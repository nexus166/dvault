#

FROM	nexus166/gobld:alpine-cgo

RUN	apk add --update --upgrade --no-cache ca-certificates bash binutils file git gcc npm libc-dev libstdc++ make python zip; \
	npm config set unsafe-perm true; \
	npm install -g yarn@1.17.3

SHELL   ["/bin/bash", "-evxo", "pipefail", "-c"]

ARG     USR="vault"
RUN     addgroup -S "${USR}"; \
        adduser -h /vault -D -S -s /dev/null -g "${USR}" "${USR}"; \
        mkdir -vp /vault/{config,file,logs,plugins} "${GOPATH}"; \
        chown -vR "${USR}:${USR}" /vault "${GOPATH}"

USER	"${USR}"

RUN	go get -d -v github.com/hashicorp/vault

ARG	VAULT_GIT_TAG
RUN	[[ ! -z "${VAULT_GIT_TAG}" ]] && (cd "${GOPATH}/src/github.com/hashicorp/vault" && git checkout "tags/${VAULT_GIT_TAG}") || true

WORKDIR	"${GOPATH}/src/github.com/hashicorp/vault"

RUN	make bootstrap

RUN	make static-dist

ARG	CGO_ENABLED=0
ARG	XC_ARCH
ARG	XC_OS
ARG	XC_OSARCH
ENV	XC_OSARCH=${XC_OSARCH:-"${XC_OS}/${XC_ARCH}"}
ENV	GO_LDFLAGS="-s -w "
#ENV	GO_GCFLAGS=all="-d softfloat"
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
