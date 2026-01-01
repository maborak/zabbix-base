# Vulnerability Status and Fixes

This document tracks all identified vulnerabilities and their fix status.

## ✅ Fixed Vulnerabilities

### 1. GHSA-5j8p-438x-rgg5 (CRITICAL - CVSS 9.3)
- **Package**: `onelogin/php-saml` 4.0.0
- **Status**: ✅ **FIXED**
- **Fix**: Updated to version 4.3.1 via composer in base image
- **Location**: `base/Dockerfile` - automatically applied during build
- **Verification**: Tested and confirmed version 4.3.1 is installed

### 2. CVE-2025-10543 (MEDIUM - CVSS 6.3)
- **Package**: `github.com/eclipse/paho.mqtt.golang` < 1.5.1
- **Status**: ✅ **FIXED**
- **Fix**: Updated to version 1.5.1+ via `go get` before building Zabbix agent2
- **Location**: `base/Dockerfile` - updates Go dependency in agent2 source before compilation
- **Note**: This affects Zabbix agent2 which is written in Go

## ⚠️ Known Vulnerabilities

### Base Image (maborak/zabbix-base)

#### 1. CVE-2025-61729 (HIGH - CVSS 7.5)
- **Package**: `golang/stdlib` 1.24.10
- **Fixed Version**: 1.24.11+ or Go 1.25+
- **Status**: ✅ **FIXED**
- **Impact**: Affects runtime binaries (zabbix_agent2 is compiled with Go stdlib)
- **Fix**: Updated to use Go 1.25 from PPA (includes the fix)
- **Location**: `base/Dockerfile` - Go 1.25 installed from PPA
- **Note**: The vulnerability is in the Go stdlib compiled into zabbix_agent2 binary, so it affects runtime

#### 2. Ubuntu Kernel CVEs (MEDIUM)
- Multiple medium-severity CVEs in Ubuntu kernel packages (e.g., CVE-2022-3238, CVE-2023-26242, CVE-2022-0400, CVE-2022-25836)
- **Status**: ⚠️ **ACCEPTABLE RISK - NOT FIXABLE IN CONTAINER**
- **Details**: 
  - CVE-2022-3238: Linux kernel NTFS3 double-free vulnerability (CVSS 7.8)
  - Requires CAP_SYS_ADMIN privileges to exploit
  - Docker Scout shows "Fixed version: not fixed" for Ubuntu 25.04
- **Note**: These are kernel-level vulnerabilities that cannot be fixed within the container. They require:
  - Host kernel updates (if available)
  - Upgrading to a newer Ubuntu version with patched kernel
  - Waiting for Ubuntu 25.04 to release kernel security updates
- **Mitigation**: 
  - Run containers with minimal privileges (avoid CAP_SYS_ADMIN)
  - Keep host system kernel updated
  - Monitor Ubuntu security advisories for kernel updates

### UI Image (maborak/zabbix-ui)

#### 1. CVE-2025-49796, CVE-2025-49794 (CRITICAL)
- **Package**: `libxml2` 2.13.4-r5
- **Fixed Version**: 2.13.9-r0
- **Status**: ✅ **FIXED** (via `apk upgrade`)
- **Location**: `ui/Dockerfile` - `apk upgrade` updates all packages

#### 2. CVE-2025-4517 (CRITICAL)
- **Package**: `python3` 3.12.10-r0
- **Fixed Version**: 3.12.11-r0
- **Status**: ✅ **FIXED** (via `apk upgrade`)
- **Location**: `ui/Dockerfile` - `apk upgrade` updates all packages

#### 3. CVE-2023-27482 (CRITICAL)
- **Package**: `supervisor` 4.2.5-r5 (Alpine)
- **Fixed Version**: Not available
- **Status**: ⚠️ **NOT APPLICABLE**
- **Impact**: This vulnerability is in Alpine's supervisor package
- **Note**: The server image uses Ubuntu's supervisor (not Alpine), so this doesn't affect it. The UI image doesn't use supervisor at all. This CVE only appears in scans because the base Alpine image (trafex/php-nginx) includes it, but it's not actually used in our images.

#### 4. CVE-2025-66293, CVE-2025-65018, CVE-2025-64720 (HIGH)
- **Package**: `libpng` 1.6.47-r0
- **Fixed Version**: 1.6.53-r0
- **Status**: ✅ **FIXED** (via `apk upgrade`)
- **Location**: `ui/Dockerfile` - `apk upgrade` updates all packages

#### 5. CVE-2025-9086, CVE-2025-5399 (HIGH)
- **Package**: `curl` 8.12.1-r1
- **Fixed Version**: 8.14.1-r2
- **Status**: ✅ **FIXED** (via `apk upgrade`)
- **Location**: `ui/Dockerfile` - `apk upgrade` updates all packages

#### 6. CVE-2025-47273 (HIGH - CVSS 7.7)
- **Package**: `setuptools` 70.3.0 (Python)
- **Fixed Version**: 78.1.1
- **Status**: ⚠️ **TO FIX**
- **Impact**: Path traversal vulnerability in Python setuptools
- **Action**: Update setuptools via pip or apk if available
- **Note**: This is a Python package, may need to update via pip in the base image

## Fixes Applied

### Base Image (`base/Dockerfile`)
1. ✅ Added composer-based fix for `onelogin/php-saml` vulnerability
2. ✅ Updated Go to 1.25 (from PPA) to fix CVE-2025-61729
3. ✅ Updated `github.com/eclipse/paho.mqtt.golang` to 1.5.1+ to fix CVE-2025-10543
4. ✅ Enhanced security updates with `apt-get dist-upgrade` and `apt-get upgrade`

### UI Image (`ui/Dockerfile`)
1. ✅ Added `apk upgrade` to update all Alpine packages to latest versions
2. ✅ This automatically fixes: libxml2, python3, libpng, curl, and other packages

### Server Image (`server/Dockerfile`)
1. ✅ Enhanced security updates with `apt-get dist-upgrade` and `apt-get upgrade`

## Recommendations

### Immediate Actions
1. ✅ **onelogin/php-saml** - Fixed automatically in base image
2. ✅ **Go stdlib CVE-2025-61729** - Fixed by installing Go 1.24.11+ in base image
3. ✅ **Alpine packages** - Fixed via `apk upgrade` in UI image
4. ⚠️ **Supervisor** - Monitor for updates or consider alternatives

### Ongoing Maintenance
1. **Regular rebuilds**: Rebuild images monthly to get latest security patches
2. **Monitor base images**: 
   - Check for updates to `trafex/php-nginx:3.9.0`
   - Consider updating to newer Alpine versions when available
3. **Go version**: Currently using Go 1.25 (patched). Monitor for newer versions when available
4. **Supervisor**: Monitor Alpine repositories for supervisor updates

### Base Image Updates
- **Alpine**: Consider updating base image tag when `trafex/php-nginx` releases newer version
- **Ubuntu**: Already using latest 25.04 with security updates applied

## Testing

Use the test script to verify fixes:
```bash
./test-vulnerability-fix.sh 7.2.15
```

## References

- Docker Scout: `docker scout cves <image>`
- Zabbix Security: https://www.zabbix.com/support/security
- Alpine Security: https://alpinelinux.org/security/
- Ubuntu Security: https://ubuntu.com/security

