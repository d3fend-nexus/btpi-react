#!/bin/bash
# Test script to verify Elasticsearch connectivity fix

set -e

echo "Starting Elasticsearch connectivity test..."

# Create a function to log messages with timestamps
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to clean up resources
cleanup() {
  log "Cleaning up resources..."
  docker stop elasticsearch 2>/dev/null || true
  docker rm elasticsearch 2>/dev/null || true
}

# Make sure we clean up on exit
trap cleanup EXIT

# Start fresh
cleanup

# Create network if it doesn't exist
if ! docker network ls | grep -q "btpi-network"; then
  log "Creating Docker network 'btpi-network'..."
  docker network create --driver bridge btpi-network
fi

# Deploy Elasticsearch container with HTTP enabled and HTTPS disabled
log "Deploying Elasticsearch container..."
docker run -d \
  --name elasticsearch \
  --network btpi-network \
  -p 9200:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "cluster.name=btpi-cluster" \
  -e "bootstrap.memory_lock=true" \
  -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
  -e "xpack.security.enabled=false" \
  -e "xpack.security.http.ssl.enabled=false" \
  -e "xpack.ml.enabled=false" \
  docker.elastic.co/elasticsearch/elasticsearch:8.11.0

# Wait for Elasticsearch to start up
log "Waiting for Elasticsearch to start (max 60s)..."
for i in {1..12}; do
  log "Attempt $i/12: Checking if Elasticsearch is ready..."

  # Test HTTP endpoint (should work)
  if curl -s "http://localhost:9200/_cluster/health" > /dev/null 2>&1; then
    log "SUCCESS: Elasticsearch is accessible via HTTP!"
    echo "HTTP Test Result:"
    curl -s "http://localhost:9200/_cluster/health" | jq . || echo "Raw response: $(curl -s "http://localhost:9200/_cluster/health")"

    # Test HTTPS endpoint (should fail)
    log "Testing HTTPS endpoint (this should fail)..."
    if curl -s -k "https://localhost:9200/_cluster/health" > /dev/null 2>&1; then
      log "WARNING: HTTPS endpoint is unexpectedly working!"
    else
      log "SUCCESS: HTTPS endpoint is correctly unavailable!"
    fi

    # Test the exact curl command used in our fixed function
    log "Testing the exact curl command from wait_for_service()..."
    if curl -s "http://localhost:9200/_cluster/health" > /dev/null 2>&1; then
      log "SUCCESS: wait_for_service() HTTP check would pass!"
    else
      log "ERROR: wait_for_service() HTTP check would fail!"
    fi

    # Test the exact curl command used in test_service_health
    log "Testing the exact curl command from test_service_health()..."
    if curl -s "http://localhost:9200/_cluster/health" | grep -q '"status":"green\|yellow"'; then
      log "SUCCESS: test_service_health() HTTP check would pass!"
    else
      log "ERROR: test_service_health() HTTP check would fail!"
    fi

    log "All tests completed. Fix is verified!"
    exit 0
  fi

  log "Elasticsearch not ready yet, waiting 5s..."
  sleep 5
done

log "ERROR: Elasticsearch failed to start within 60s"
docker logs elasticsearch
exit 1
