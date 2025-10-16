#!/bin/bash
# BTPI-REACT ARM64 Deployment Test Script
# Purpose: Test individual service deployments on ARM64 with practical success criteria
# Focus: Successful deployment and functionality over strict architectural purity

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results storage
declare -A TEST_RESULTS=()
declare -A DEPLOYMENT_METHODS=()
declare -A ARCHITECTURE_INFO=()
declare -A PERFORMANCE_NOTES=()

# Test configuration
TIMEOUT_SHORT=30
TIMEOUT_MEDIUM=60
TIMEOUT_LONG=120
REPORT_FILE="$PROJECT_ROOT/logs/arm64-deployment-report-$(date +%Y%m%d-%H%M%S).txt"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$REPORT_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$REPORT_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$REPORT_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$REPORT_FILE"
}

log_test() {
    echo -e "${PURPLE}[TEST]${NC} $1" | tee -a "$REPORT_FILE"
}

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1" | tee -a "$REPORT_FILE"
}

# Initialize test environment
initialize_testing() {
    log_info "Initializing ARM64 deployment testing environment..."
    
    # Create logs directory
    mkdir -p "$PROJECT_ROOT/logs"
    
    # Initialize report file
    cat > "$REPORT_FILE" <<EOF
# BTPI-REACT ARM64 Deployment Test Report
# Generated: $(date)
# Host: $(hostname)
# Architecture: $(uname -m)
# OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")

================================
EOF

    # Source platform detection
    if [ -f "$PROJECT_ROOT/scripts/core/detect-platform.sh" ]; then
        source "$PROJECT_ROOT/scripts/core/detect-platform.sh" --source
        detect_architecture || log_warn "Platform detection failed - continuing with manual detection"
    else
        log_warn "Platform detection script not found - using manual detection"
        export BTPI_ARCH="$(uname -m)"
        export BTPI_PLATFORM="$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')"
    fi
    
    log_info "Detected platform: $BTPI_PLATFORM ($BTPI_ARCH)"
    
    # Load environment if available
    if [ -f "$PROJECT_ROOT/config/.env" ]; then
        source "$PROJECT_ROOT/config/.env"
        log_info "Loaded environment configuration"
    else
        log_warn "No environment file found - some tests may fail"
    fi
}

# Test Docker availability and multi-arch support
test_docker_environment() {
    log_test "Testing Docker environment for ARM64 support..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found - cannot test containerized services"
        return 1
    fi
    
    # Test basic Docker functionality
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not accessible - check permissions"
        return 1
    fi
    
    log_success "Docker daemon is accessible"
    
    # Check buildx support
    if docker buildx version >/dev/null 2>&1; then
        log_success "Docker buildx available for multi-arch support"
        local platforms=$(docker buildx ls 2>/dev/null | grep -o "linux/[a-z0-9/]*" | sort -u | tr '\n' ',' | sed 's/,$//')
        log_info "Available platforms: $platforms"
    else
        log_warn "Docker buildx not available - limited multi-arch support"
    fi
    
    # Test QEMU emulation if not native ARM64
    if [ "$BTPI_ARCH" != "aarch64" ] && [ "$BTPI_ARCH" != "arm64" ]; then
        log_info "Testing x86_64 system with potential emulation support"
        if docker run --rm --platform=linux/arm64 hello-world >/dev/null 2>&1; then
            log_success "ARM64 emulation available via QEMU"
        else
            log_warn "ARM64 emulation not available - ARM64 images will fail"
        fi
    fi
    
    return 0
}

