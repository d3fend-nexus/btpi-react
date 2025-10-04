#!/bin/bash
# Test script to verify Elasticsearch health check with dynamic password

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/config"

# Source common utilities to get the health check function
source "${SCRIPT_DIR}/common-utils.sh"

echo "🔍 Testing Elasticsearch Health Check with Dynamic Password..."
echo "============================================================="

# Load environment
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
    echo "✅ Environment loaded"
    echo "📋 Using password: ${ELASTIC_PASSWORD:0:8}***"
else
    echo "❌ Environment file not found"
    exit 1
fi

# Test the enhanced health check function
echo ""
echo "🧪 Running enhanced health check function..."
if check_elasticsearch_health; then
    echo "✅ Enhanced Elasticsearch health check: PASSED"
else
    echo "❌ Enhanced Elasticsearch health check: FAILED"
    exit 1
fi

echo ""
echo "🎉 All tests passed! The health check fix is working correctly."
echo "🚀 The deployment script should now proceed past the Elasticsearch health check."
