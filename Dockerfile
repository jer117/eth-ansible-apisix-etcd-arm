ARG VERSION=3.14.0
FROM ubuntu:22.04 AS builder

# Set build arguments
ARG VERSION=3.14.0
ARG DEBIAN_FRONTEND=noninteractive
ARG ETCD_VERSION=v3.5.11

# Set environment variables
ENV APISIX_VERSION=${VERSION}
ENV OPENRESTY_VERSION=1.21.4.3
ENV PATH=/usr/local/openresty/bin:/usr/local/openresty/nginx/sbin:$PATH

# Install basic dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gnupg \
    ca-certificates \
    curl \
    git \
    sudo \
    unzip \
    software-properties-common \
    lsb-release \
    build-essential \
    libreadline-dev \
    libncurses5-dev \
    libpcre3-dev \
    libssl-dev \
    perl \
    make \
    && rm -rf /var/lib/apt/lists/*

# Import OpenResty GPG key
RUN wget -O - https://openresty.org/package/pubkey.gpg | apt-key add -

# Add OpenResty APT repository for ARM64
RUN echo "deb http://openresty.org/package/arm64/ubuntu $(lsb_release -sc) main" \
    | tee /etc/apt/sources.list.d/openresty.list

# Update and install OpenResty
RUN apt-get update && apt-get install -y --no-install-recommends \
    openresty \
    openresty-resty \
    openresty-opm \
    && rm -rf /var/lib/apt/lists/*

# Clone Apache APISIX source code
WORKDIR /tmp
RUN git clone https://github.com/apache/apisix.git && \
    cd apisix && \
    git checkout ${VERSION}

# Install LuaRocks
WORKDIR /tmp/apisix
RUN curl https://raw.githubusercontent.com/apache/apisix/master/utils/linux-install-luarocks.sh -sL | bash -

# Install APISIX dependencies
RUN bash utils/install-dependencies.sh || true

# Install APISIX dependencies with LuaRocks
ENV LUAROCKS_SERVER=https://luarocks.cn
RUN make deps || true

# Build and install APISIX
RUN make install

# Download and install etcd for ARM64
WORKDIR /tmp
RUN ETCD_ARCH="arm64" && \
    wget https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${ETCD_ARCH}.tar.gz && \
    tar -xvf etcd-${ETCD_VERSION}-linux-${ETCD_ARCH}.tar.gz && \
    cd etcd-${ETCD_VERSION}-linux-${ETCD_ARCH} && \
    cp etcd /usr/local/bin/ && \
    cp etcdctl /usr/local/bin/ && \
    cp etcdutl /usr/local/bin/ && \
    cd .. && \
    rm -rf etcd-${ETCD_VERSION}-linux-${ETCD_ARCH}*

# Final stage - create minimal runtime image
FROM ubuntu:22.04

ARG VERSION=3.14.0
ARG DEBIAN_FRONTEND=noninteractive

ENV APISIX_VERSION=${VERSION}
ENV PATH=/usr/local/openresty/bin:/usr/local/openresty/nginx/sbin:/usr/local/apisix:$PATH

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gnupg \
    ca-certificates \
    curl \
    libpcre3 \
    libssl3 \
    lsb-release \
    lua5.1 \
    liblua5.1-0 \
    && rm -rf /var/lib/apt/lists/*

# Import OpenResty GPG key and add repository
RUN wget -O - https://openresty.org/package/pubkey.gpg | apt-key add - && \
    echo "deb http://openresty.org/package/arm64/ubuntu $(lsb_release -sc) main" \
    | tee /etc/apt/sources.list.d/openresty.list

# Install OpenResty runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    openresty \
    && rm -rf /var/lib/apt/lists/*

# Copy etcd binaries from builder
COPY --from=builder /usr/local/bin/etcd /usr/local/bin/etcd
COPY --from=builder /usr/local/bin/etcdctl /usr/local/bin/etcdctl
COPY --from=builder /usr/local/bin/etcdutl /usr/local/bin/etcdutl

# Copy APISIX installation from builder
COPY --from=builder /usr/local/apisix /usr/local/apisix
COPY --from=builder /usr/bin/apisix /usr/bin/apisix
COPY --from=builder /tmp/apisix/apisix /usr/local/share/lua/5.1/apisix
COPY --from=builder /tmp/apisix/conf /usr/local/apisix/conf-template
COPY --from=builder /usr/local/share/lua /usr/local/share/lua

# Create necessary directories
RUN mkdir -p /usr/local/apisix/logs \
    /usr/local/apisix/conf \
    /var/lib/etcd \
    /var/log/etcd && \
    if [ ! -f /usr/local/apisix/conf/config.yaml ]; then \
      cp -r /usr/local/apisix/conf-template/* /usr/local/apisix/conf/ 2>/dev/null || true; \
    fi

# Set working directory
WORKDIR /usr/local/apisix

# Expose ports
# 9080 - APISIX HTTP
# 9443 - APISIX HTTPS
# 9180 - APISIX Admin API
# 2379 - etcd client
# 2380 - etcd peer
EXPOSE 9080 9443 9180 2379 2380

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Start etcd in background\n\
echo "Starting etcd..."\n\
etcd --data-dir=/var/lib/etcd \\\n\
  --listen-client-urls http://0.0.0.0:2379 \\\n\
  --advertise-client-urls http://127.0.0.1:2379 \\\n\
  --listen-peer-urls http://0.0.0.0:2380 \\\n\
  --initial-advertise-peer-urls http://127.0.0.1:2380 \\\n\
  --initial-cluster default=http://127.0.0.1:2380 \\\n\
  --log-level info \\\n\
  > /var/log/etcd/etcd.log 2>&1 &\n\
\n\
# Wait for etcd to be ready\n\
echo "Waiting for etcd to be ready..."\n\
for i in {1..30}; do\n\
  if etcdctl endpoint health > /dev/null 2>&1; then\n\
    echo "etcd is ready"\n\
    break\n\
  fi\n\
  echo "Waiting for etcd... ($i/30)"\n\
  sleep 1\n\
done\n\
\n\
# Initialize APISIX configuration if needed\n\
if [ ! -f /usr/local/apisix/conf/config.yaml ]; then\n\
  echo "Initializing APISIX configuration..."\n\
  apisix init || true\n\
fi\n\
\n\
# Start APISIX\n\
echo "Starting APISIX..."\n\
exec apisix start -c /usr/local/apisix/conf/config.yaml\n\
' > /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9080/apisix/status || exit 1

# Labels
LABEL maintainer="APISIX ARM Builder"
LABEL version="${VERSION}"
LABEL description="Apache APISIX ${VERSION} built for ARM64 architecture with etcd"

