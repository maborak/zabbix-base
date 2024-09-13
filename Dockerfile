# Stage 1: Compile and build Zabbix
FROM ubuntu:noble AS builder 

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive 
ARG ZABBIX_MAJOR_VERSION=7.0 
ARG ZABBIX_MINOR_VERSION=3 

# Set working directory 
WORKDIR /build 

# Update repositories and install needed dependencies for Zabbix in one layer & clean up
RUN apt-get update && \
    apt-get -y install mariadb-client \
    mariadb-common \
    software-properties-common \
    ca-certificates \
    libpcre2-8-0 \
    wget \
    build-essential \
    automake \
    pkg-config \
    autoconf \
    autogen \
    libmysqlclient-dev \
    libxml2-dev \
    libsnmp-dev \
    libssh2-1-dev \
    libopenipmi-dev \
    libevent-dev \
    libevent-pthreads-2.1-7t64 \
    libcurl4-openssl-dev \
    libpcre3-dev \
    unixodbc-dev \
    openjdk-21-jdk \
    libldap2-dev \
    libgnutls28-dev \
    libmodbus-dev \
    golang-go \
    libmysqlclient-dev && \
    wget https://cdn.zabbix.com/zabbix/sources/stable/${ZABBIX_MAJOR_VERSION}/zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}.tar.gz && \
    tar xvfz zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}.tar.gz && \
    rm zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}.tar.gz && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /build/zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION} 

# Configure, build Zabbix in one layer
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
    --enable-java \
    --enable-webservice \
    --with-ldap \
    --enable-agent2 \
    --with-openssl \
    --with-libmodbus\
    --prefix=/var/lib/zabbix && \
    make -j$(nproc) && \
    make install


# Stage 2: Runtime Image
FROM ubuntu:noble 

# Set environment variables again
ARG ZABBIX_MAJOR_VERSION=7.0 
ARG ZABBIX_MINOR_VERSION=3 

COPY --from=builder /var/lib/zabbix/sbin/ /var/lib/zabbix/sbin/
COPY --from=builder /build/zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION} /var/lib/zabbix_tmp

# Clean up residual files 
RUN mv /var/lib/zabbix_tmp/ui /var/lib/zabbix_ui && \
    mv /var/lib/zabbix_tmp/database /var/lib/zabbix_db && \
    rm -Rf /var/lib/zabbix_tmp