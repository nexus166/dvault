#!/usr/bin/env bash

set -xe

CONTAINER="${CONTAINER}"
[[ -z ${CONTAINER} ]] && CONTAINER="$(basename $(dirname $(realpath .)))/$(basename $(git remote get-url origin) .git)"

CGO_TAG=""
CGO_ENABLED="${CGO_ENABLED:-0}"
[[ ${CGO_ENABLED} == 1 ]] && export CGO_TAG="-cgo"

ALL_TAGS="$(curl -s 'https://api.github.com/repos/hashicorp/vault/tags' | jq -r '.[].name' | grep -vE 'rc|beta' | sort -Vu)"
TARGET_TAGS=${1:-"$(tr ' ' '\n' <<<"${ALL_TAGS}" | tail -5)"}
[[ ${TARGET_ALL} == "true" ]] && TARGET_TAGS="${ALL_TAGS}"

for VAULT_GIT_TAG in ${TARGET_TAGS}; do
	docker build --rm --squash \
		--file ./stage1.Dockerfile \
		--build-arg XC_ARCH="${3:-${XC_ARCH}}" \
		--build-arg XC_OS="${2:-${XC_OS}}" \
		--build-arg VAULT_GIT_TAG="${VAULT_GIT_TAG}" \
		--build-arg "CGO_ENABLED=${CGO_ENABLED}" \
		--tag "${CONTAINER}:stage1${CGO_TAG}" \
		.
	#	printf '%s\n' "$DOCKERIO_KEY_PASS" | docker push "${CONTAINER}:stage1${CGO_TAG}";
	docker build --rm --squash \
		--file ./stage2${CGO_TAG}.Dockerfile \
		--tag "${CONTAINER}:${VAULT_GIT_TAG}${CGO_TAG}" \
		.
	#	printf '%s\n' "$DOCKERIO_KEY_PASS" | docker push "${CONTAINER}:${VAULT_GIT_TAG}${CGO_TAG}";
done

LATEST_TAG="$(tr ' ' '\n' <<<"${TARGET_TAGS}" | tail -1)"
docker tag "${CONTAINER}:${LATEST_TAG}${CGO_TAG}" "${CONTAINER}:latest${CGO_TAG}"
#printf '%s\n' "$DOCKERIO_KEY_PASS" | docker push "${CONTAINER}:latest${CGO_TAG}"

docker images | grep "${CONTAINER}"
