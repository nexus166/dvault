FROM	node:10-alpine AS nodejs

FROM	nexus166/gobld:latest
COPY	--from=nodejs /usr/local /usr/local
RUN	apk add --update --upgrade --no-cache ca-certificates bash binutils file git gcc libc-dev libstdc++ make python zip; \
	npm config set unsafe-perm true; \
	rm -fv /usr/local/bin/yarn*; \
	npm install -g --force yarn@1.19.1

SHELL   ["/bin/bash", "-evxo", "pipefail", "-c"]

ARG     USR="vault"
RUN     addgroup -S "${USR}"; \
        adduser -h /vault -D -S -s /dev/null -g "${USR}" "${USR}"; \
        mkdir -vp /vault/{config,file,logs,plugins} "${GOPATH}"; \
        chown -vR "${USR}:${USR}" /vault "${GOPATH}"

USER	"${USR}"

ARG	VAULT_GIT_TAG
RUN	if [[ -z "${VAULT_GIT_TAG}" ]]; then \
		go get -d -u -v github.com/hashicorp/vault; \
	else \
		mkdir -vp "${GOPATH}/src/github.com/hashicorp/vault"; \
		git clone --branch "${VAULT_GIT_TAG}" --depth 1 https://github.com/hashicorp/vault.git "${GOPATH}/src/github.com/hashicorp/vault"; \
	fi; \
	set +x; \
	for f in $(find "${GOPATH}/src/github.com/hashicorp/vault" -type f -name '*.go' -o -name '*.mod' -o -name '*.sum'); do \
		sed -i 's|git.apache.org/thrift|github.com/apache/thrift|g' "${f}"; \
	done

WORKDIR	"${GOPATH}/src/github.com/hashicorp/vault"

RUN	make bootstrap

RUN	make static-dist

ARG	CGO_ENABLED=0
ARG	XC_ARCH
ARG	XC_OS
ARG	XC_OSARCH
ENV	XC_OSARCH=${XC_OSARCH:-"${XC_OS}/${XC_ARCH}"}
ENV	GO_LDFLAGS="-s -w -extldflags=-static "
ENV	GOARM=7

RUN	export \
		GCFLAGS="${GO_GCFLAGS}" \
		LD_FLAGS="${GO_LDFLAGS}" \
		XC_ARCH="${XC_ARCH:-$(go env GOARCH)}" \
		XC_OS="${XC_OS:-$(go env GOOS)}"; \
	export	\
		XC_OSARCH=${XC_OSARCH:-"${XC_OS}/${XC_ARCH}"}; \
	[[ "${XC_OSARCH}" == "/" ]] && export XC_OSARCH="${XC_OS}/${XC_ARCH}"; \
	CGO_ENABLED="${CGO_ENABLED}" XC_ARCH="${XC_ARCH}" XC_OS="${XC_OS}" XC_OSARCH="${XC_OSARCH}" make bin; \
	cp -v "./pkg/$(echo ${XC_OSARCH} | tr '/' '_')/vault" "${GOPATH}/bin/vault"; \
	rm -fr "${GOPATH}/src" ~/.cache; \
	file "$(which vault)"
