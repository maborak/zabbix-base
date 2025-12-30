ARG ZABBIX_BASE
ARG BUILD_DATE
FROM ${ZABBIX_BASE:-maborak/zabbix-base} AS base

FROM mariadb:11.1
ARG BUILD_DATE

LABEL org.opencontainers.image.title="Zabbix Database" \
      org.opencontainers.image.description="Zabbix database initialization component" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/zabbix/zabbix" \
      maintainer="maborak"

WORKDIR /docker-entrypoint-initdb.d/
COPY --from=base /var/lib/zabbix_db/mysql/schema.sql ./01-schema.sql
COPY --from=base /var/lib/zabbix_db/mysql/images.sql ./02-images.sql
COPY --from=base /var/lib/zabbix_db/mysql/data.sql ./03-data.sql

# Set environment variables for correct collation
ENV MARIADB_CHARACTER_SET_SERVER=utf8mb4
ENV MARIADB_COLLATION_SERVER=utf8mb4_bin
