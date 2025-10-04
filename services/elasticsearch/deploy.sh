#!/bin/bash
# Elasticsearch Deployment Script - Core Network

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment and common utilities
source "$PROJECT_ROOT/config/.env"
source "$PROJECT_ROOT/scripts/common-utils.sh"

echo "🔍 Deploying Elasticsearch on Core Network..."

# Check if container already exists
if docker ps -a --format "{{.Names}}" | grep -q "^elasticsearch$"; then
    echo "📋 Elasticsearch container already exists, checking status..."

    # Check if it's running and healthy
    if docker ps --format "{{.Names}}" | grep -q "^elasticsearch$"; then
        echo "✅ Elasticsearch is already running"

        # Test if it's responding properly using authenticated health check
        if check_elasticsearch_health; then
            echo "✅ Elasticsearch is healthy and responding"
            echo "🔗 Available at: http://localhost:9200"
            echo "🔐 Username: elastic"
            echo "🔐 Password: ${ELASTIC_PASSWORD}"
            exit 0
        else
            echo "⚠️ Elasticsearch is running but not responding properly, restarting..."
            docker restart elasticsearch

            # Wait for restart and test again
            echo "🔄 Waiting for Elasticsearch to restart..."
            sleep 15
            if check_elasticsearch_health; then
                echo "✅ Elasticsearch restarted successfully"
                exit 0
            else
                echo "❌ Elasticsearch restart failed, continuing with new deployment..."
                docker rm -f elasticsearch 2>/dev/null || true
            fi
        fi
    else
        echo "🔄 Elasticsearch container exists but is not running, starting..."
        docker start elasticsearch
        sleep 5
        exit 0
    fi
else
    echo "📦 No existing Elasticsearch container found, deploying new instance..."
fi

# Create data directory
mkdir -p "$PROJECT_ROOT/data/elasticsearch"
chmod 777 "$PROJECT_ROOT/data/elasticsearch"

# Deploy Elasticsearch
docker run -d \
    --name elasticsearch \
    --restart unless-stopped \
    --network btpi-core-network \
    -p 9200:9200 \
    -p 9300:9300 \
    -e "discovery.type=single-node" \
    -e "bootstrap.memory_lock=true" \
    -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
    -e "ELASTIC_PASSWORD=${ELASTIC_PASSWORD}" \
    -e "xpack.security.enabled=true" \
    -v "$PROJECT_ROOT/data/elasticsearch:/usr/share/elasticsearch/data" \
    -v "$PROJECT_ROOT/services/elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro" \
    --ulimit memlock=-1:-1 \
    docker.elastic.co/elasticsearch/elasticsearch:8.15.3

echo "✅ Elasticsearch deployed successfully on btpi-core-network"
echo "🔗 Available at: http://localhost:9200"
echo "🔐 Username: elastic"
echo "🔐 Password: ${ELASTIC_PASSWORD}"
