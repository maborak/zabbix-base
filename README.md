# Zabbix Base Docker Image

A multi-platform Docker image for Zabbix server and agent, built from source with security best practices.

## Features

- **Multi-platform support**: Built for both `linux/amd64` and `linux/arm64` architectures
- **Security-focused**: Runs as non-root user with explicit UID/GID
- **Version-flexible**: Automatically detects and installs correct PCRE library based on Zabbix version
- **SBOM and Provenance**: Includes Software Bill of Materials and build provenance for security
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

### Setup Buildx Builder
```bash
docker buildx create --name mybuilder --use
```

### Build and Push to Docker Hub
```bash
docker buildx build \
  --sbom=true \
  --provenance=true \
  --platform linux/amd64,linux/arm64 \
  -t maborak/zabbix-base:7.4.1 \
  . \
  --push
```

### Build Parameters
- `--sbom=true`: Generates Software Bill of Materials
- `--provenance=true`: Includes build provenance for security
- `--platform linux/amd64,linux/arm64`: Builds for both architectures
- `-t maborak/zabbix-base:7.4.1`: Tags the image
- `--push`: Pushes directly to Docker Hub

## Version Management

To build a different Zabbix version, modify the `ZABBIX_VERSION` argument in the Dockerfile:

```dockerfile
ARG ZABBIX_VERSION=7.4.1
```

The build process will automatically:
- Download the correct Zabbix source version
- Install the appropriate PCRE library (PCRE2 for 7.4.x, PCRE3 for 7.2.x)
- Build with all necessary dependencies

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

```bash
# Pull the image
docker pull maborak/zabbix-base:7.4.1

# Run with your configuration
docker run -d \
  --name zabbix-server \
  -p 10051:10051 \
  maborak/zabbix-base:7.4.1
```

## License

This project is licensed under the same license as Zabbix.
