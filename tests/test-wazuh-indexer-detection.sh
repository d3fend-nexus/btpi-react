#!/bin/bash
# Quick test to validate wazuh-indexer detection with enhanced system

set -euo pipefail

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Quick Wazuh-Indexer Detection Test ===${NC}"

# Source the enhanced functions from fresh-btpi-react.sh
source fresh-btpi-react.sh

echo ""
echo "Current container status:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep wazuh-indexer

echo ""
echo "Testing enhanced detection specifically for wazuh-indexer..."

# Test the enhanced wait_for_service function with shorter timeout
if wait_for_service "wazuh-indexer" 30; then
    echo -e "${GREEN}✅ SUCCESS: Enhanced detection system correctly identified wazuh-indexer as ready!${NC}"
    exit 0
else
    echo -e "${RED}❌ FAILED: Enhanced detection system could not detect wazuh-indexer${NC}"
    exit 1
fi
