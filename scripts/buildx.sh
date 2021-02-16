#!/bin/bash

REGISTRY="ahgraber"
TAG=${1:-"test"}

# clone/update keycloak container instructions
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# buildx
docker buildx create --name "${BUILDX_NAME:-certbot}" || echo
docker buildx use "${BUILDX_NAME:-certbot}"

docker buildx build \
	-f Dockerfile \
    -t ${REGISTRY}/certbot_only:${TAG} \
	--platform linux/amd64,linux/arm64 \
	--push \
	.

# cleanup
docker buildx rm "${BUILDX_NAME:-certbot}"
cd ${DIR} \
	&& rm -rf ./tmp