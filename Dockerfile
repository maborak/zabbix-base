# Stage 1: Compile and build Zabbix
FROM ubuntu:noble AS builder 

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive 
ARG ZABBIX_MAJOR_VERSION=7.0
ARG ZABBIX_MINOR_VERSION=3
ARG GOLANG_VERSION=1.23
# Set working directory 
WORKDIR /build 
ENV PATH="${PATH}:/usr/lib/go-${GOLANG_VERSION}/bin"
# Update repositories and install needed dependencies for Zabbix in one layer & clean up
RUN apt-get update && \
    apt-get -y install mariadb-client \
    mariadb-common \
    software-properties-common \
    ca-certificates \
    libpcre2-8-0 \
    wget \
    git \
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
    #openjdk-21-jdk \
    libldap2-dev \
    libgnutls28-dev \
    libmodbus-dev \
    libmysqlclient-dev && \
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && apt-get -y install golang-${GOLANG_VERSION} && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    git clone --verbose https://github.com/zabbix/zabbix.git && \
    cd zabbix/ && \
    sh bootstrap.sh && \
    ./configure \
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
    #--enable-java \
    --enable-webservice \
    #--with-ldap \
    --enable-agent2 \
    --with-openssl \
    --with-libmodbus\
    --prefix=/var/lib/zabbix && \
    make -j$(nproc) && \
    make install && \
    mv /build/zabbix/ui /var/lib/zabbix_ui && \
    mv /build/zabbix/database /var/lib/zabbix_database && \
    rm -Rf /build/zabbix
    

# Stage 2: Runtime Image
FROM ubuntu:noble

COPY --from=builder /var/lib/zabbix/sbin/ /var/lib/zabbix/sbin/
COPY --from=builder /var/lib/zabbix_ui /var/lib/zabbix_ui
COPY --from=builder /var/lib/zabbix_database /var/lib/zabbix_db
