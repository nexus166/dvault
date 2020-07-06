FROM	nexus166/vault:stage1-cgo
FROM	alpine

RUN	mkdir -vp /lib64; \
	ln -vs "/lib/libc.musl-$(uname -m).so.1" "/lib64/ld-linux-$(uname -m | tr '_' '-').so.2" || true; \
	ln -vs "/lib/libc.musl-$(uname -m).so.1" /lib/ld64.so.1 || true; \
	apk add --update --upgrade ca-certificates; \
	rm /bin/busybox

ARG	USR="vault"

COPY	--from=0 /etc/passwd /etc/group			/etc/
COPY	--from=0 /opt/go/bin/vault			/bin/vault
COPY	--from=0 --chown=vault:vault /vault		/vault

USER	"${USR}"

EXPOSE	8200/tcp

ENTRYPOINT ["/bin/vault"]
CMD	["server", "-dev"]
