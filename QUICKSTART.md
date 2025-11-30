# Quick Start Guide - Apache APISIX on ARM64

This guide will help you get started with Apache APISIX running on ARM64 architecture in just a few minutes.

## Prerequisites

- Docker installed on ARM64 system (Apple Silicon, AWS Graviton, etc.)
- `make` installed (optional, for convenience)
- `curl` installed (for testing)

## Option 1: Using Make (Recommended)

### 1. Build the Image

```bash
make build
```

### 2. Start APISIX

```bash
make run
```

### 3. Verify Installation

```bash
make health
```

You should see output indicating APISIX and etcd are healthy.

### 4. View Logs

```bash
make logs
```

Press `Ctrl+C` to exit log viewing.

## Option 2: Using Docker Compose

### 1. Start Services

```bash
docker-compose up -d
```

### 2. Check Status

```bash
docker-compose ps
```

### 3. View Logs

```bash
docker-compose logs -f
```

## Option 3: Using Docker Commands Directly

### 1. Build the Image

```bash
docker build -t apisix-arm:3.14.0 .
```

### 2. Run the Container

```bash
docker run -d \
  --name apisix \
  -p 9080:9080 \
  -p 9443:9443 \
  -p 9180:9180 \
  -p 2379:2379 \
  apisix-arm:3.14.0
```

### 3. Check Status

```bash
curl http://localhost:9080/apisix/status
```

## Testing Your Installation

### 1. Check APISIX Status

```bash
curl http://localhost:9080/apisix/status
```

Expected response:
```json
{"status":"ok"}
```

### 2. Create a Test Route

```bash
curl "http://127.0.0.1:9180/apisix/admin/routes/1" \
  -H "X-API-KEY: test" \
  -X PUT -d '
{
  "methods": ["GET"],
  "uri": "/hello",
  "plugins": {},
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}'
```

### 3. Test the Route

```bash
curl http://127.0.0.1:9080/hello
```

You should receive a response from httpbin.org.

### 4. List All Routes

```bash
curl "http://127.0.0.1:9180/apisix/admin/routes" \
  -H "X-API-KEY: test"
```

### 5. Delete the Test Route

```bash
curl "http://127.0.0.1:9180/apisix/admin/routes/1" \
  -H "X-API-KEY: test" \
  -X DELETE
```

## Using with Custom Configuration

### 1. Copy the Example Config

```bash
cp config.yaml.example config.yaml
```

### 2. Edit the Configuration

```bash
nano config.yaml  # or use your favorite editor
```

### 3. Run with Custom Config

Using Docker:
```bash
docker run -d \
  --name apisix \
  -v $(pwd)/config.yaml:/usr/local/apisix/conf/config.yaml \
  -p 9080:9080 \
  -p 9443:9443 \
  -p 9180:9180 \
  apisix-arm:3.14.0
```

Or update `docker-compose.yml` and uncomment the config volume mount.

## Common Use Cases

### Reverse Proxy Example

```bash
# Create a route that proxies to your backend service
curl "http://127.0.0.1:9180/apisix/admin/routes/100" \
  -H "X-API-KEY: test" \
  -X PUT -d '
{
  "uri": "/api/*",
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "backend.example.com:8080": 1
    }
  }
}'
```

### Load Balancer Example

```bash
# Create a route with multiple upstream nodes
curl "http://127.0.0.1:9180/apisix/admin/routes/200" \
  -H "X-API-KEY: test" \
  -X PUT -d '
{
  "uri": "/service/*",
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "backend1.example.com:8080": 1,
      "backend2.example.com:8080": 1,
      "backend3.example.com:8080": 1
    }
  }
}'
```

### Rate Limiting Example

```bash
# Add rate limiting to a route
curl "http://127.0.0.1:9180/apisix/admin/routes/300" \
  -H "X-API-KEY: test" \
  -X PUT -d '
{
  "uri": "/limited/*",
  "plugins": {
    "limit-req": {
      "rate": 10,
      "burst": 5,
      "key": "remote_addr",
      "rejected_code": 429
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "backend.example.com:8080": 1
    }
  }
}'
```

### CORS Example

```bash
# Enable CORS on a route
curl "http://127.0.0.1:9180/apisix/admin/routes/400" \
  -H "X-API-KEY: test" \
  -X PUT -d '
{
  "uri": "/cors-enabled/*",
  "plugins": {
    "cors": {
      "allow_origins": "*",
      "allow_methods": "GET,POST,PUT,DELETE,OPTIONS",
      "allow_headers": "Content-Type,Authorization",
      "expose_headers": "X-Custom-Header",
      "max_age": 3600
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "backend.example.com:8080": 1
    }
  }
}'
```

## Troubleshooting

### Container Won't Start

1. Check the logs:
   ```bash
   make logs
   # or
   docker logs apisix
   ```

2. Verify ports are available:
   ```bash
   lsof -i :9080
   lsof -i :9180
   lsof -i :2379
   ```

### etcd Connection Issues

1. Check etcd health:
   ```bash
   docker exec apisix etcdctl endpoint health
   ```

2. View etcd logs:
   ```bash
   docker exec apisix cat /var/log/etcd/etcd.log
   ```

### Admin API Not Responding

1. Verify the admin API port:
   ```bash
   curl http://localhost:9180/apisix/admin/routes -H 'X-API-KEY: test'
   ```

2. Check if you're using the correct API key (default: `test`)

### Health Check Failing

1. Wait a bit longer - APISIX can take 30-60 seconds to fully start
2. Check if all required ports are accessible
3. Verify etcd is running and healthy

## Next Steps

- Read the full [Apache APISIX Documentation](https://apisix.apache.org/docs/apisix/getting-started/)
- Explore [APISIX Plugins](https://apisix.apache.org/docs/apisix/plugins/batch-requests/)
- Learn about [APISIX Admin API](https://apisix.apache.org/docs/apisix/admin-api/)
- Set up [monitoring with Prometheus](https://apisix.apache.org/docs/apisix/plugins/prometheus/)

## Stopping and Cleanup

### Stop the Container

```bash
make stop
# or
docker-compose down
# or
docker stop apisix && docker rm apisix
```

### Remove Images and Volumes

```bash
make clean-all
```

## Support

For issues specific to this ARM64 build, please open an issue in this repository.

For general APISIX questions, refer to the [official Apache APISIX documentation](https://apisix.apache.org/).

