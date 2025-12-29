#!/bin/bash
set -e

# Default values
ZABBIX_VERSION="7.4.1"
ARCH=""
SET_LATEST="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --arch=*)
            ARCH="${1#--arch=}"
            shift
            ;;
        --zabbix-version=*)
            ZABBIX_VERSION="${1#--zabbix-version=}"
            shift
            ;;
        --set-latest=*)
            SET_LATEST="${1#--set-latest=}"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate architecture
if [[ -z "$ARCH" || "$ARCH" != "arm64" && "$ARCH" != "amd64" ]]; then
    echo "Usage: $0 --arch=<arch> [--zabbix-version=<version>] [--set-latest=<true|false>]"
    echo "  --arch: arm64 or amd64 (required)"
    echo "  --zabbix-version: Zabbix version (optional, default: 7.4.1)"
    echo "  --set-latest: Push to :latest tag (optional, default: false)"
    exit 1
fi

# Validate set-latest value
if [[ "$SET_LATEST" != "true" && "$SET_LATEST" != "false" ]]; then
    echo "Error: --set-latest must be 'true' or 'false'"
    exit 1
fi

IMAGE_NAME="maborak/zabbix-base"

# Create and use a new builder instance
docker buildx create --use 

# Build and push the specified architecture using buildx
echo "Building and pushing ${IMAGE_NAME}:${ZABBIX_VERSION} for ${ARCH} with buildx..."
echo "Zabbix version: ${ZABBIX_VERSION}"

# Prepare tags
TAGS="-t ${IMAGE_NAME}:${ZABBIX_VERSION}"
if [[ "$SET_LATEST" == "true" ]]; then
    TAGS="${TAGS} -t ${IMAGE_NAME}:latest"
fi

docker buildx build --platform linux/${ARCH} \
    --build-arg ZABBIX_VERSION=${ZABBIX_VERSION} \
    ${TAGS} \
    --push .
echo "Successfully pushed ${IMAGE_NAME}:${ZABBIX_VERSION}!"
if [[ "$SET_LATEST" == "true" ]]; then
    echo "Successfully pushed ${IMAGE_NAME}:latest!"
fi

# Remove the builder instance
docker buildx rm