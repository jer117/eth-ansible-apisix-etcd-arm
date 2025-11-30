#!/bin/bash

# APISIX ARM64 Test Script
# This script tests the basic functionality of APISIX

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APISIX_HOST="${APISIX_HOST:-127.0.0.1}"
APISIX_PORT="${APISIX_PORT:-9080}"
ADMIN_PORT="${ADMIN_PORT:-9180}"
ADMIN_KEY="${ADMIN_KEY:-test}"

echo "================================================"
echo "  APISIX ARM64 Installation Test Suite"
echo "================================================"
echo ""

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC}: $2"
    else
        echo -e "${RED}✗ FAILED${NC}: $2"
        exit 1
    fi
}

# Function to print info
print_info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# Test 1: Check if APISIX is responding
print_info "Test 1: Checking APISIX status endpoint..."
if curl -s -f "http://${APISIX_HOST}:${APISIX_PORT}/apisix/status" > /dev/null; then
    print_result 0 "APISIX status endpoint is responding"
else
    print_result 1 "APISIX status endpoint is not responding"
fi

# Test 2: Check Admin API
print_info "Test 2: Checking APISIX Admin API..."
ADMIN_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://${APISIX_HOST}:${ADMIN_PORT}/apisix/admin/routes" -H "X-API-KEY: ${ADMIN_KEY}")
if [ "$ADMIN_RESPONSE" -eq 200 ]; then
    print_result 0 "Admin API is accessible"
else
    print_result 1 "Admin API returned status code: $ADMIN_RESPONSE"
fi

# Test 3: Create a test route
print_info "Test 3: Creating a test route..."
CREATE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://${APISIX_HOST}:${ADMIN_PORT}/apisix/admin/routes/test-route-1" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -X PUT -d '
{
  "uri": "/get",
  "methods": ["GET"],
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}')

if [ "$CREATE_RESPONSE" -eq 200 ] || [ "$CREATE_RESPONSE" -eq 201 ]; then
    print_result 0 "Test route created successfully"
else
    print_result 1 "Failed to create test route (HTTP $CREATE_RESPONSE)"
fi

# Test 4: Test the created route
print_info "Test 4: Testing the created route..."
sleep 2  # Give APISIX time to sync the route
ROUTE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://${APISIX_HOST}:${APISIX_PORT}/get")
if [ "$ROUTE_RESPONSE" -eq 200 ]; then
    print_result 0 "Route is working correctly"
else
    print_result 1 "Route returned status code: $ROUTE_RESPONSE"
fi

# Test 5: List routes
print_info "Test 5: Listing all routes..."
LIST_RESPONSE=$(curl -s "http://${APISIX_HOST}:${ADMIN_PORT}/apisix/admin/routes" -H "X-API-KEY: ${ADMIN_KEY}")
if echo "$LIST_RESPONSE" | grep -q "test-route-1"; then
    print_result 0 "Route listing works and contains test route"
else
    print_result 1 "Route listing failed or doesn't contain test route"
fi

# Test 6: Update route with a plugin
print_info "Test 6: Testing plugin functionality (adding response-rewrite)..."
UPDATE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://${APISIX_HOST}:${ADMIN_PORT}/apisix/admin/routes/test-route-1" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -X PUT -d '
{
  "uri": "/get",
  "methods": ["GET"],
  "plugins": {
    "response-rewrite": {
      "headers": {
        "X-APISIX-Test": "ARM64-Build"
      }
    }
  },
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "httpbin.org:80": 1
    }
  }
}')

if [ "$UPDATE_RESPONSE" -eq 200 ] || [ "$UPDATE_RESPONSE" -eq 201 ]; then
    print_result 0 "Route updated with plugin successfully"
else
    print_result 1 "Failed to update route with plugin (HTTP $UPDATE_RESPONSE)"
fi

# Test 7: Verify plugin is working
print_info "Test 7: Verifying plugin functionality..."
sleep 2  # Give APISIX time to sync
PLUGIN_HEADER=$(curl -s -I "http://${APISIX_HOST}:${APISIX_PORT}/get" | grep -i "X-APISIX-Test" | tr -d '\r')
if echo "$PLUGIN_HEADER" | grep -q "ARM64-Build"; then
    print_result 0 "Plugin is working correctly"
else
    print_result 1 "Plugin header not found in response"
fi

# Test 8: Delete the test route
print_info "Test 8: Cleaning up - deleting test route..."
DELETE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://${APISIX_HOST}:${ADMIN_PORT}/apisix/admin/routes/test-route-1" \
  -H "X-API-KEY: ${ADMIN_KEY}" \
  -X DELETE)

if [ "$DELETE_RESPONSE" -eq 200 ]; then
    print_result 0 "Test route deleted successfully"
else
    print_result 1 "Failed to delete test route (HTTP $DELETE_RESPONSE)"
fi

# Test 9: Check etcd health (if running in Docker)
print_info "Test 9: Checking etcd health..."
if command -v docker &> /dev/null; then
    if docker ps | grep -q apisix; then
        if docker exec apisix etcdctl endpoint health &> /dev/null; then
            print_result 0 "etcd is healthy"
        else
            print_result 1 "etcd health check failed"
        fi
    else
        print_info "Skipping etcd test (container not found)"
    fi
else
    print_info "Skipping etcd test (Docker not available)"
fi

echo ""
echo "================================================"
echo -e "${GREEN}  All tests passed successfully! ✓${NC}"
echo "================================================"
echo ""
echo "Your APISIX ARM64 installation is working correctly."
echo ""