# Generic service test function
test_service_deployment() {
    local service_name="$1"
    local test_type="$2"  # docker, native, or auto
    local health_check_cmd="$3"
    local expected_ports="$4"
    
    log_test "Testing $service_name deployment (method: $test_type)..."
    
    local start_time=$(date +%s)
    local success=false
    local method_used=""
    local arch_info=""
    local performance_info=""
    
    case "$test_type" in
        docker)
            success=$(test_docker_service "$service_name" "$health_check_cmd" "$expected_ports")
            method_used="Docker Container"
            ;;
        native)
            success=$(test_native_service "$service_name" "$health_check_cmd" "$expected_ports")
            method_used="Native Binary/Package"
            ;;
        auto)
            # Try multiple methods until one works
            if test_docker_service "$service_name" "$health_check_cmd" "$expected_ports"; then
                success=true
                method_used="Docker Container (auto-selected)"
            elif test_native_service "$service_name" "$health_check_cmd" "$expected_ports"; then
                success=true
                method_used="Native Binary/Package (auto-selected)"
            else
                success=false
                method_used="All methods failed"
            fi
            ;;
    esac
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    performance_info="Deployment time: ${duration}s"
    
    # Store results
    if [ "$success" = true ]; then
        TEST_RESULTS["$service_name"]="SUCCESS"
        log_success "$service_name deployed successfully using $method_used"
    else
        TEST_RESULTS["$service_name"]="FAILED"
        log_error "$service_name deployment failed"
    fi
    
    DEPLOYMENT_METHODS["$service_name"]="$method_used"
    PERFORMANCE_NOTES["$service_name"]="$performance_info"
    
    # Get architecture info if it's a container
    if [[ "$method_used" == *"Docker"* ]] && docker ps --format "{{.Names}}" | grep -q "^$service_name$"; then
        arch_info=$(docker image inspect "$(docker ps --format "{{.Image}}" --filter "name=$service_name")" 2>/dev/null | jq -r '.[0].Architecture' 2>/dev/null || echo "unknown")
        ARCHITECTURE_INFO["$service_name"]="Container: $arch_info"
    elif [[ "$method_used" == *"Native"* ]]; then
        ARCHITECTURE_INFO["$service_name"]="Native: $(uname -m)"
    fi
    
    return $($success)
}

# Test Docker-based service
test_docker_service() {
    local service_name="$1"
    local health_check_cmd="$2"
    local expected_ports="$3"
    
    # Check if service is already running
    if docker ps --format "{{.Names}}" | grep -q "^$service_name$"; then
        log_info "$service_name container already running - testing health"
        if eval "$health_check_cmd" >/dev/null 2>&1; then
            log_success "$service_name is healthy"
            return 0
        else
            log_warn "$service_name running but not healthy - will attempt restart"
            docker restart "$service_name" >/dev/null 2>&1 || return 1
            sleep 10
        fi
    fi
    
    # Try to start the service using its deploy script
    local deploy_script="$PROJECT_ROOT/services/$service_name/deploy.sh"
    if [ -f "$deploy_script" ]; then
        log_debug "Running deployment script: $deploy_script"
        if timeout $TIMEOUT_LONG "$deploy_script" >/dev/null 2>&1; then
            log_debug "Deploy script completed successfully"
        else
            log_debug "Deploy script failed or timed out"
            return 1
        fi
    else
        log_debug "No deploy script found for $service_name"
        return 1
    fi
    
    # Wait for service to be ready
    local attempts=0
    local max_attempts=30
    while [ $attempts -lt $max_attempts ]; do
        if eval "$health_check_cmd" >/dev/null 2>&1; then
            log_debug "$service_name health check passed"
            return 0
        fi
        sleep 2
        ((attempts++))
    done
    
    log_debug "$service_name health check failed after $max_attempts attempts"
    return 1
}

# Test native service deployment
test_native_service() {
    local service_name="$1"
    local health_check_cmd="$2"
    local expected_ports="$3"
    
    # Check if systemd service exists
    if systemctl list-units --type=service | grep -q "$service_name"; then
        log_debug "Found systemd service for $service_name"
        if systemctl is-active --quiet "$service_name"; then
            log_debug "$service_name systemd service is active"
            if eval "$health_check_cmd" >/dev/null 2>&1; then
                return 0
            fi
        else
            log_debug "Starting $service_name systemd service"
            systemctl start "$service_name" >/dev/null 2>&1 || return 1
            sleep 5
            if eval "$health_check_cmd" >/dev/null 2>&1; then
                return 0
            fi
        fi
    fi
    
    # Check for native binary
    local binary_path="/opt/$service_name/bin/$service_name"
    if [ -f "$binary_path" ]; then
        log_debug "Found native binary: $binary_path"
        # Test if binary works
        if "$binary_path" --version >/dev/null 2>&1 || "$binary_path" version >/dev/null 2>&1; then
            log_debug "Native binary is functional"
            return 0
        fi
    fi
    
    return 1
}

# Test individual services
test_velociraptor() {
    log_test "=== Testing Velociraptor (DFIR Platform) ==="
    test_service_deployment "velociraptor" "auto" \
        "curl -k -f https://localhost:8889/ --max-time 10" \
        "8889,8000,8001"
}

