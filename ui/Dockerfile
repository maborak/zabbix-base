ARG ZABBIX_BASE
ARG ZABBIX_VERSION
ARG BUILD_DATE
FROM ${ZABBIX_BASE:-maborak/zabbix-base} AS base

# Use the trafex/php-nginx image with PHP 8.4
FROM trafex/php-nginx:3.9.0
ARG BUILD_DATE
ARG ZABBIX_VERSION
ARG VCS_REF
ARG GIT_COMMIT
ARG BUILD_NUMBER
ARG BUILD_URL

LABEL org.opencontainers.image.title="Zabbix UI" \
      org.opencontainers.image.description="Zabbix web interface component" \
      org.opencontainers.image.version="${ZABBIX_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="maborak" \
      org.opencontainers.image.url="https://maborak.com" \
      org.opencontainers.image.documentation="https://github.com/maborak/zabbix-base/blob/main/README.md" \
      org.opencontainers.image.source="https://github.com/zabbix/zabbix" \
      org.opencontainers.image.vendor="maborak" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.base.name="trafex/php-nginx:3.9.0" \
      maintainer="maborak" \
      docker.cmd="docker run -d maborak/zabbix-ui:${ZABBIX_VERSION}" \
      docker.params="ZABBIX_VERSION=${ZABBIX_VERSION}" \
      security.scan.enabled="true" \
      security.policy.version="1.0" \
      com.docker.security.scan.enabled="true" \
      build.buildnumber="${BUILD_NUMBER}" \
      build.url="${BUILD_URL}" \
      build.timestamp="${BUILD_DATE}" \
      build.git.commit="${GIT_COMMIT}" \
      zabbix.version="${ZABBIX_VERSION}" \
      zabbix.component="ui" \
      zabbix.php.version="8.4" \
      zabbix.nginx.version="3.9.0" \
      io.kubernetes.pod.name="zabbix-ui" \
      io.kubernetes.container.name="zabbix-ui" \
      io.kubernetes.container.image="maborak/zabbix-ui:${ZABBIX_VERSION}" \
      healthcheck.enabled="true" \
      healthcheck.interval="30s" \
      healthcheck.timeout="10s" \
      healthcheck.retries="3" \
      com.maborak.com.category="monitoring" \
      com.maborak.com.team="devops" \
      com.maborak.com.project="zabbix" \
      com.maborak.com.cost-center="engineering"

WORKDIR /var/www/html
COPY --from=base /var/lib/zabbix_ui/ ./
USER root

# Update Alpine packages to fix security vulnerabilities
# This updates: libxml2, python3, libpng, curl, and other packages
RUN apk update && \
    apk upgrade --no-cache && \
    apk --no-cache add \
      php84-bcmath \
      php84-sockets \
      php84-xmlwriter \
      php84-gettext \
      php84-ldap \
      php84-zip \
      python3 \
      py3-pip && \
    # Fix setuptools vulnerability CVE-2025-47273 (requires >= 78.1.1)
    echo "Updating setuptools to fix CVE-2025-47273..." && \
    pip3 install --upgrade --no-cache-dir --break-system-packages 'setuptools>=78.1.1' && \
    echo "Verifying setuptools version..." && \
    python3 -c "import setuptools; print(f'setuptools version: {setuptools.__version__}')" && \
    # Clean up pip if not needed
    apk del py3-pip

# Note: Vulnerability fix for onelogin/php-saml is applied in base image
# This ensures the fix is applied once in the base image before copying to UI image

RUN chown -Rf nobody:nobody /var/www/html/conf/ /var/www/html/vendor/ 2>/dev/null || true
USER nobody

