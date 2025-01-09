# --------------------------------
# Stage 1: Build Zabbix
# --------------------------------
    FROM ubuntu:noble AS builder

    ARG DEBIAN_FRONTEND=noninteractive
    ARG ZABBIX_MAJOR_VERSION=7.0
    ARG ZABBIX_MINOR_VERSION=3
    ARG GOLANG_VERSION=1.23
    
    # Working directory
    WORKDIR /build
    
    ENV PATH="${PATH}:/usr/lib/go-${GOLANG_VERSION}/bin"
    
    # ----- Step 1: Update & Dist-Upgrade (Optional but often helps)
    RUN apt-get update && \
        apt-get dist-upgrade -y && \
        apt-get clean && rm -rf /var/lib/apt/lists/*
    
    # ----- Step 2: Install first batch of packages
    RUN apt-get update && \
        apt-get -y install \
          mariadb-client \
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
          libldap2-dev \
          libgnutls28-dev \
          libmodbus-dev \
          libmysqlclient-dev && \
        apt-get clean && rm -rf /var/lib/apt/lists/*
    
    # ----- Step 3: Add Golang PPA & Install Go
    RUN apt-get update && \
        add-apt-repository ppa:longsleep/golang-backports && \
        apt-get update && \
        apt-get -y install golang-${GOLANG_VERSION} && \
        apt-get clean && rm -rf /var/lib/apt/lists/*
    
    # ----- Step 4: Download & Extract Zabbix
    RUN wget https://cdn.zabbix.com/zabbix/sources/stable/${ZABBIX_MAJOR_VERSION}/zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}.tar.gz && \
        tar xvfz zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}.tar.gz && \
        rm zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}.tar.gz
    
    # ----- Step 5: Configure & Compile Zabbix
    WORKDIR /build/zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION}
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
        --prefix=/var/lib/zabbix
    RUN LDFLAGS="-lm" make -j"$(nproc)" && \
        make install && \
        go version
    
    
    # --------------------------------
    # Stage 2: Runtime Image
    # --------------------------------
    FROM ubuntu:noble
    
    ARG ZABBIX_MAJOR_VERSION=7.0
    ARG ZABBIX_MINOR_VERSION=3
    
    # Copy installed Zabbix from builder
    COPY --from=builder /var/lib/zabbix/sbin/ /var/lib/zabbix/sbin/
    COPY --from=builder /build/zabbix-${ZABBIX_MAJOR_VERSION}.${ZABBIX_MINOR_VERSION} /var/lib/zabbix_tmp
    
    # Organize files in final image
    RUN mv /var/lib/zabbix_tmp/ui /var/lib/zabbix_ui && \
        mv /var/lib/zabbix_tmp/database /var/lib/zabbix_db && \
        rm -rf /var/lib/zabbix_tmp