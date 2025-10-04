#!/bin/bash
# Wazuh Indexer Deployment Script - Wazuh Network

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
source "$PROJECT_ROOT/config/.env"

echo "🔍 Deploying Wazuh Indexer on Wazuh Network..."

# Create data directory
mkdir -p "$PROJECT_ROOT/data/wazuh-indexer"
chmod 777 "$PROJECT_ROOT/data/wazuh-indexer"

# Check if Wazuh Indexer container already exists and is healthy
if docker ps --format "{{.Names}}" | grep -q "^wazuh-indexer$"; then
    echo "📋 Wazuh Indexer container already exists, checking health..."

    # Check if it's responding properly
    if nc -z localhost 9400 2>/dev/null && \
       curl -s --max-time 10 "http://localhost:9400/_cluster/health" >/dev/null 2>&1; then
        echo "✅ Wazuh Indexer is already healthy and responding"
        echo "🔗 Available at: http://localhost:9400"
        exit 0
    else
        echo "⚠️ Wazuh Indexer container exists but is not healthy, restarting..."
        docker restart wazuh-indexer
        sleep 30

        # Check again after restart
        if curl -s --max-time 10 "http://localhost:9400/_cluster/health" >/dev/null 2>&1; then
            echo "✅ Wazuh Indexer restarted successfully"
            exit 0
        else
            echo "❌ Wazuh Indexer restart failed, will redeploy"
            docker stop wazuh-indexer 2>/dev/null || true
            docker rm wazuh-indexer 2>/dev/null || true
        fi
    fi
elif docker ps -a --format "{{.Names}}" | grep -q "^wazuh-indexer$"; then
    echo "🔄 Wazuh Indexer container exists but is not running, starting..."
    docker start wazuh-indexer
    sleep 30

    # Check if it's working after start
    if curl -s --max-time 10 "http://localhost:9400/_cluster/health" >/dev/null 2>&1; then
        echo "✅ Wazuh Indexer started successfully"
        exit 0
    else
        echo "❌ Wazuh Indexer failed to start properly, will redeploy"
        docker stop wazuh-indexer 2>/dev/null || true
        docker rm wazuh-indexer 2>/dev/null || true
    fi
else
    echo "📦 No existing Wazuh Indexer container found, deploying new instance..."
fi

# Create custom opensearch.yml with proper security configuration
mkdir -p "$PROJECT_ROOT/services/wazuh-indexer/config"
cat > "$PROJECT_ROOT/services/wazuh-indexer/config/opensearch.yml" <<EOF
cluster.name: wazuh-cluster
node.name: wazuh-indexer-1
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node
bootstrap.memory_lock: true

# Security configuration
plugins.security.ssl.transport.enabled: false
plugins.security.ssl.http.enabled: false
plugins.security.disabled: true
plugins.security.allow_unsafe_democertificates: true
plugins.security.allow_default_init_securityindex: true
plugins.security.audit.type: noop
plugins.security.enable_snapshot_restore_privilege: true
plugins.security.check_snapshot_restore_write_privileges: true
plugins.security.system_indices.enabled: false

# Performance settings
indices.memory.index_buffer_size: 10%
thread_pool.write.queue_size: 10000
thread_pool.search.queue_size: 10000
EOF

# Deploy Wazuh Indexer with custom config
docker run -d \
    --name wazuh-indexer \
    --restart unless-stopped \
    --network btpi-wazuh-network \
    -p 9400:9200 \
    -e "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m -Dopensearch.security.disabled=true" \
    -e "DISABLE_SECURITY_PLUGIN=true" \
    -e "DISABLE_INSTALL_DEMO_CONFIG=true" \
    -v "$PROJECT_ROOT/data/wazuh-indexer:/usr/share/wazuh-indexer/data" \
    -v "$PROJECT_ROOT/services/wazuh-indexer/config/opensearch.yml:/usr/share/wazuh-indexer/config/opensearch.yml:ro" \
    --ulimit memlock=-1:-1 \
    wazuh/wazuh-indexer:4.9.0

echo "✅ Wazuh Indexer deployed successfully on btpi-wazuh-network"
echo "🔗 Available at: http://localhost:9400"
