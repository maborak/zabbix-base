#!/bin/bash

# Exit immediately if any command fails
set -e

# Ensure the architecture argument is provided
if [[ -z "$1" || "$1" != "--arch=arm64" && "$1" != "--arch=amd64" ]]; then
    echo "Usage: $0 --arch=<arch>"
    echo "arch: arm64 or amd64"
    exit 1
fi

# Parse the architecture from the input
ARCH=${1#--arch=}
IMAGE_NAME="maborak/zabbix-base"

# Build and push the specified architecture
echo "Building and pushing ${IMAGE_NAME}:${ARCH}..."
docker build -t ${IMAGE_NAME}:${ARCH} .
docker push ${IMAGE_NAME}:${ARCH}
echo "Successfully pushed ${IMAGE_NAME}:${ARCH}!"

# Update the multi-arch manifest
echo "Updating multi-arch manifest for ${IMAGE_NAME}:latest..."
docker manifest create ${IMAGE_NAME}:latest \
    --amend ${IMAGE_NAME}:arm64 \
    --amend ${IMAGE_NAME}:amd64

# Annotate the manifest for clarity
docker manifest annotate ${IMAGE_NAME}:latest ${IMAGE_NAME}:amd64 --arch amd64
docker manifest annotate ${IMAGE_NAME}:latest ${IMAGE_NAME}:arm64 --arch arm64

# Push the updated manifest
echo "Pushing updated multi-arch manifest for ${IMAGE_NAME}:latest..."
docker manifest push ${IMAGE_NAME}:latest

echo "Done! ${IMAGE_NAME}:latest has been updated with ${ARCH}."