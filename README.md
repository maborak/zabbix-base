# Zabbix Base Docker Image

A multi-platform Docker image for Zabbix server and agent, built from source with security best practices.

## Features

- **Complete Zabbix Stack**: Builds base, server, database, and UI components
- **Multi-platform support**: Built for both `linux/amd64` and `linux/arm64` architectures
- **Multi-arch manifests**: Automatically preserves existing architectures when building
- **Security-focused**: Runs as non-root user with explicit UID/GID
- **Version-flexible**: Automatically detects and installs correct PCRE library based on Zabbix version
- **Automated builds**: Single script builds entire stack with proper versioning
- **Build options**: Support for local builds, dry-run, force mode, and cache control
- **Latest Ubuntu**: Based on Ubuntu 25.04 with latest security updates

## Build Improvements Made

### 1. Non-Root User Creation
- Added explicit UID/GID (1997) for consistent user creation across architectures
- Uses `/bin/sh` instead of `/bin/bash` for better ARM64 compatibility
- Includes debugging commands to verify user creation

### 2. Dynamic PCRE Library Selection
- Automatically detects Zabbix version and installs correct PCRE library:
  - Zabbix 7.4.x → `libpcre2-dev` (PCRE2)
  - Zabbix 7.2.x → `libpcre3-dev` (PCRE3)

### 3. Multi-Platform Build Support
- Configured for both AMD64 and ARM64 architectures
- Includes SBOM and provenance for security scanning

## Building and Publishing

### Prerequisites
- Docker with buildx support
- Docker Hub account with repository access

### Using the Build Script

The `build_push_and_update_manifest.sh` script simplifies building and pushing the entire Zabbix stack (base, server, db, and ui images) for different architectures and Zabbix versions.

#### What Gets Built

The script builds and tags the following images:
- **Base**: `maborak/zabbix-base:<version>` - Core Zabbix binaries
- **Server**: `maborak/zabbix-server:<version>` - Zabbix server component
- **DB**: `maborak/zabbix-db:<version>` - Database schema initialization
- **UI**: `maborak/zabbix-ui:<version>` - Web interface

#### Script Parameters

- `--arch=<arch>` (required): Architecture(s) to build for. Can be:
  - Single: `arm64` or `amd64`
  - Multiple: `arm64,amd64` (comma-separated)
- `--zabbix-version=<version>` (optional): Zabbix version to build (default: `7.4.1`)
- `--set-latest` (optional): Also tag and push as `:latest` (default: `false`)
- `--verbose` (optional): Show full build output with `--progress=plain` (default: `false`)
- `--versions` (optional): List available Zabbix versions from GitHub and exit
- `--no-cache` (optional): Force rebuild without using cache (default: `false`)
- `--dry-run` (optional): Show what would be built/pushed without executing (default: `false`)
- `--force` (optional): Skip manifest checking, build only requested architectures (default: `false`)
- `--push=<true|false>` (optional): Push images to registry (default: `true`, use `--push=false` to build only)

#### Basic Usage Examples

```bash
# Build for a specific architecture with default Zabbix version (7.4.1)
./build_push_and_update_manifest.sh --arch=arm64

# Build for a specific architecture with custom Zabbix version
./build_push_and_update_manifest.sh --arch=amd64 --zabbix-version=7.4.2

# Build for multiple architectures at once
./build_push_and_update_manifest.sh --arch=arm64,amd64 --zabbix-version=7.4.2

# Build and also tag as :latest
./build_push_and_update_manifest.sh --arch=arm64 --zabbix-version=7.5.0 --set-latest

# Build entire stack locally without pushing
./build_push_and_update_manifest.sh --arch=amd64 --push=false

# List available Zabbix versions
./build_push_and_update_manifest.sh --versions

# Preview what would be built (dry-run)
./build_push_and_update_manifest.sh --arch=amd64,arm64 --zabbix-version=7.4.2 --dry-run
```

#### Advanced Usage Examples

```bash
# Build with verbose output
./build_push_and_update_manifest.sh --arch=amd64 --zabbix-version=7.4.2 --verbose

# Force rebuild without cache
./build_push_and_update_manifest.sh --arch=amd64 --zabbix-version=7.4.2 --no-cache

# Build only requested architectures (skip manifest merging)
./build_push_and_update_manifest.sh --arch=amd64 --zabbix-version=7.4.2 --force

# Build locally with force (no manifest check, no push)
./build_push_and_update_manifest.sh --arch=arm64,amd64 --push=false --force

# Build and set as latest with verbose output
./build_push_and_update_manifest.sh --arch=amd64 --zabbix-version=7.4.2 --set-latest --verbose
```

#### Multi-Architecture Manifest Behavior

The script automatically preserves existing architectures in manifests:

**Example Scenario:**
1. You previously built `maborak/zabbix-base:7.4.2` with both `arm64` and `amd64`
2. You run: `./build_push_and_update_manifest.sh --arch=amd64 --zabbix-version=7.4.2`
3. The script detects `arm64` exists and automatically builds both `arm64` and `amd64`
4. The multi-arch manifest is preserved

**To override this behavior:**
- Use `--force` flag to skip manifest checking and build only requested architectures

#### Building Multi-Architecture Manifests

You can build multi-architecture manifests in two ways:

**Method 1: Single command (recommended)**
```bash
# Build both architectures in one command
./build_push_and_update_manifest.sh --arch=arm64,amd64 --zabbix-version=7.4.2
```

