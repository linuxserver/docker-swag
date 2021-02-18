#!/bin/bash

REGISTRY="ahgraber"
TAG=${1:-"test"}

# define build context
# assumes run from project folder root
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# buildx
docker buildx create --name "${BUILDX_NAME:-certbot}" || echo
docker buildx use "${BUILDX_NAME:-certbot}"

docker buildx build \
	--no-cache \
	--platform linux/amd64,linux/arm64 \
	--file Dockerfile \
    --tag ${REGISTRY}/certbot_only:${TAG} \
	--push \
	.

# cleanup
docker buildx rm "${BUILDX_NAME:-certbot}"
cd ${DIR} \
	&& rm -rf ./tmp