test_elasticsearch() {
    log_test "=== Testing Elasticsearch (Search Engine) ==="
    local health_cmd="curl -f http://localhost:9200/_cluster/health --max-time 10"
    if [ -n "${ELASTIC_PASSWORD:-}" ]; then
        health_cmd="curl -u elastic:\$ELASTIC_PASSWORD -f http://localhost:9200/_cluster/health --max-time 10"
    fi
    test_service_deployment "elasticsearch" "docker" "$health_cmd" "9200,9300"
}

test_wazuh_indexer() {
    log_test "=== Testing Wazuh Indexer (Security Data Store) ==="
    test_service_deployment "wazuh-indexer" "docker" \
        "curl -f http://localhost:9400/_cluster/health --max-time 10" \
        "9400"
}

test_cassandra() {
    log_test "=== Testing Cassandra (NoSQL Database) ==="
    test_service_deployment "cassandra" "docker" \
        "docker exec cassandra cqlsh -e 'SELECT release_version FROM system.local;'" \
        "9042,7000"
}

test_portainer() {
    log_test "=== Testing Portainer (Container Management) ==="
    test_service_deployment "portainer" "docker" \
        "curl -k -f https://localhost:9443/ --max-time 10" \
        "9443,8000"
}

test_wazuh_manager() {
    log_test "=== Testing Wazuh Manager (Security Monitoring) ==="
    local health_cmd="curl -k -f https://localhost:55000/ --max-time 10"
    if [ -n "${WAZUH_API_PASSWORD:-}" ]; then
        health_cmd="curl -u wazuh:\$WAZUH_API_PASSWORD -k -f https://localhost:55000/ --max-time 10"
    fi
    test_service_deployment "wazuh-manager" "docker" "$health_cmd" "55000,1514,1515"
}

# Test service integrations
test_service_integrations() {
    log_test "=== Testing Service Integrations ==="
    
    local integration_success=0
    local total_integrations=0
    
    # Test Wazuh Stack Integration
    if [ "${TEST_RESULTS[wazuh-indexer]:-}" = "SUCCESS" ] && [ "${TEST_RESULTS[wazuh-manager]:-}" = "SUCCESS" ]; then
        log_test "Testing Wazuh Indexer <-> Wazuh Manager integration"
        total_integrations=$((total_integrations + 1))
        
        # Simple integration test - check if manager can reach indexer
        if docker exec wazuh-manager curl -f http://wazuh-indexer:9200/_cluster/health --max-time 10 >/dev/null 2>&1; then
            log_success "Wazuh stack integration working"
            integration_success=$((integration_success + 1))
        else
            log_warn "Wazuh stack integration issue detected"
        fi
    fi
    
    # Test Elasticsearch accessibility
    if [ "${TEST_RESULTS[elasticsearch]:-}" = "SUCCESS" ]; then
        log_test "Testing Elasticsearch integration capabilities"
        total_integrations=$((total_integrations + 1))
        
        # Test index creation capability
        if curl -X PUT "localhost:9200/test-index" -H 'Content-Type: application/json' --max-time 10 >/dev/null 2>&1; then
            curl -X DELETE "localhost:9200/test-index" >/dev/null 2>&1
            log_success "Elasticsearch integration capabilities verified"
            integration_success=$((integration_success + 1))
        else
            log_warn "Elasticsearch integration test failed"
        fi
    fi
    
    # Test Velociraptor API accessibility
    if [ "${TEST_RESULTS[velociraptor]:-}" = "SUCCESS" ]; then
        log_test "Testing Velociraptor API accessibility"
        total_integrations=$((total_integrations + 1))
        
        if curl -k -f https://localhost:8000/api/v1/GetVersion --max-time 10 >/dev/null 2>&1; then
            log_success "Velociraptor API integration verified"
            integration_success=$((integration_success + 1))
        else
            log_warn "Velociraptor API integration test failed"
        fi
    fi
    
    if [ $total_integrations -gt 0 ]; then
        log_info "Integration tests: $integration_success/$total_integrations passed"
    else
        log_warn "No services available for integration testing"
    fi
}

