#!/bin/bash
# Quick test script for Elasticsearch health check

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment
source "$PROJECT_ROOT/config/.env"
source "$PROJECT_ROOT/scripts/common-utils.sh"

echo "Testing Elasticsearch health check..."
echo "=====================================  "

echo "1. Testing port connectivity..."
if nc -z localhost 9200 2>/dev/null; then
    echo "✅ Port 9200 is accessible"
else
    echo "❌ Port 9200 is not accessible"
    exit 1
fi

echo ""
echo "2. Testing Elasticsearch API with authentication..."
if check_service_health elasticsearch; then
    echo "✅ Elasticsearch health check PASSED"
    exit 0
else
    echo "❌ Elasticsearch health check FAILED"

    echo ""
    echo "3. Debugging Elasticsearch response..."
    echo "Without auth:"
    curl -s --max-time 5 "http://localhost:9200/_cluster/health" || echo "Failed"

    echo ""
    echo "With auth:"
    curl -s --max-time 5 -u "elastic:$ELASTIC_PASSWORD" "http://localhost:9200/_cluster/health" || echo "Failed"

    exit 1
fi
