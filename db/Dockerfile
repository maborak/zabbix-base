ARG ZABBIX_BASE
ARG ZABBIX_VERSION
ARG BUILD_DATE
FROM ${ZABBIX_BASE:-maborak/zabbix-base} AS base

FROM mariadb:11.1
ARG BUILD_DATE
ARG ZABBIX_VERSION
ARG VCS_REF
ARG GIT_COMMIT
ARG BUILD_NUMBER
ARG BUILD_URL

LABEL org.opencontainers.image.title="Zabbix Database" \
      org.opencontainers.image.description="Zabbix database initialization component" \
      org.opencontainers.image.version="${ZABBIX_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="maborak" \
      org.opencontainers.image.url="https://maborak.com" \
      org.opencontainers.image.documentation="https://github.com/maborak/zabbix-base/blob/main/README.md" \
      org.opencontainers.image.source="https://github.com/zabbix/zabbix" \
      org.opencontainers.image.vendor="maborak" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.base.name="mariadb:11.1" \
      maintainer="maborak" \
      docker.cmd="docker run -d maborak/zabbix-db:${ZABBIX_VERSION}" \
      docker.params="ZABBIX_VERSION=${ZABBIX_VERSION}" \
      security.scan.enabled="true" \
      security.policy.version="1.0" \
      com.docker.security.scan.enabled="true" \
      build.buildnumber="${BUILD_NUMBER}" \
      build.url="${BUILD_URL}" \
      build.timestamp="${BUILD_DATE}" \
      build.git.commit="${GIT_COMMIT}" \
      zabbix.version="${ZABBIX_VERSION}" \
      zabbix.component="database" \
      zabbix.database.type="mariadb" \
      zabbix.database.version="11.1" \
      io.kubernetes.pod.name="zabbix-db" \
      io.kubernetes.container.name="zabbix-database" \
      io.kubernetes.container.image="maborak/zabbix-db:${ZABBIX_VERSION}" \
      healthcheck.enabled="true" \
      healthcheck.interval="30s" \
      healthcheck.timeout="10s" \
      healthcheck.retries="3" \
      com.maborak.com.category="monitoring" \
      com.maborak.com.team="devops" \
      com.maborak.com.project="zabbix" \
      com.maborak.com.cost-center="engineering"

WORKDIR /docker-entrypoint-initdb.d/
COPY --from=base /var/lib/zabbix_db/mysql/schema.sql ./01-schema.sql
COPY --from=base /var/lib/zabbix_db/mysql/images.sql ./02-images.sql
COPY --from=base /var/lib/zabbix_db/mysql/data.sql ./03-data.sql

# Set environment variables for correct collation
ENV MARIADB_CHARACTER_SET_SERVER=utf8mb4
ENV MARIADB_COLLATION_SERVER=utf8mb4_bin