# Generate comprehensive report
generate_report() {
    log_info "Generating comprehensive ARM64 deployment report..."
    
    cat >> "$REPORT_FILE" <<EOF

================================
DEPLOYMENT TEST SUMMARY
================================

Host Information:
- Architecture: $BTPI_ARCH
- Platform: $BTPI_PLATFORM
- OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
- Docker Version: $(docker --version 2>/dev/null || echo "Not available")
- Test Duration: Started $(date)

Service Deployment Results:
EOF

    local successful_services=0
    local total_services=0
    
    for service in "${!TEST_RESULTS[@]}"; do
        total_services=$((total_services + 1))
        local status="${TEST_RESULTS[$service]}"
        local method="${DEPLOYMENT_METHODS[$service]:-Unknown}"
        local arch="${ARCHITECTURE_INFO[$service]:-Unknown}"
        local perf="${PERFORMANCE_NOTES[$service]:-}"
        
        if [ "$status" = "SUCCESS" ]; then
            successful_services=$((successful_services + 1))
            echo "✅ $service: $status" >> "$REPORT_FILE"
        else
            echo "❌ $service: $status" >> "$REPORT_FILE"
        fi
        
        echo "   Method: $method" >> "$REPORT_FILE"
        echo "   Architecture: $arch" >> "$REPORT_FILE"
        [ -n "$perf" ] && echo "   Performance: $perf" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    done
    
    cat >> "$REPORT_FILE" <<EOF

================================
SUMMARY STATISTICS
================================

Overall Success Rate: $successful_services/$total_services services ($(( successful_services * 100 / total_services ))%)

Deployment Methods Used:
EOF

    # Count deployment methods
    declare -A method_counts=()
    for service in "${!DEPLOYMENT_METHODS[@]}"; do
        local method="${DEPLOYMENT_METHODS[$service]}"
        method_counts["$method"]=$((${method_counts["$method"]:-0} + 1))
    done
    
    for method in "${!method_counts[@]}"; do
        echo "- $method: ${method_counts[$method]} services" >> "$REPORT_FILE"
    done
    
    cat >> "$REPORT_FILE" <<EOF

================================
RECOMMENDATIONS
================================

EOF

    # Generate recommendations based on results
    if [ $successful_services -eq $total_services ]; then
        echo "🎉 Excellent! All services deployed successfully on ARM64." >> "$REPORT_FILE"
        echo "This system is ready for production BTPI-REACT deployment." >> "$REPORT_FILE"
    elif [ $successful_services -gt $((total_services / 2)) ]; then
        echo "👍 Good! Most services deployed successfully." >> "$REPORT_FILE"
        echo "Review failed services for alternative deployment methods." >> "$REPORT_FILE"
    else
        echo "⚠️ Limited success. This ARM64 system may need additional configuration." >> "$REPORT_FILE"
        echo "Consider x86_64 deployment or investigate ARM64 compatibility issues." >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" <<EOF

Next Steps:
1. Review failed services and attempt alternative deployment methods
2. Test end-to-end workflows for successfully deployed services
3. Monitor performance and stability under load
4. Configure service integrations and authentication
5. Deploy agents and test data collection

Report generated: $(date)
Report location: $REPORT_FILE
EOF

    echo ""
    log_success "Comprehensive report generated: $REPORT_FILE"
    log_info "Deployment success rate: $successful_services/$total_services services"
}

# Main execution
main() {
    echo -e "${CYAN}"
    cat << "EOF"
   ____  _____ _____ ____     ____  _____    _    ____ _____   
  | __ )|_   _|  _  |_   _|   |  _ \| ____|  / \  / ___|_   _|  
  |  _ \  | | | |_) | | |_____| |_) |  _|   / _ \| |     | |    
  | |_) | | | |  __/  | |_____|  _ <| |___ / ___ \ |___  | |    
  |____/  |_| |_|     |_|     |_| \_\_____/_/   \_\____| |_|    
                                                               
     ARM64 Deployment Testing & Validation Suite
EOF
    echo -e "${NC}"
    
    initialize_testing
    test_docker_environment || log_warn "Docker environment issues detected"
    
    log_info "Starting individual service deployment tests..."
    
    # Test core services
    test_elasticsearch
    test_cassandra
    test_portainer
    
    # Test security services  
    test_velociraptor
    test_wazuh_indexer
    test_wazuh_manager
    
    # Test integrations
    test_service_integrations
    
    # Generate report
    generate_report
    
    # Display summary
    local successful=0
    local total=0
    for service in "${!TEST_RESULTS[@]}"; do
        total=$((total + 1))
        [ "${TEST_RESULTS[$service]}" = "SUCCESS" ] && successful=$((successful + 1))
    done
    
    echo ""
    if [ $successful -eq $total ]; then
        log_success "All $total services deployed successfully! 🎉"
    elif [ $successful -gt 0 ]; then
        log_warn "$successful/$total services deployed successfully"
    else
        log_error "No services deployed successfully"
    fi
    
    log_info "Detailed report: $REPORT_FILE"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
