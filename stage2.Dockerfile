FROM	nexus166/vault:stage1
FROM	scratch

ARG	USR="vault"

COPY	--from=0 /etc/passwd /etc/group			/etc/
COPY	--from=0 /etc/ssl			        /etc/ssl
COPY	--from=0 /opt/go/bin/vault			/bin/vault
COPY	--from=0 --chown=vault:vault /vault		/vault

USER	"${USR}"

EXPOSE	8200/tcp

ENTRYPOINT ["/bin/vault"]
CMD	["server", "-dev"]
