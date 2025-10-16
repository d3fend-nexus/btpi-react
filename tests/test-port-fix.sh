#!/bin/bash
# Test script to validate the port conflict fix

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [TEST-INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [TEST-ERROR]${NC} $1"
}

log_success() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [TEST-SUCCESS]${NC} $1"
}

log_info "Starting port conflict fix validation..."

# Test 1: Check service port separation
log_info "Test 1: Checking service port separation..."

# Check if elasticsearch is on port 9200
if lsof -Pi :9200 -sTCP:LISTEN -t >/dev/null 2>&1; then
    PROCESS=$(lsof -Pi :9200 -sTCP:LISTEN 2>/dev/null | tail -n 1 | awk '{print $1}' || echo "unknown")
    if [[ "$PROCESS" == *"docker"* ]]; then
        log_success "Elasticsearch correctly using port 9200 (via Docker)"
    else
        log_error "Port 9200 occupied by non-Docker process: $PROCESS"
        exit 1
    fi
else
    log_success "Port 9200 available (Elasticsearch not running yet)"
fi

# Check that port 9201 is available for wazuh-indexer (or already used by it)
if lsof -Pi :9201 -sTCP:LISTEN -t >/dev/null 2>&1; then
    PROCESS=$(lsof -Pi :9201 -sTCP:LISTEN 2>/dev/null | tail -n 1 | awk '{print $1}' || echo "unknown")
    if [[ "$PROCESS" == *"docker"* ]]; then
        log_success "Wazuh-indexer correctly using port 9201 (via Docker)"
    else
        log_error "Port 9201 occupied by non-Docker process: $PROCESS"
        exit 1
    fi
else
    log_success "Port 9201 available for Wazuh-indexer"
fi

# Test 2: Validate configuration files
log_info "Test 2: Validating configuration updates..."

# Check wazuh-indexer deploy script
if grep -q "9201:9200" services/wazuh-indexer/deploy.sh; then
    log_success "Wazuh-indexer port mapping correctly updated to 9201:9200"
else
    log_error "Wazuh-indexer port mapping not found or incorrect"
    exit 1
fi

# Check if external API calls use 9201
if grep -q "localhost:9201" services/wazuh-indexer/deploy.sh; then
    log_success "Wazuh-indexer external API calls correctly use port 9201"
else
    log_error "Wazuh-indexer external API calls not updated to port 9201"
    exit 1
fi

# Check fresh-btpi-react.sh port mappings
if grep -q '"wazuh-indexer"]="9201,9600"' fresh-btpi-react.sh; then
    log_success "Main deployment script port mapping updated correctly"
else
    log_error "Main deployment script port mapping not updated"
    exit 1
fi

# Check health check functions
if grep -q "localhost:9201/_cluster/health" fresh-btpi-react.sh; then
    log_success "Health check functions updated to use port 9201"
else
    log_error "Health check functions not updated to port 9201"
    exit 1
fi

# Test 3: Simulate service deployment (without actually deploying)
log_info "Test 3: Simulating service deployment order..."

# Check that elasticsearch and wazuh-indexer are both in database category
ELASTICSEARCH_CATEGORY=$(grep -A 20 "declare -A SERVICES=" fresh-btpi-react.sh | grep '\["elasticsearch"\]' | cut -d'"' -f4)
WAZUH_INDEXER_CATEGORY=$(grep -A 20 "declare -A SERVICES=" fresh-btpi-react.sh | grep '\["wazuh-indexer"\]' | cut -d'"' -f4)

if [[ "$ELASTICSEARCH_CATEGORY" == "database" && "$WAZUH_INDEXER_CATEGORY" == "database" ]]; then
    log_success "Both Elasticsearch and Wazuh-indexer are correctly categorized as database services"
else
    log_error "Service categorization issue: elasticsearch=$ELASTICSEARCH_CATEGORY, wazuh-indexer=$WAZUH_INDEXER_CATEGORY"
    exit 1
fi

# Test 4: Validate dependency chain
log_info "Test 4: Validating service dependencies..."

# Check that wazuh-manager depends on wazuh-indexer
if grep -q '"wazuh-manager"]="wazuh-indexer"' fresh-btpi-react.sh; then
    log_success "Wazuh-manager correctly depends on wazuh-indexer"
else
    log_error "Wazuh-manager dependency on wazuh-indexer not found"
    exit 1
fi

# Test 5: Check internal vs external port usage
log_info "Test 5: Validating internal vs external port usage..."

# Wazuh-manager should still use internal Docker network communication
if grep -q "wazuh-indexer:9200" services/wazuh-manager/deploy.sh; then
    log_success "Wazuh-manager correctly uses internal Docker network port 9200"
else
    log_error "Wazuh-manager internal communication may be broken"
    exit 1
fi

# Test 6: Validate management script port references
log_info "Test 6: Checking management script port references..."

# Check if management scripts use correct external port
if grep -q "localhost:9201" services/wazuh-indexer/deploy.sh; then
    # Count occurrences to ensure consistency
    EXTERNAL_REFS=$(grep -c "localhost:9201" services/wazuh-indexer/deploy.sh)
    if [ $EXTERNAL_REFS -ge 3 ]; then
        log_success "Management scripts consistently use external port 9201 ($EXTERNAL_REFS references found)"
    else
        log_error "Inconsistent external port references in management scripts"
        exit 1
    fi
fi

# Summary
log_info "Port conflict fix validation completed successfully!"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    PORT CONFLICT FIX VALIDATION        ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✅ All tests passed successfully!${NC}"
echo ""
echo -e "${GREEN}Summary of changes:${NC}"
echo -e "  • Elasticsearch: Port 9200 (unchanged)"
echo -e "  • Wazuh-indexer: External port 9201, Internal port 9200"
echo -e "  • Port mappings updated in deployment scripts"
echo -e "  • Health checks updated to use correct ports"
echo -e "  • Service dependencies maintained correctly"
echo -e "  • Internal Docker network communication preserved"
echo ""
echo -e "${YELLOW}Ready for deployment!${NC}"
echo -e "  Run: ${BLUE}sudo bash fresh-btpi-react.sh${NC}"
echo ""
