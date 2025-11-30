#!/bin/bash

# APISIX ARM64 Example Routes and Configurations
# This script creates various example routes to demonstrate APISIX capabilities

set -e

# Configuration
APISIX_HOST="${APISIX_HOST:-127.0.0.1}"
ADMIN_PORT="${ADMIN_PORT:-9180}"
ADMIN_KEY="${ADMIN_KEY:-test}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================"
echo "  APISIX ARM64 Example Configurations"
echo "================================================"
echo ""

# Function to create route
create_route() {
    local route_id=$1
    local description=$2
    local json_data=$3
    
    echo -e "${BLUE}Creating:${NC} $description"
    
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://${APISIX_HOST}:${ADMIN_PORT}/apisix/admin/routes/${route_id}" \
        -H "X-API-KEY: ${ADMIN_KEY}" \
        -X PUT -d "$json_data")
    
    if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
        echo -e "${GREEN}✓ Created:${NC} Route ID ${route_id}"
        echo ""
    else
        echo -e "${YELLOW}✗ Failed:${NC} HTTP $response"
        echo ""
    fi
}

# Example 1: Simple Reverse Proxy
create_route "example-1" "Simple Reverse Proxy to httpbin.org" '
{
  "name": "Simple Reverse Proxy",
  "uri": "/httpbin/*",
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}'

# Example 2: Load Balancer with Multiple Upstream Nodes
create_route "example-2" "Load Balancer with Multiple Backends" '
{
  "name": "Load Balancer Example",
  "uri": "/loadbalanced/*",
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1,
      "postman-echo.com:80": 1
    }
  }
}'

# Example 3: Rate Limiting
create_route "example-3" "Rate Limiting (10 req/min)" '
{
  "name": "Rate Limited Route",
  "uri": "/ratelimited/*",
  "plugins": {
    "limit-req": {
      "rate": 10,
      "burst": 5,
      "key": "remote_addr",
      "rejected_code": 429,
      "rejected_msg": "Too many requests"
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}'

# Example 4: CORS Enabled Route
create_route "example-4" "CORS Enabled Route" '
{
  "name": "CORS Example",
  "uri": "/cors/*",
  "plugins": {
    "cors": {
      "allow_origins": "**",
      "allow_methods": "GET,POST,PUT,DELETE,OPTIONS",
      "allow_headers": "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization",
      "expose_headers": "Content-Length,Content-Range",
      "max_age": 3600,
      "allow_credential": true
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}'

# Example 5: Request/Response Rewrite
create_route "example-5" "Request/Response Rewrite" '
{
  "name": "Rewrite Example",
  "uri": "/api/v1/*",
  "plugins": {
    "proxy-rewrite": {
      "regex_uri": ["^/api/v1/(.*)", "/$1"]
    },
    "response-rewrite": {
      "headers": {
        "X-Server-ID": "APISIX-ARM64",
        "X-Server-Status": "Active"
      }
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}'

# Example 6: IP Restriction
create_route "example-6" "IP Restriction (Whitelist)" '
{
  "name": "IP Restriction Example",
  "uri": "/restricted/*",
  "plugins": {
    "ip-restriction": {
      "whitelist": ["127.0.0.1", "::1"]
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}'

# Example 7: Request Validation
create_route "example-7" "Request Validation (Schema)" '
{
  "name": "Validation Example",
  "uri": "/validated/*",
  "methods": ["POST"],
  "plugins": {
    "request-validation": {
      "body_schema": {
        "type": "object",
        "required": ["name", "email"],
        "properties": {
          "name": {"type": "string", "minLength": 1},
          "email": {"type": "string", "format": "email"},
          "age": {"type": "integer", "minimum": 0, "maximum": 150}
        }
      }
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}'

# Example 8: Traffic Split (Canary Deployment)
create_route "example-8" "Traffic Split (90/10)" '
{
  "name": "Traffic Split Example",
  "uri": "/canary/*",
  "plugins": {
    "traffic-split": {
      "rules": [
        {
          "weighted_upstreams": [
            {
              "upstream": {
                "name": "production",
                "type": "roundrobin",
                "nodes": {
                  "httpbin.org:80": 1
                }
              },
              "weight": 90
            },
            {
              "upstream": {
                "name": "canary",
                "type": "roundrobin",
                "nodes": {
                  "postman-echo.com:80": 1
                }
              },
              "weight": 10
            }
          ]
        }
      ]
    }
  }
}'

# Example 9: Proxy Cache
create_route "example-9" "Proxy Cache (5 min TTL)" '
{
  "name": "Cache Example",
  "uri": "/cached/*",
  "plugins": {
    "proxy-cache": {
      "cache_zone": "disk_cache_one",
      "cache_key": ["$host", "$request_uri"],
      "cache_bypass": ["$arg_bypass"],
      "cache_method": ["GET"],
      "cache_http_status": [200],
      "hide_cache_headers": false,
      "no_cache": ["$arg_no_cache"]
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}'

# Example 10: Redirect
create_route "example-10" "HTTP Redirect (301)" '
{
  "name": "Redirect Example",
  "uri": "/old-path",
  "plugins": {
    "redirect": {
      "uri": "/new-path",
      "ret_code": 301
    }
  }
}'

echo "================================================"
echo -e "${GREEN}  All example routes created!${NC}"
echo "================================================"
echo ""
echo "You can now test the following routes:"
echo ""
echo "1. Simple Reverse Proxy:"
echo "   curl http://${APISIX_HOST}:9080/httpbin/get"
echo ""
echo "2. Load Balancer:"
echo "   curl http://${APISIX_HOST}:9080/loadbalanced/get"
echo ""
echo "3. Rate Limiting:"
echo "   for i in {1..15}; do curl http://${APISIX_HOST}:9080/ratelimited/get; done"
echo ""
echo "4. CORS:"
echo "   curl -H 'Origin: http://example.com' http://${APISIX_HOST}:9080/cors/get"
echo ""
echo "5. Request/Response Rewrite:"
echo "   curl -I http://${APISIX_HOST}:9080/api/v1/get"
echo ""
echo "6. IP Restriction (should work from localhost):"
echo "   curl http://${APISIX_HOST}:9080/restricted/get"
echo ""
echo "7. Request Validation (try valid and invalid JSON):"
echo "   curl -X POST http://${APISIX_HOST}:9080/validated/post \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"name\":\"John\",\"email\":\"john@example.com\"}'"
echo ""
echo "8. Traffic Split:"
echo "   for i in {1..10}; do curl http://${APISIX_HOST}:9080/canary/get; done"
echo ""
echo "9. Proxy Cache:"
echo "   curl -I http://${APISIX_HOST}:9080/cached/get"
echo ""
echo "10. Redirect:"
echo "    curl -I http://${APISIX_HOST}:9080/old-path"
echo ""
echo "To delete all examples:"
echo "  for i in {1..10}; do curl -X DELETE \\"
echo "    \"http://${APISIX_HOST}:${ADMIN_PORT}/apisix/admin/routes/example-\$i\" \\"
echo "    -H \"X-API-KEY: ${ADMIN_KEY}\"; done"
echo ""

