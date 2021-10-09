FROM	node:14-alpine AS nodejs

FROM	nexus166/gobld:alpine_go1.16.8 AS buildenv
COPY	--from=nodejs /usr/local /usr/local
RUN	apk add --update --upgrade --no-cache ca-certificates bash binutils file git gcc libc-dev libstdc++ make py3-pip upx zip; \
	npm config set unsafe-perm true; \
	rm -fv /usr/local/bin/yarn*; \
	npm install -g --force yarn

SHELL   ["/bin/bash", "-evxo", "pipefail", "-c"]

ARG     USR="vault"
RUN     addgroup -S "${USR}"; \
        adduser -h /vault -D -S -s /dev/null -g "${USR}" "${USR}"; \
        mkdir -vp /vault/{config,file,logs,plugins} "${GOPATH}"; \
        chown -vR "${USR}:${USR}" /vault "${GOPATH}"

USER	"${USR}"

ARG	VAULT_GIT_TAG
RUN	if [[ -z "${VAULT_GIT_TAG}" ]]; then \
		GO111MODULE=on go get -d -u -v github.com/hashicorp/vault; \
	else \
		mkdir -vp "${GOPATH}/src/github.com/hashicorp/vault"; \
		git clone --branch "${VAULT_GIT_TAG}" --depth 1 https://github.com/hashicorp/vault.git "${GOPATH}/src/github.com/hashicorp/vault"; \
	fi

WORKDIR	"${GOPATH}/src/github.com/hashicorp/vault"

RUN	go mod tidy; \
	make bootstrap; \
	cd ui && npx browserslist@latest --update-db
RUN	make static-dist

ARG	CGO_ENABLED=0
ARG	XC_ARCH
ARG	XC_OS
ARG	XC_OSARCH
ENV	XC_OSARCH=${XC_OSARCH:-"${XC_OS}/${XC_ARCH}"}
ENV	GO_LDFLAGS="-s -w -extldflags=-static "
ENV	GOARM=7
ARG	UPX=0

RUN	export \
		GCFLAGS="${GO_GCFLAGS}" \
		LD_FLAGS="${GO_LDFLAGS}" \
		XC_ARCH="${XC_ARCH:-$(go env GOARCH)}" \
		XC_OS="${XC_OS:-$(go env GOOS)}"; \
	export XC_OSARCH=${XC_OSARCH:-"${XC_OS}/${XC_ARCH}"}; \
	[[ "${XC_OSARCH}" == "/" ]] && export XC_OSARCH="${XC_OS}/${XC_ARCH}"; \
	CGO_ENABLED="${CGO_ENABLED}" XC_ARCH="${XC_ARCH}" XC_OS="${XC_OS}" XC_OSARCH="${XC_OSARCH}" make bin; \
	cp -v "./pkg/$(tr '/' '_' <<<${XC_OSARCH})/vault" "${GOPATH}/bin/vault"; \
	rm -fr "${GOPATH}/src" ~/.cache; \
	_v="$(which vault)"; \
	file "${_v}"; \
	du -sh "${_v}"; \
	if [[ ${UPX} != 0 ]]; then \
		upx -9 "${_v}"; \
		du -sh "${_v}"; \
	fi; \
	vault version

FROM	scratch
ARG	USR="vault"

COPY	--from=buildenv 			/etc/passwd /etc/group	/etc/
COPY	--from=nodejs 				/etc/ssl       		/etc/ssl
COPY	--from=buildenv				/opt/go/bin/vault	/bin/vault
COPY	--from=buildenv --chown=vault:vault	/vault			/vault

USER	"${USR}"
EXPOSE	8200/tcp

ENTRYPOINT ["/bin/vault"]
CMD	["server", "-dev"]
