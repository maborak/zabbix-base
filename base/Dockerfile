# Define Zabbix version globally
ARG ZABBIX_VERSION=7.4.6
ARG UBUNTU_VERSION=25.04
ARG BUILD_DATE

# --------------------------------
# Stage 1: Build Zabbix
# --------------------------------
FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG ZABBIX_VERSION
ARG BUILD_DATE
ARG DEBIAN_FRONTEND=noninteractive
ARG GOLANG_VERSION=1.25

# Extract major and minor versions dynamically
ENV ZABBIX_MAJOR_VERSION=${ZABBIX_VERSION%.*} \
    ZABBIX_MINOR_VERSION=${ZABBIX_VERSION##*.} \
    PATH="${PATH}:/usr/lib/go-${GOLANG_VERSION}/bin:/usr/local/go/bin"

# Working directory
WORKDIR /build

# Install dependencies in a single step
RUN apt-get update && apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
        mariadb-client mariadb-common \
        software-properties-common ca-certificates wget \
        build-essential gpg gpg-agent gcc g++ automake pkg-config autoconf autogen \
        libmysqlclient-dev libxml2-dev libsnmp-dev libssh2-1-dev \
        libopenipmi-dev libevent-dev libcurl4-openssl-dev \
        unixodbc-dev libldap2-dev libgnutls28-dev libmodbus-dev \
        libevent-pthreads-2.1-7 && \
    if [ "${ZABBIX_MAJOR_VERSION}" = "7.4" ]; then \
        apt-get install -y --no-install-recommends libpcre2-dev; \
    else \
        apt-get install -y --no-install-recommends libpcre3-dev; \
    fi && \
    # Install Go 1.25 from PPA to fix CVE-2025-61729 (Go 1.25 includes the fix)
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && \
    apt-get install -y --no-install-recommends golang-${GOLANG_VERSION} && \
    go version && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Download and extract Zabbix source
RUN wget https://cdn.zabbix.com/zabbix/sources/stable/${ZABBIX_MAJOR_VERSION}/zabbix-${ZABBIX_VERSION}.tar.gz && \
    tar -xzf zabbix-${ZABBIX_VERSION}.tar.gz && \
    rm zabbix-${ZABBIX_VERSION}.tar.gz

# Configure, compile, and install Zabbix
WORKDIR /build/zabbix-${ZABBIX_VERSION}

# Fix CVE-2025-10543: Update github.com/eclipse/paho.mqtt.golang to >= 1.5.1
# This vulnerability affects Zabbix agent2 Go dependencies
# Find and update go.mod in agent2 directory, then sync vendor directory
RUN if [ -d "src/go" ] && [ -f "src/go/go.mod" ]; then \
    echo "=========================================" && \
    echo "Updating paho.mqtt.golang to fix CVE-2025-10543..." && \
    echo "=========================================" && \
    cd src/go && \
    echo "Current directory: $(pwd)" && \
    echo "" && \
    echo "Step 1: Updating dependency to v1.5.1..." && \
    go get github.com/eclipse/paho.mqtt.golang@v1.5.1 && \
    echo "" && \
    echo "Step 2: Running go mod tidy..." && \
    go mod tidy && \
    echo "" && \
    echo "Step 3: Syncing vendor directory..." && \
    go mod vendor && \
    echo "" && \
    echo "Step 4: Verifying vendor sync..." && \
    go mod verify && \
    echo "" && \
    echo "Step 5: Checking updated version..." && \
    grep -A 2 "github.com/eclipse/paho.mqtt.golang" go.mod || true && \
    echo "" && \
    echo "✓ Successfully updated paho.mqtt.golang dependency and synced vendor directory"; \
    fi

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
RUN make -j"$(nproc)"
RUN make install
RUN go version

# --------------------------------
# Stage 2: Runtime Image
# --------------------------------
FROM ubuntu:${UBUNTU_VERSION}

ARG ZABBIX_VERSION
ARG UBUNTU_VERSION
ARG BUILD_DATE
ARG GOLANG_VERSION=1.25
ARG VCS_REF
ARG GIT_COMMIT
ARG BUILD_NUMBER
ARG BUILD_URL

LABEL org.opencontainers.image.title="Zabbix Base" \
      org.opencontainers.image.description="Zabbix server and agent base image" \
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
      docker.cmd="docker run -d maborak/zabbix-base:${ZABBIX_VERSION}" \
      docker.params="ZABBIX_VERSION=${ZABBIX_VERSION},UBUNTU_VERSION=${UBUNTU_VERSION}" \
      security.scan.enabled="true" \
      security.policy.version="1.0" \
      com.docker.security.scan.enabled="true" \
      build.buildnumber="${BUILD_NUMBER}" \
      build.url="${BUILD_URL}" \
      build.timestamp="${BUILD_DATE}" \
      zabbix.version="${ZABBIX_VERSION}" \
      zabbix.component="base" \
      zabbix.ubuntu.version="${UBUNTU_VERSION}" \
      zabbix.golang.version="${GOLANG_VERSION}" \
      io.kubernetes.pod.name="zabbix-base" \
      io.kubernetes.container.name="zabbix" \
      io.kubernetes.container.image="maborak/zabbix-base:${ZABBIX_VERSION}" \
      healthcheck.enabled="true" \
      healthcheck.interval="30s" \
      healthcheck.timeout="10s" \
      healthcheck.retries="3" \
      com.maborak.com.category="monitoring" \
      com.maborak.com.team="devops" \
      com.maborak.com.project="zabbix" \
      com.maborak.com.cost-center="engineering"

ENV ZABBIX_MAJOR_VERSION=${ZABBIX_VERSION%.*} \
    ZABBIX_MINOR_VERSION=${ZABBIX_VERSION##*.}

# Install runtime dependencies and apply security updates
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
        mariadb-client mariadb-common libmysqlclient* && \
    apt-get upgrade -y && \
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
    rm -rf /var/lib/zabbix_tmp

# Fix critical vulnerability GHSA-5j8p-438x-rgg5 in UI vendor dependencies
# Update onelogin/php-saml from 4.0.0 to 4.3.1+ using composer
# This step runs after UI files are copied, ensuring it executes when UI files change
# Cache-friendly: Uses cached layers for earlier steps, only runs fix when UI content changes
RUN if [ -f "/var/lib/zabbix_ui/vendor/composer/installed.json" ]; then \
    apt-get update && \
    apt-get install -y --no-install-recommends composer php-cli php-curl php-zip unzip ca-certificates && \
    cd /var/lib/zabbix_ui && \
    echo "Checking for onelogin/php-saml vulnerability..." && \
    if grep -q '"name".*"onelogin/php-saml"' vendor/composer/installed.json 2>/dev/null; then \
        VERSION=$(grep -A 10 '"name".*onelogin/php-saml' vendor/composer/installed.json | grep '"version"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/') && \
        echo "Detected onelogin/php-saml version: ${VERSION:-unknown}" && \
        if [ -n "$VERSION" ] && [ "$(printf '%s\n' "4.0.0" "$VERSION" | sort -V | head -1)" = "4.0.0" ] && [ "$(printf '%s\n' "$VERSION" "4.3.1" | sort -V | head -1)" = "$VERSION" ]; then \
            echo "CRITICAL: Found vulnerable version $VERSION, updating to ^4.3.1 via composer..." && \
            if [ -f "composer.json" ]; then \
                composer require --no-interaction --no-scripts --update-with-dependencies onelogin/php-saml:"^4.3.1" 2>&1 | head -30 && \
                echo "✓ Composer update completed"; \
            else \
                echo "Creating minimal composer.json to update package..." && \
                echo '{"require":{"onelogin/php-saml":"^4.3.1"}}' > composer.json.tmp && \
                composer require --no-interaction --no-scripts --update-with-dependencies onelogin/php-saml:"^4.3.1" 2>&1 | head -30 && \
                rm -f composer.json.tmp && \
                echo "✓ Package updated via composer"; \
            fi && \
            echo "Verifying fix..." && \
            if [ -f "vendor/composer/installed.json" ]; then \
                NEW_VERSION=$(grep -A 10 '"name".*onelogin/php-saml' vendor/composer/installed.json 2>/dev/null | grep '"version"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/') && \
                if [ -n "$NEW_VERSION" ] && [ "$(printf '%s\n' "4.3.1" "$NEW_VERSION" | sort -V | head -1)" = "4.3.1" ]; then \
                    echo "✓ Verification successful: Version is now $NEW_VERSION (>= 4.3.1)"; \
                else \
                    echo "⚠ Warning: Version check - $NEW_VERSION"; \
                fi; \
            fi; \
        else \
            echo "✓ Version $VERSION is already patched (>= 4.3.1)"; \
        fi; \
    else \
        echo "✓ onelogin/php-saml not found in dependencies"; \
    fi && \
    apt-get purge -y composer php-cli php-curl php-zip unzip && \
    apt-get autoremove -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi

# Set ownership after vulnerability fix
RUN chown -R zabbix:zabbix /var/lib/zabbix*

# Set working directory and switch to non-root user
WORKDIR /var/lib/zabbix
USER zabbix