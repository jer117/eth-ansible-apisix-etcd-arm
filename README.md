# Apache APISIX for ARM64

This repository contains a Docker image for Apache APISIX built specifically for ARM64 architecture (including Apple Silicon M1/M2/M3).

## Features

- ✅ Apache APISIX 3.14.0
- ✅ OpenResty with ARM64 support
- ✅ Embedded etcd v3.5.11
- ✅ Multi-stage build for smaller image size
- ✅ Health checks included
- ✅ Automatic initialization and startup

## Quick Start

### Build the Image

```bash
docker build -t apisix-arm:3.14.0 .
```

### Build with Custom Version

```bash
docker build --build-arg VERSION=3.14.0 -t apisix-arm:3.14.0 .
```

### Run the Container

```bash
docker run -d \
  --name apisix \
  -p 9080:9080 \
  -p 9443:9443 \
  -p 9180:9180 \
  -p 2379:2379 \
  apisix-arm:3.14.0
```

### Verify the Installation

Check APISIX status:
```bash
curl http://localhost:9080/apisix/status
```

Check etcd health:
```bash
docker exec apisix etcdctl endpoint health
```

## Exposed Ports

- `9080` - APISIX HTTP (default gateway)
- `9443` - APISIX HTTPS
- `9180` - APISIX Admin API
- `2379` - etcd client API
- `2380` - etcd peer communication

## Configuration

To use custom APISIX configuration, mount your `config.yaml`:

```bash
docker run -d \
  --name apisix \
  -v /path/to/config.yaml:/usr/local/apisix/conf/config.yaml \
  -p 9080:9080 \
  -p 9443:9443 \
  -p 9180:9180 \
  apisix-arm:3.14.0
```

## Persistent Data

To persist etcd data:

```bash
docker run -d \
  --name apisix \
  -v apisix-etcd-data:/var/lib/etcd \
  -p 9080:9080 \
  -p 9443:9443 \
  -p 9180:9180 \
  apisix-arm:3.14.0
```

## Architecture

This image is built using a multi-stage Dockerfile:

1. **Builder Stage**: Compiles and installs all dependencies, APISIX, and etcd
2. **Runtime Stage**: Creates a minimal runtime image with only necessary components

## Components

- **Base OS**: Ubuntu 22.04
- **APISIX Version**: 3.14.0 (configurable)
- **OpenResty**: Installed from official ARM64 repository
- **etcd**: v3.5.11 (ARM64 build)
- **LuaRocks**: Installed from official scripts

## Build Arguments

- `VERSION`: APISIX version to build (default: 3.14.0)
- `ETCD_VERSION`: etcd version to install (default: v3.5.11)

## GitHub Actions

This repository includes a CI/CD pipeline that automatically builds and pushes the Docker image when changes are pushed to the main branch.

## Manual Build Instructions

If you want to build APISIX manually on ARM without Docker, follow these steps:

1. Clone the APISIX repository:
   ```bash
   git clone https://github.com/apache/apisix.git
   cd apisix
   git checkout release/3.14.0
   ```

2. Install OpenResty for ARM64:
   ```bash
   sudo apt-get install -y wget gnupg ca-certificates
   wget -O - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
   echo "deb http://openresty.org/package/arm64/ubuntu $(lsb_release -sc) main" \
       | sudo tee /etc/apt/sources.list.d/openresty.list
   sudo apt-get update
   sudo apt-get install -y openresty
   ```

3. Install dependencies:
   ```bash
   bash utils/install-dependencies.sh
   curl https://raw.githubusercontent.com/apache/apisix/master/utils/linux-install-luarocks.sh -sL | bash -
   LUAROCKS_SERVER=https://luarocks.cn make deps
   ```

4. Build and install:
   ```bash
   make install
   ```

## Troubleshooting

### Container won't start
Check the logs:
```bash
docker logs apisix
```

### etcd connection issues
Verify etcd is running:
```bash
docker exec apisix etcdctl endpoint health
```

### Port conflicts
Make sure ports 9080, 9443, 9180, and 2379 are available on your host.

## License

This project follows the same license as Apache APISIX.

## Resources

- [Apache APISIX Official Documentation](https://apisix.apache.org/)
- [OpenResty Documentation](https://openresty.org/)
- [etcd Documentation](https://etcd.io/)
