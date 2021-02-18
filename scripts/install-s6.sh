#!/bin/bash

# Note: This script is designed to be run inside a Docker Build for a container


TARGETPLATFORM=$1
S6_OVERLAY_VERSION=${2:-"latest"}
# S6_OVERLAY_VERSION="v2.1.0.3"

# Determine the correct binary file for the architecture given
case $TARGETPLATFORM in
	linux/arm64)
		S6_ARCH=aarch64
		;;
	linux/aarch64)
		S6_ARCH=aarch64
		;;
	linux/arm/v7)
		S6_ARCH=armhf
		;;
	*)
		S6_ARCH=amd64
		;;
esac

echo -e "Downloading S6-overlay ${S6_OVERLAY_VERSION} for ${TARGETPLATFORM} (${S6_ARCH})"

if [ S6_OVERLAY_VERSION="latest" ]; then
	S6_URL="https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-${S6_ARCH}.tar.gz"
else
	S6_URL="https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.gz"
fi

# curl -L -o "/tmp/s6-overlay-${S6_ARCH}.tar.gz" "https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.gz" \
curl -L -o "/tmp/s6-overlay-${S6_ARCH}.tar.gz" "${S6_URL}" \
	&& sleep 1 \
	&& tar xvzf "/tmp/s6-overlay-${S6_ARCH}.tar.gz" -C / --exclude="./bin" \
	&& tar xvzf "/tmp/s6-overlay-${S6_ARCH}.tar.gz" -C /usr ./bin \
	&& echo -e "S6-overlay install complete."

# curl -L -o "/tmp/s6-overlay-installer" "${S6_URL}" \
# 	&& chmod +x "/tmp/s6-overlay-installer" \
# 	&& bash "/tmp/s6-overlay-installer" \
# 	&& echo -e "S6-overlay install complete."