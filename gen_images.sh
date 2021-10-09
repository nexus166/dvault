#!/usr/bin/env bash

set -xe

CONTAINER="${CONTAINER}"
[[ -z ${CONTAINER} ]] && CONTAINER="$(basename $(dirname $(realpath .)))/$(basename $(git remote get-url origin) .git)"

ALL_TAGS="$(curl -s 'https://api.github.com/repos/hashicorp/vault/tags' | jq -r '.[].name' | grep -vE 'rc|beta' | sort -Vu)"
TARGET_TAGS=${1:-"$(tr ' ' '\n' <<<"${ALL_TAGS}" | tail -1)"}
[[ ${TARGET_ALL} == "true" ]] && TARGET_TAGS="${ALL_TAGS}"

for VAULT_GIT_TAG in ${TARGET_TAGS}; do
	docker build --rm --squash \
		--file ./Dockerfile \
		--build-arg XC_ARCH="${3:-${XC_ARCH}}" \
		--build-arg XC_OS="${2:-${XC_OS}}" \
		--build-arg VAULT_GIT_TAG="${VAULT_GIT_TAG}" \
		--build-arg CGO_ENABLED=0 \
		--tag "${CONTAINER}:${VAULT_GIT_TAG}" \
		.
done
docker images | grep "${CONTAINER}"
