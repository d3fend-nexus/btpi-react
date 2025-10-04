#!/bin/bash
# Test script for enhanced service detection system

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [TEST]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG]${NC} $1"
}

log_success() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $1"
}

# Source the enhanced functions from fresh-btpi-react.sh
source fresh-btpi-react.sh

echo "=== Enhanced Service Detection Test ==="
echo ""

# Test current running services
log_info "Testing detection of currently running services..."

# Check what containers are running
log_info "Currently running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Test each running service
RUNNING_SERVICES=$(docker ps --format "{{.Names}}")

for service in $RUNNING_SERVICES; do
    log_info "Testing enhanced detection for: $service"

    # Test container status check
    log_debug "Testing container status check..."
    if check_container_status "$service"; then
        log_success "$service container status check passed"
    else
        log_error "$service container status check failed"
        continue
    fi

    # Test service health check
    log_debug "Testing service health check..."
    if check_service_health "$service" 60; then
        log_success "$service health check passed"
    else
        log_error "$service health check failed"
        show_service_debug_info "$service"
        continue
    fi

    # Test overall wait_for_service function
    log_debug "Testing overall wait_for_service function..."
    if wait_for_service "$service" 60; then
        log_success "$service overall detection successful"
    else
        log_error "$service overall detection failed"
    fi

    echo ""
done

echo "=== Testing Complete ==="