**Method 2: Sequential builds**
```bash
# Build ARM64 first
./build_push_and_update_manifest.sh --arch=arm64 --zabbix-version=7.4.2

# Build AMD64 (will automatically merge with existing ARM64)
./build_push_and_update_manifest.sh --arch=amd64 --zabbix-version=7.4.2
```

### Manual Build (Alternative Method)

If you prefer to build manually without the script:

#### Setup Buildx Builder
```bash
docker buildx create --name mybuilder --use
```

#### Build Base Image
```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ZABBIX_VERSION=7.4.2 \
  -t maborak/zabbix-base:7.4.2 \
  -f base/Dockerfile \
  base/ \
  --push
```

#### Build Component Images
After the base image is built, build the components:

```bash
# Server
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ZABBIX_BASE=maborak/zabbix-base:7.4.2 \
  -t maborak/zabbix-server:7.4.2 \
  -f server/Dockerfile \
  server/ \
  --push

# Database
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ZABBIX_BASE=maborak/zabbix-base:7.4.2 \
  -t maborak/zabbix-db:7.4.2 \
  -f db/Dockerfile \
  db/ \
  --push

# UI
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ZABBIX_BASE=maborak/zabbix-base:7.4.2 \
  -t maborak/zabbix-ui:7.4.2 \
  -f ui/Dockerfile \
  ui/ \
  --push
```

**Note**: The build script automates all of this and handles manifest merging automatically.

## Version Management

### Using the Build Script

The easiest way to build different Zabbix versions is using the build script:

```bash
# Build a specific version
./build_push_and_update_manifest.sh --arch=amd64 --zabbix-version=7.4.2

# List available versions
./build_push_and_update_manifest.sh --versions
```

The script will build all components (base, server, db, ui) for the specified version.

### Image Structure

The build script creates a complete Zabbix stack:

- **Base Image** (`maborak/zabbix-base:<version>`): Contains compiled Zabbix binaries, UI files, and database schemas
- **Server Image** (`maborak/zabbix-server:<version>`): Zabbix server with all dependencies, uses base image
- **DB Image** (`maborak/zabbix-db:<version>`): MariaDB with Zabbix database schemas pre-loaded
- **UI Image** (`maborak/zabbix-ui:<version>`): Web interface using PHP-Nginx, uses base image

All component images reference the base image using the `ZABBIX_BASE` build argument, ensuring version consistency across the stack.

### Manual Build Method

To build manually without the script, you can use docker buildx directly:

```bash
# Build base image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ZABBIX_VERSION=7.4.2 \
  -t maborak/zabbix-base:7.4.2 \
  -f base/Dockerfile \
  base/ \
  --push

# Build server image (requires base image to exist)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ZABBIX_BASE=maborak/zabbix-base:7.4.2 \
  -t maborak/zabbix-server:7.4.2 \
  -f server/Dockerfile \
  server/ \
  --push
```

The build process automatically:
- Downloads the correct Zabbix source version
- Installs the appropriate PCRE library (PCRE2 for 7.4.x, PCRE3 for 7.2.x)
- Builds with all necessary dependencies

## Security Features

- **Non-root execution**: Container runs as `zabbix` user (UID 1997)
- **Explicit UID/GID**: Prevents user ID conflicts across platforms
- **Minimal attack surface**: Only necessary runtime dependencies installed
- **SBOM generation**: Enables vulnerability scanning
- **Build provenance**: Provides build transparency and audit trail

## Architecture Support

- **AMD64**: Full support with optimized builds
- **ARM64**: Full support with ARM-specific optimizations and compatibility fixes

## Troubleshooting

### ARM64 User Creation Issues
If you encounter "No default non-root user found" on ARM64:
- The Dockerfile includes debugging commands (`id zabbix`, `groups zabbix`)
- Check build logs for user creation verification
- Explicit UID/GID should resolve most ARM64-specific issues

### PCRE Library Errors
- For Zabbix 7.4.x: Uses `libpcre2-dev`
- For Zabbix 7.2.x: Uses `libpcre3-dev`
- The IF-ELSE condition automatically selects the correct library

## Usage

### Pulling Images

```bash
# Pull base image
docker pull maborak/zabbix-base:7.4.2

# Pull server image
docker pull maborak/zabbix-server:7.4.2

# Pull database image
docker pull maborak/zabbix-db:7.4.2

# Pull UI image
docker pull maborak/zabbix-ui:7.4.2
```

### Running the Stack

```bash
# Start database
docker run -d \
  --name zabbix-db \
  -e MYSQL_ROOT_PASSWORD=zabbix \
  -e MYSQL_DATABASE=zabbix \
  -e MYSQL_USER=zabbix \
  -e MYSQL_PASSWORD=zabbix \
  maborak/zabbix-db:7.4.2

# Start Zabbix server
docker run -d \
  --name zabbix-server \
  --link zabbix-db:mysql \
  -p 10051:10051 \
  maborak/zabbix-server:7.4.2

# Start Zabbix UI
docker run -d \
  --name zabbix-ui \
  --link zabbix-server:zabbix-server \
  -p 80:8080 \
  maborak/zabbix-ui:7.4.2
```

### Using Docker Compose

For a complete stack setup, use Docker Compose with all components.

## License

This project is licensed under the same license as Zabbix.
