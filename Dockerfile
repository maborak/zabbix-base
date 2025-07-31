# Define Zabbix version globally
ARG ZABBIX_VERSION=7.4.1
ARG UBUNTU_VERSION=25.04

# --------------------------------
# Stage 1: Build Zabbix
# --------------------------------
FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG ZABBIX_VERSION
ARG DEBIAN_FRONTEND=noninteractive
ARG GOLANG_VERSION=1.24

# Extract major and minor versions dynamically
ENV ZABBIX_MAJOR_VERSION=${ZABBIX_VERSION%.*} \
    ZABBIX_MINOR_VERSION=${ZABBIX_VERSION##*.} \
    PATH="${PATH}:/usr/lib/go-${GOLANG_VERSION}/bin"

# Working directory
WORKDIR /build

# Install dependencies in a single step
RUN apt-get update && apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
        mariadb-client mariadb-common \
        software-properties-common ca-certificates wget \
        build-essential automake pkg-config autoconf autogen \
        libmysqlclient-dev libxml2-dev libsnmp-dev libssh2-1-dev \
        libopenipmi-dev libevent-dev libcurl4-openssl-dev \
        unixodbc-dev libldap2-dev libgnutls28-dev libmodbus-dev \
        libevent-pthreads-2.1-7 && \
    if [ "${ZABBIX_MAJOR_VERSION}" = "7.4" ]; then \
        apt-get install -y --no-install-recommends libpcre2-dev; \
    else \
        apt-get install -y --no-install-recommends libpcre3-dev; \
    fi && \
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && \
    apt-get install -y --no-install-recommends golang-${GOLANG_VERSION} && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Download and extract Zabbix source
RUN wget https://cdn.zabbix.com/zabbix/sources/stable/${ZABBIX_MAJOR_VERSION}/zabbix-${ZABBIX_VERSION}.tar.gz && \
    tar -xzf zabbix-${ZABBIX_VERSION}.tar.gz && \
    rm zabbix-${ZABBIX_VERSION}.tar.gz

# Configure, compile, and install Zabbix
WORKDIR /build/zabbix-${ZABBIX_VERSION}
RUN ./configure \
        --enable-server \
        --enable-agent \
        --with-mysql \
        --enable-ipv6 \
        --with-net-snmp \
        --with-libcurl \
        --with-libxml2 \
        --with-openipmi \
        --with-ssh2 \
        --with-unixodbc \
        --enable-proxy \
        --enable-webservice \
        --enable-agent2 \
        --with-openssl \
        --with-libmodbus \
        --prefix=/var/lib/zabbix && \
    make -j"$(nproc)" && \
    make install && \
    go version

# --------------------------------
# Stage 2: Runtime Image
# --------------------------------
FROM ubuntu:${UBUNTU_VERSION}

ARG ZABBIX_VERSION
ENV ZABBIX_MAJOR_VERSION=${ZABBIX_VERSION%.*} \
    ZABBIX_MINOR_VERSION=${ZABBIX_VERSION##*.}

# Install runtime dependencies
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
        mariadb-client mariadb-common libmysqlclient* && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user for Zabbix
RUN groupadd -r -g 1997 zabbix && \
    useradd -r -u 1997 -g zabbix -d /var/lib/zabbix -s /bin/sh zabbix && \
    mkdir -p /var/lib/zabbix && \
    chown zabbix:zabbix /var/lib/zabbix && \
    id zabbix && \
    groups zabbix && \
    ls -la /var/lib/zabbix

# Copy built Zabbix binaries from the builder stage
COPY --from=builder /var/lib/zabbix/sbin/ /var/lib/zabbix/sbin/
COPY --from=builder /build/zabbix-${ZABBIX_VERSION} /var/lib/zabbix_tmp

# Organize runtime files
RUN mv /var/lib/zabbix_tmp/ui /var/lib/zabbix_ui && \
    mv /var/lib/zabbix_tmp/database /var/lib/zabbix_db && \
    chown -R zabbix:zabbix /var/lib/zabbix* && \
    rm -rf /var/lib/zabbix_tmp

# Set working directory and switch to non-root user
WORKDIR /var/lib/zabbix
USER zabbix