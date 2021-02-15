#!/bin/bash

# Note: This script is designed to be run inside a Docker Build for a container

S6_OVERLAY_VERSION=1.22.1.0
TARGETPLATFORM=$1

# Determine the correct binary file for the architecture given
case $TARGETPLATFORM in
	linux/arm64)
		S6_ARCH=aarch64
		;;

	linux/arm/v7)
		S6_ARCH=armhf
		;;

	*)
		S6_ARCH=amd64
		;;
esac

echo -e "Installing S6-overlay v${S6_OVERLAY_VERSION} for ${TARGETPLATFORM} (${S6_ARCH})"

curl -L -o "/tmp/s6-overlay-${S6_ARCH}.tar.gz" "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.gz" \
	&& tar xzf /tmp/s6-overlay-amd64.tar.gz -C / --exclude="./bin" && \
    tar xzf /tmp/s6-overlay-amd64.tar.gz -C /usr ./bin

echo -e "S6-overlay install complete."