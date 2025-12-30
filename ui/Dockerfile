ARG ZABBIX_BASE
ARG BUILD_DATE
FROM ${ZABBIX_BASE:-maborak/zabbix-base} AS base

# Use the trafex/php-nginx image with PHP 8.4
FROM trafex/php-nginx:3.9.0
ARG BUILD_DATE

LABEL org.opencontainers.image.title="Zabbix UI" \
      org.opencontainers.image.description="Zabbix web interface component" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/zabbix/zabbix" \
      maintainer="maborak"

WORKDIR /var/www/html
COPY --from=base /var/lib/zabbix_ui/ ./
USER root
RUN apk --no-cache add \
  php84-bcmath \
  php84-sockets \
  php84-xmlwriter \
  php84-gettext \
  php84-ldap \
  php84-zip
RUN chown -Rf nobody:nobody /var/www/html/conf/
USER nobody

