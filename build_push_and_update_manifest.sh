#!/bin/bash
set -e

# Default values
ZABBIX_VERSION="7.4.1"
ARCH=""
SET_LATEST="false"
VERBOSE="false"
SHOW_VERSIONS="false"
NO_CACHE="false"
DRY_RUN="false"
FORCE="false"
PUSH="true"

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
        --set-latest)
            SET_LATEST="true"
            shift
            ;;
        --verbose)
            VERBOSE="true"
            shift
            ;;
        --versions)
            SHOW_VERSIONS="true"
            shift
            ;;
        --no-cache)
            NO_CACHE="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --push=*)
            PUSH="${1#--push=}"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to fetch and display Zabbix versions from GitHub
show_zabbix_versions() {
    echo "Fetching Zabbix versions from https://github.com/zabbix/zabbix/tags..."
    echo ""
    
    # Use GitHub API to get tags
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo "Error: curl or wget is required to fetch versions"
        exit 1
    fi
    
    # Fetch tags from GitHub HTML page (works better than API, same as browser)
    USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    
    if command -v curl &> /dev/null; then
        HTML_RESPONSE=$(curl -s -H "User-Agent: $USER_AGENT" "https://github.com/zabbix/zabbix/tags")
    else
        HTML_RESPONSE=$(wget -q -O - --user-agent="$USER_AGENT" "https://github.com/zabbix/zabbix/tags")
    fi
    
    if [[ -z "$HTML_RESPONSE" ]] || [[ "$HTML_RESPONSE" == *"Not Found"* ]]; then
        echo "Error: Failed to fetch versions from GitHub"
        exit 1
    fi
    
    # Extract version tags from HTML (looking for tag links like /zabbix/zabbix/releases/tag/7.4.6)
    VERSIONS=$(echo "$HTML_RESPONSE" | grep -oE '/zabbix/zabbix/releases/tag/[0-9]+\.[0-9]+\.[0-9]+[^"]*' | sed 's|/zabbix/zabbix/releases/tag/||' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' | sort -V -r -u | head -20)
    
    # If that doesn't work, try alternative HTML patterns
    if [[ -z "$VERSIONS" ]]; then
        # Try extracting from href attributes
        VERSIONS=$(echo "$HTML_RESPONSE" | grep -oE 'href="[^"]*releases/tag/[0-9]+\.[0-9]+\.[0-9]+' | sed 's|.*releases/tag/||' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' | sort -V -r -u | head -20)
    fi
    
    if [[ -z "$VERSIONS" ]]; then
        # Try extracting version numbers directly from the page
        VERSIONS=$(echo "$HTML_RESPONSE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(rc[0-9]+)?' | sort -V -r -u | head -20)
    fi
    
    if [[ -z "$VERSIONS" ]]; then
        echo "Error: Could not parse versions from GitHub"
        echo "Debug: HTML response length: ${#HTML_RESPONSE}"
        echo "Debug: First 200 chars of response: ${HTML_RESPONSE:0:200}"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "Full HTML response:"
            echo "$HTML_RESPONSE"
        fi
        exit 1
    fi
    
    # Display versions
    echo "Available Zabbix versions:"
    echo "========================="
    echo "$VERSIONS"
    
    echo ""
    echo "Note: Showing latest 20 versions. For more, visit: https://github.com/zabbix/zabbix/tags"
    exit 0
}

# Handle --versions flag early
if [[ "$SHOW_VERSIONS" == "true" ]]; then
    show_zabbix_versions
fi

# Validate architecture(s)
if [[ -z "$ARCH" ]]; then
    echo "Usage: $0 --arch=<arch> [--zabbix-version=<version>] [--set-latest] [--verbose] [--versions] [--no-cache] [--dry-run] [--force] [--push=<true|false>]"
    echo "  --arch: arm64, amd64, or comma-separated list (e.g., arm64,amd64) (required)"
    echo "  --zabbix-version: Zabbix version (optional, default: 7.4.1)"
    echo "  --set-latest: Push to :latest tag (optional flag, default: false)"
    echo "  --verbose: Show full build output (optional, default: false)"
    echo "  --versions: List available Zabbix versions from GitHub (exits after listing)"
    echo "  --no-cache: Force rebuild without using cache (optional, default: false)"
    echo "  --dry-run: Show what would be built/pushed without executing (optional, default: false)"
    echo "  --force: Skip manifest checking, build only requested architectures (optional, default: false)"
    echo "  --push: Push images to registry (optional, default: true, use --push=false to build only)"
    exit 1
fi

# Split architectures by comma and validate each
IFS=',' read -ra ARCH_ARRAY <<< "$ARCH"
VALID_ARCHS=("arm64" "amd64")
PLATFORMS=""

for arch in "${ARCH_ARRAY[@]}"; do
    arch=$(echo "$arch" | xargs) # trim whitespace
    valid=false
    for valid_arch in "${VALID_ARCHS[@]}"; do
        if [[ "$arch" == "$valid_arch" ]]; then
            valid=true
            if [[ -z "$PLATFORMS" ]]; then
                PLATFORMS="linux/$arch"
            else
                PLATFORMS="$PLATFORMS,linux/$arch"
            fi
            break
        fi
    done
    if [[ "$valid" == "false" ]]; then
        echo "Error: Invalid architecture '$arch'. Must be one of: ${VALID_ARCHS[*]}"
        exit 1
    fi
done

# Validate set-latest value
if [[ "$SET_LATEST" != "true" && "$SET_LATEST" != "false" ]]; then
    echo "Error: --set-latest must be 'true' or 'false'"
    exit 1
fi

# Validate push value
if [[ "$PUSH" != "true" && "$PUSH" != "false" ]]; then
    echo "Error: --push must be 'true' or 'false'"
    exit 1
fi

IMAGE_NAME="maborak/zabbix-base"

# Function to check existing manifest architectures
check_existing_archs() {
    local tag=$1
    local full_image="${IMAGE_NAME}:${tag}"
    
    echo "  → Checking manifest for: ${full_image}" >&2
    
    # Check if manifest exists
    if docker manifest inspect "$full_image" &>/dev/null; then
        echo "  → Manifest found, extracting architectures..." >&2
        # Extract architectures from manifest
        local archs=$(docker manifest inspect "$full_image" 2>/dev/null | \
            grep -o '"architecture":"[^"]*"' | \
            sed 's/"architecture":"\([^"]*\)"/\1/' | \
            sort | uniq)
        
        if [[ -n "$archs" ]]; then
            local arch_list=$(echo "$archs" | tr '\n' ' ' | sed 's/ $//')
            echo "  → Found architectures: ${arch_list}" >&2
            echo "$archs"  # Return architectures to stdout
        else
            echo "  → No architectures found in manifest" >&2
        fi
    else
        echo "  → Manifest not found (image doesn't exist yet)" >&2
    fi
}

# Function to check if an architecture is in the array
arch_in_array() {
    local arch=$1
    shift
    local arr=("$@")
    for a in "${arr[@]}"; do
        if [[ "$a" == "$arch" ]]; then
            return 0
        fi
    done
    return 1
}

# Check for existing architectures and merge them with requested ones (unless --force)
existing_archs_version=""
existing_archs_latest=""

if [[ "$FORCE" != "true" ]]; then
    echo "Checking existing manifest architectures..."
    echo "Requested architectures: ${ARCH_ARRAY[*]}"
    echo ""
    echo "Checking version tag: ${IMAGE_NAME}:${ZABBIX_VERSION}"
    existing_archs_version=$(check_existing_archs "$ZABBIX_VERSION")
    echo ""

    if [[ "$SET_LATEST" == "true" ]]; then
        echo "Checking latest tag: ${IMAGE_NAME}:latest"
        existing_archs_latest=$(check_existing_archs "latest")
        echo ""
    fi

    echo "Manifest check complete."
    if [[ -n "$existing_archs_version" ]] || [[ -n "$existing_archs_latest" ]]; then
        echo "Existing architectures found - will merge with requested architectures."
    else
        echo "No existing manifests found - will build only requested architectures."
    fi
    echo ""
else
    echo "Force mode enabled - skipping manifest check, building only requested architectures: ${ARCH_ARRAY[*]}"
    echo ""
fi

# Collect all architectures we need to build
declare -a FINAL_ARCH_ARRAY=("${ARCH_ARRAY[@]}")

# Merge with existing architectures from version tag
if [[ -n "$existing_archs_version" ]]; then
    while IFS= read -r existing_arch; do
        existing_arch=$(echo "$existing_arch" | xargs) # trim whitespace
        if [[ -n "$existing_arch" ]] && ! arch_in_array "$existing_arch" "${FINAL_ARCH_ARRAY[@]}"; then
            # Check if it's a valid architecture
            for valid_arch in "${VALID_ARCHS[@]}"; do
                if [[ "$existing_arch" == "$valid_arch" ]]; then
                    FINAL_ARCH_ARRAY+=("$existing_arch")
                    echo "Found existing architecture '$existing_arch' in ${IMAGE_NAME}:${ZABBIX_VERSION}, will include it in build"
                    break
                fi
            done
        fi
    done <<< "$existing_archs_version"
fi

# Merge with existing architectures from latest tag (if applicable)
if [[ -n "$existing_archs_latest" ]]; then
    while IFS= read -r existing_arch; do
        existing_arch=$(echo "$existing_arch" | xargs) # trim whitespace
        if [[ -n "$existing_arch" ]] && ! arch_in_array "$existing_arch" "${FINAL_ARCH_ARRAY[@]}"; then
            # Check if it's a valid architecture
            for valid_arch in "${VALID_ARCHS[@]}"; do
                if [[ "$existing_arch" == "$valid_arch" ]]; then
                    FINAL_ARCH_ARRAY+=("$existing_arch")
                    echo "Found existing architecture '$existing_arch' in ${IMAGE_NAME}:latest, will include it in build"
                    break
                fi
            done
        fi
    done <<< "$existing_archs_latest"
fi

# Rebuild PLATFORMS string with merged architectures
PLATFORMS=""
for arch in "${FINAL_ARCH_ARRAY[@]}"; do
    if [[ -z "$PLATFORMS" ]]; then
        PLATFORMS="linux/$arch"
    else
        PLATFORMS="$PLATFORMS,linux/$arch"
    fi
done

# Show what will be built
if [[ ${#FINAL_ARCH_ARRAY[@]} -gt ${#ARCH_ARRAY[@]} ]]; then
    echo ""
    echo "Merged architectures: ${ARCH_ARRAY[*]} (requested) + existing = ${FINAL_ARCH_ARRAY[*]} (final)"
    echo ""
fi

# Dry-run display function
display_dry_run() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    DRY RUN MODE                             ║"
    echo "║         (No builds or pushes will be executed)                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Configuration:"
    echo "  Zabbix Version: ${ZABBIX_VERSION}"
    echo "  Architectures: ${FINAL_ARCH_ARRAY[*]}"
    echo "  Platforms: ${PLATFORMS}"
    echo "  Set Latest: ${SET_LATEST}"
    echo "  No Cache: ${NO_CACHE}"
    echo "  Verbose: ${VERBOSE}"
    echo ""
    echo "Images to build and push:"
    echo ""
    echo "1. BASE IMAGE:"
    echo "   Image: ${IMAGE_NAME}:${ZABBIX_VERSION}"
    if [[ "$SET_LATEST" == "true" ]]; then
        echo "   Also tagged as: ${IMAGE_NAME}:latest"
    fi
    echo "   Dockerfile: base/Dockerfile"
    echo "   Build args: ZABBIX_VERSION=${ZABBIX_VERSION}"
    echo "   Platforms: ${PLATFORMS}"
    echo ""
    
    NAMESPACE=$(echo "$IMAGE_NAME" | cut -d'/' -f1)
    COMPONENTS=("server" "db" "ui")
    for i in "${!COMPONENTS[@]}"; do
        component="${COMPONENTS[$i]}"
        COMPONENT_IMAGE_NAME="${NAMESPACE}/zabbix-${component}"
        echo "$((i+2)). ${component^^} IMAGE:"
        echo "   Image: ${COMPONENT_IMAGE_NAME}:${ZABBIX_VERSION}"
        if [[ "$SET_LATEST" == "true" ]]; then
            echo "   Also tagged as: ${COMPONENT_IMAGE_NAME}:latest"
        fi
        echo "   Dockerfile: ${component}/Dockerfile"
        echo "   Build args: ZABBIX_BASE=${IMAGE_NAME}:${ZABBIX_VERSION}"
        echo "   Platforms: ${PLATFORMS}"
        echo ""
    done
    
    echo "Builder:"
    if [[ "$NO_CACHE" == "true" ]]; then
        echo "  - Will remove existing builder (if exists)"
        echo "  - Will create new builder"
        echo "  - Will remove builder after build"
    else
        echo "  - Will reuse existing builder (or create if needed)"
        echo "  - Builder will be kept for cache preservation"
    fi
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  End of dry-run. Run without --dry-run to execute builds.   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    exit 0
}

# Use or create a builder instance (reuse to preserve cache)
BUILDER_NAME="zabbix-base-builder"

# If --no-cache, remove existing builder to start fresh
if [[ "$NO_CACHE" == "true" ]]; then
    if [[ "$DRY_RUN" != "true" ]]; then
        if docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
            echo "Removing existing buildx builder: $BUILDER_NAME (--no-cache enabled)"
            docker buildx rm "$BUILDER_NAME" 2>/dev/null || true
        fi
    fi
fi

# Display dry-run info and exit if in dry-run mode
if [[ "$DRY_RUN" == "true" ]]; then
    display_dry_run
fi

# Create or use builder
echo "Setting up buildx builder..."
if ! docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
    echo "Creating buildx builder: $BUILDER_NAME (this may take a moment)..."
    docker buildx create --name "$BUILDER_NAME" --use --driver docker-container
    echo "Builder created successfully."
else
    echo "Using existing buildx builder: $BUILDER_NAME"
    docker buildx use "$BUILDER_NAME"
fi
echo ""

# Build and push base image first
echo "=========================================="
echo "Building base image: ${IMAGE_NAME}:${ZABBIX_VERSION}"
echo "Platform(s): ${PLATFORMS}"
echo "Zabbix version: ${ZABBIX_VERSION}"
echo "=========================================="

# Prepare tags for base image
BASE_TAGS="-t ${IMAGE_NAME}:${ZABBIX_VERSION}"
if [[ "$SET_LATEST" == "true" ]]; then
    BASE_TAGS="${BASE_TAGS} -t ${IMAGE_NAME}:latest"
fi

# Prepare progress flag - always show progress, use plain for verbose
if [[ "$VERBOSE" == "true" ]]; then
    PROGRESS_FLAG="--progress=plain"
else
    PROGRESS_FLAG="--progress=auto"
fi

# Prepare no-cache flag
NO_CACHE_FLAG=""
if [[ "$NO_CACHE" == "true" ]]; then
    NO_CACHE_FLAG="--no-cache"
    echo "Warning: Building without cache (--no-cache flag enabled)"
fi

# Prepare push flag
PUSH_FLAG=""
if [[ "$PUSH" == "true" ]]; then
    PUSH_FLAG="--push"
fi

# Build base image
if [[ "$PUSH" == "true" ]]; then
    echo "Starting base image build and push..."
else
    echo "Starting base image build (no push)..."
fi
echo "Command: docker buildx build --platform ${PLATFORMS} --build-arg ZABBIX_VERSION=${ZABBIX_VERSION} ${BASE_TAGS} ${PUSH_FLAG} ${NO_CACHE_FLAG} ${PROGRESS_FLAG} -f base/Dockerfile base/"
echo ""

docker buildx build --platform ${PLATFORMS} \
    --build-arg ZABBIX_VERSION=${ZABBIX_VERSION} \
    ${BASE_TAGS} \
    ${PUSH_FLAG} \
    ${NO_CACHE_FLAG} \
    ${PROGRESS_FLAG} \
    -f base/Dockerfile \
    base/

echo ""
if [[ "$PUSH" == "true" ]]; then
    echo "✓ Successfully built and pushed base image ${IMAGE_NAME}:${ZABBIX_VERSION}!"
    if [[ "$SET_LATEST" == "true" ]]; then
        echo "✓ Successfully built and pushed base image ${IMAGE_NAME}:latest!"
    fi
else
    echo "✓ Successfully built base image ${IMAGE_NAME}:${ZABBIX_VERSION}!"
    if [[ "$SET_LATEST" == "true" ]]; then
        echo "✓ Successfully built base image ${IMAGE_NAME}:latest!"
    fi
fi

# Set ZABBIX_BASE to match the version being built
ZABBIX_BASE_IMAGE="${IMAGE_NAME}:${ZABBIX_VERSION}"

# Build server, db, and ui images
# Use cleaner naming: maborak/zabbix-server, maborak/zabbix-db, maborak/zabbix-ui
COMPONENTS=("server" "db" "ui")
for component in "${COMPONENTS[@]}"; do
    # Extract namespace from IMAGE_NAME (e.g., "maborak" from "maborak/zabbix-base")
    NAMESPACE=$(echo "$IMAGE_NAME" | cut -d'/' -f1)
    COMPONENT_IMAGE_NAME="${NAMESPACE}/zabbix-${component}"
    
    echo ""
    echo "=========================================="
    echo "Building ${component} image: ${COMPONENT_IMAGE_NAME}:${ZABBIX_VERSION}"
    echo "Platform(s): ${PLATFORMS}"
    echo "Base image: ${ZABBIX_BASE_IMAGE}"
    echo "=========================================="
    
    COMPONENT_TAGS="-t ${COMPONENT_IMAGE_NAME}:${ZABBIX_VERSION}"
    if [[ "$SET_LATEST" == "true" ]]; then
        COMPONENT_TAGS="${COMPONENT_TAGS} -t ${COMPONENT_IMAGE_NAME}:latest"
    fi
    
    if [[ "$PUSH" == "true" ]]; then
        echo "Starting ${component} image build and push..."
    else
        echo "Starting ${component} image build (no push)..."
    fi
    echo "Command: docker buildx build --platform ${PLATFORMS} --build-arg ZABBIX_BASE=${ZABBIX_BASE_IMAGE} ${COMPONENT_TAGS} ${PUSH_FLAG} ${NO_CACHE_FLAG} ${PROGRESS_FLAG} -f ${component}/Dockerfile ${component}/"
    echo ""
    
    docker buildx build --platform ${PLATFORMS} \
        --build-arg ZABBIX_BASE=${ZABBIX_BASE_IMAGE} \
        ${COMPONENT_TAGS} \
        ${PUSH_FLAG} \
        ${NO_CACHE_FLAG} \
        ${PROGRESS_FLAG} \
        -f ${component}/Dockerfile \
        ${component}/
    
    echo ""
    if [[ "$PUSH" == "true" ]]; then
        echo "✓ Successfully built and pushed ${component} image ${COMPONENT_IMAGE_NAME}:${ZABBIX_VERSION}!"
        if [[ "$SET_LATEST" == "true" ]]; then
            echo "✓ Successfully built and pushed ${component} image ${COMPONENT_IMAGE_NAME}:latest!"
        fi
    else
        echo "✓ Successfully built ${component} image ${COMPONENT_IMAGE_NAME}:${ZABBIX_VERSION}!"
        if [[ "$SET_LATEST" == "true" ]]; then
            echo "✓ Successfully built ${component} image ${COMPONENT_IMAGE_NAME}:latest!"
        fi
    fi
done

echo ""
echo "=========================================="
if [[ "$PUSH" == "true" ]]; then
    echo "All images built and pushed successfully!"
else
    echo "All images built successfully! (not pushed)"
fi
echo "=========================================="

# Remove builder if --no-cache was used (fresh start each time)
if [[ "$NO_CACHE" == "true" ]]; then
    echo "Removing buildx builder: $BUILDER_NAME (--no-cache enabled)"
    docker buildx rm "$BUILDER_NAME" 2>/dev/null || true
else
    # Note: Builder is kept for cache preservation
    echo "Builder '$BUILDER_NAME' kept for cache preservation"
fi