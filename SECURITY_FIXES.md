# Security Vulnerability Fixes

This document outlines the security fixes implemented and additional actions you can take to address vulnerabilities found in Docker Scout scans.

## Fixes Implemented

### 1. ✅ PHP SAML Vulnerability (GHSA-5j8p-438x-rgg5 - Critical)
- **Location**: Base Dockerfile (applied before UI is copied)
- **Fix**: Direct package replacement - downloads and installs `onelogin/php-saml` v4.3.1 to replace vulnerable 4.0.0 version
- **Method**: 
  - First tries composer update if composer.json exists
  - Falls back to direct download and replacement of vendor package
  - Updates installed.json to reflect new version
- **Status**: Automatically applied during base image build

### 2. ✅ Security Updates
- **Location**: Base and Server Dockerfiles
- **Fix**: Enhanced `apt-get dist-upgrade` and `apt-get upgrade` to ensure all security patches are applied
- **Status**: Automatically applied during build

### 3. ✅ Zabbix Version Update
- **Location**: Base Dockerfile
- **Fix**: Updated default Zabbix version from 7.4.1 to 7.4.6
- **Status**: Use `--zabbix-version=7.4.6` or latest when building

## Additional Actions You Can Take

### 1. Update to Latest Zabbix Version
Always use the latest Zabbix version when building:
```bash
./build_push_and_update_manifest.sh --zabbix-version=7.4.6
```

Check for newer versions:
```bash
./build_push_and_update_manifest.sh --versions
```

### 2. Update Base Images Regularly
- **Ubuntu**: Check for latest 25.04 updates
- **MariaDB**: Update from 11.1 to latest if available
- **PHP-Nginx**: Update trafex/php-nginx:3.9.0 to latest

### 3. Update Go Version (for build-time vulnerability)
The Go stdlib vulnerability (CVE-2025-61729) is in build tools only. To update:
- Check latest Go version: https://go.dev/dl/
- Update `GOLANG_VERSION` in base/Dockerfile if newer version is available

### 4. Regular Security Scanning
Add to your CI/CD pipeline:
```bash
# Scan before pushing
docker scout cves maborak/zabbix-base:latest

# Or use Docker Hub automated scanning (already enabled)
```

### 5. Monitor for New Vulnerabilities
- Set up Docker Hub notifications for new vulnerabilities
- Regularly rebuild images even if code hasn't changed (to get latest base image patches)
- Subscribe to Zabbix security advisories: https://www.zabbix.com/support/security

### 6. Manual Dependency Updates
If composer update doesn't work automatically, you can manually patch:

```dockerfile
# In UI Dockerfile, add after copying files:
RUN cd /var/www/html && \
    if [ -f "composer.json" ]; then \
        composer update onelogin/php-saml --no-interaction --no-scripts; \
    fi
```

### 7. Use Specific Base Image Tags
Instead of `ubuntu:25.04`, use specific patch versions:
```dockerfile
FROM ubuntu:25.04-20250101  # Use date-based tags when available
```

## Known Limitations

1. **PHP SAML Update**: If Zabbix source doesn't include `composer.json`, the automatic update may not work. In this case:
   - Wait for Zabbix to release a version with the fix
   - Or manually patch the vendor directory (not recommended for production)

2. **Go Build Vulnerability**: This only affects the build process, not runtime. Consider it lower priority.

3. **Ubuntu Package Vulnerabilities**: Some may require waiting for Ubuntu security updates. The `dist-upgrade` ensures you get the latest available patches.

## Verification

After rebuilding, verify fixes:
```bash
# Build your images
./build_push_and_update_manifest.sh --zabbix-version=7.4.6

# Scan the new image
docker scout cves maborak/zabbix-base:7.4.6

# Check specific vulnerability
docker scout cves maborak/zabbix-base:7.4.6 --only-severity critical
```

## Best Practices Going Forward

1. **Always use latest Zabbix version** when building
2. **Rebuild images monthly** even without code changes (to get base image updates)
3. **Monitor Docker Hub** for automated scan results
4. **Keep build scripts updated** with latest versions
5. **Document any manual patches** applied

## Resources

- Docker Scout: https://docs.docker.com/scout/
- Zabbix Security: https://www.zabbix.com/support/security
- Ubuntu Security: https://ubuntu.com/security
- CVE Database: https://cve.mitre.org/

