#!/bin/bash
set -e

if [[ -z "$1" || "$1" != "--arch=arm64" && "$1" != "--arch=amd64" ]]; then
    echo "Usage: $0 --arch=<arch>"
    echo "arch: arm64 or amd64"
    exit 1
fi

# Parse the architecture from the input
ARCH=${1#--arch=}
IMAGE_NAME="maborak/zabbix-base"

# Create and use a new builder instance
docker buildx create --use 

# Build and push the specified architecture using buildx
echo "Building and pushing ${IMAGE_NAME}:${ARCH} with buildx..."
docker buildx build --platform linux/${ARCH} -t ${IMAGE_NAME}:${ARCH} --push .
echo "Successfully pushed ${IMAGE_NAME}:${ARCH}!"

# Update the multi-arch manifest
echo "Updating multi-arch manifest for ${IMAGE_NAME}:latest..."
docker buildx imagetools create -t ${IMAGE_NAME}:latest \
    ${IMAGE_NAME}:arm64 ${IMAGE_NAME}:amd64
echo "Successfully updated multi-arch manifest for ${IMAGE_NAME}:latest!"

# Remove the builder instance
docker buildx rm