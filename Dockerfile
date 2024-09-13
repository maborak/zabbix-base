FROM ubuntu:noble

RUN apt-get update
ARG DEBIAN_FRONTEND=noninteractive
ARG ZABBIX_MAJOR_VERSION=7.0
ARG ZABBIX_MINOR_VERSION=3

WORKDIR /build

RUN apt-get -y install mariadb-client \
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
    apt-get clean

RUN wget https://cdn.zabbix.com/zabbix/sources/stable/${ZABBIX_MAJOR_VERSION}/zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}.tar.gz && \
    tar xvfz zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}.tar.gz && \
    rm zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}.tar.gz

WORKDIR /build/zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}

RUN ./configure     \
    --enable-server \
    --enable-agent  \
    --with-mysql    \
    --enable-ipv6   \
    --with-net-snmp \
    --with-libcurl  \
    --with-libxml2  \
    --with-openipmi \
    --with-ssh2     \
    --with-unixodbc \
    --enable-proxy  \
    --enable-java   \
    --enable-webservice  \
    --enable-ipv6   \
    --with-ldap     \
    --enable-agent2 \
    --with-openssl  \
    --with-libmodbus\
    --prefix=/var/lib/zabbix && \
    make -j$(nproc) && \
    make install

WORKDIR /build

RUN mv zabbix-*/ui /var/lib/zabbix_ui && \
    mv zabbix-*/database /var/lib/zabbix_db && \
    rm -Rf zabbix* /tmp/go/