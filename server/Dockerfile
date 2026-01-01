ARG ZABBIX_BASE
ARG ZABBIX_VERSION
ARG UBUNTU_VERSION=25.04
ARG BUILD_DATE
FROM ${ZABBIX_BASE:-maborak/zabbix-base} AS base

FROM ubuntu:${UBUNTU_VERSION}
ARG UBUNTU_VERSION
ARG BUILD_DATE
ARG ZABBIX_VERSION
ARG VCS_REF
ARG GIT_COMMIT
ARG BUILD_NUMBER
ARG BUILD_URL

LABEL org.opencontainers.image.title="Zabbix Server" \
      org.opencontainers.image.description="Zabbix server component" \
      org.opencontainers.image.version="${ZABBIX_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="maborak" \
      org.opencontainers.image.url="https://maborak.com" \
      org.opencontainers.image.documentation="https://github.com/maborak/zabbix-base/blob/main/README.md" \
      org.opencontainers.image.source="https://github.com/zabbix/zabbix" \
      org.opencontainers.image.vendor="maborak" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.base.name="ubuntu:${UBUNTU_VERSION}" \
      maintainer="maborak" \
      docker.cmd="docker run -d maborak/zabbix-server:${ZABBIX_VERSION}" \
      docker.params="ZABBIX_VERSION=${ZABBIX_VERSION},UBUNTU_VERSION=${UBUNTU_VERSION}" \
      security.scan.enabled="true" \
      security.policy.version="1.0" \
      com.docker.security.scan.enabled="true" \
      build.buildnumber="${BUILD_NUMBER}" \
      build.url="${BUILD_URL}" \
      build.timestamp="${BUILD_DATE}" \
      build.git.commit="${GIT_COMMIT}" \
      zabbix.version="${ZABBIX_VERSION}" \
      zabbix.component="server" \
      zabbix.ubuntu.version="${UBUNTU_VERSION}" \
      zabbix.ports="9997,10050" \
      io.kubernetes.pod.name="zabbix-server" \
      io.kubernetes.container.name="zabbix-server" \
      io.kubernetes.container.image="maborak/zabbix-server:${ZABBIX_VERSION}" \
      healthcheck.enabled="true" \
      healthcheck.interval="30s" \
      healthcheck.timeout="10s" \
      healthcheck.retries="3" \
      com.maborak.com.category="monitoring" \
      com.maborak.com.team="devops" \
      com.maborak.com.project="zabbix" \
      com.maborak.com.cost-center="engineering"

WORKDIR /var/lib/zabbix/
COPY --from=base /var/lib/zabbix/ ./
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get dist-upgrade -y
RUN apt-get install -y \
    bash \
    tzdata \
    ca-certificates \
    iputils-ping \
    traceroute \
    fping \
    libcurl4 \
    libevent-2.1 \
    libmysqlclient24 \
    libopenipmi0 \
    libpcre3 \
    libsnmp-dev \
    libssh2-1-dev \
    libevent-dev \
    libevent-extra* \
    libevent-pthreads* \
    libssl-dev \
    libxml2 \
    mysql-client \
    net-tools \
    snmp-mibs-downloader \
    unixodbc \
    supervisor && \
    apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
RUN groupadd --system --gid 1995 zabbix && \
    useradd -r -u 1997 --home /var/lib/zabbix --gid zabbix -s /sbin/nologin zabbix

# Copy the configuration files
COPY zabbix_server.conf /var/lib/zabbix/etc/zabbix_server.conf
COPY zabbix_agent2.conf /var/lib/zabbix/etc/zabbix_agent2.conf

# Create supervisor configuration and log directories
RUN mkdir -p /etc/supervisor/conf.d /var/lib/zabbix/log /var/lib/zabbix/run /var/lib/zabbix/etc/zabbix_agent2.d
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chown -R zabbix:zabbix /var/lib/zabbix/log /var/lib/zabbix/run

USER 1997
EXPOSE 9997 10050
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
