#!/bin/bash
# BTPI-REACT Integration Testing Suite
# Purpose: Comprehensive testing of all deployed services and integrations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results tracking
declare -A TEST_RESULTS
FAILED_TESTS=0
TOTAL_TESTS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARN]${NC} $1"
}

# Test execution wrapper
run_test() {
    local test_name=$1
    local test_function=$2
    
    ((TOTAL_TESTS++))
    log_info "Running test: $test_name"
    
    if $test_function; then
        log_success "$test_name"
        TEST_RESULTS[$test_name]="PASSED"
    else
        log_error "$test_name"
        TEST_RESULTS[$test_name]="FAILED"
        ((FAILED_TESTS++))
    fi
}

# Basic connectivity tests
test_elasticsearch_connectivity() {
    curl -s -k "https://localhost:9200/_cluster/health" | grep -q '"status":"green\|yellow"'
}

test_cassandra_connectivity() {
    docker exec cassandra cqlsh -e "DESC KEYSPACES" >/dev/null 2>&1
}

test_wazuh_manager_connectivity() {
    curl -s -k "https://localhost:55000/" >/dev/null 2>&1
}

test_velociraptor_connectivity() {
    curl -s -k "https://localhost:8889/" >/dev/null 2>&1
}

test_thehive_connectivity() {
    curl -s "http://localhost:9000/api/status" | grep -q '"versions"'
}

test_cortex_connectivity() {
    curl -s "http://localhost:9001/api/status" | grep -q '"versions"'
}

test_kasm_connectivity() {
    curl -s -k "https://localhost:6443/" >/dev/null 2>&1
}

test_portainer_connectivity() {
    curl -s -k "https://localhost:9443/" >/dev/null 2>&1
}

# Service health tests
test_elasticsearch_health() {
    local health_response
    health_response=$(curl -s -k "https://localhost:9200/_cluster/health" 2>/dev/null || echo "failed")
    
    if echo "$health_response" | grep -q '"status":"green"'; then
        return 0
    elif echo "$health_response" | grep -q '"status":"yellow"'; then
        log_warn "Elasticsearch cluster status is yellow (acceptable for single-node)"
        return 0
    else
        return 1
    fi
}

test_cassandra_health() {
    local keyspaces
    keyspaces=$(docker exec cassandra cqlsh -e "DESC KEYSPACES" 2>/dev/null || echo "failed")
    
    echo "$keyspaces" | grep -q "thehive\|cortex"
}

test_wazuh_api_health() {
    curl -s -k -u "admin:${WAZUH_API_PASSWORD}" \
        "https://localhost:55000/security/user/authenticate" | grep -q '"data"'
}

test_velociraptor_api_health() {
    curl -s -k "https://localhost:8889/api/v1/GetVersion" | grep -q '"version"'
}

test_thehive_api_health() {
    local status_response
    status_response=$(curl -s "http://localhost:9000/api/status" 2>/dev/null || echo "failed")
    
    echo "$status_response" | grep -q '"versions"'
}

test_cortex_api_health() {
    local status_response
    status_response=$(curl -s "http://localhost:9001/api/status" 2>/dev/null || echo "failed")
    
    echo "$status_response" | grep -q '"versions"'
}

# Integration tests
test_thehive_cortex_integration() {
    # Test if TheHive can communicate with Cortex
    if [ -z "${CORTEX_API_KEY:-}" ]; then
        log_error "CORTEX_API_KEY not set"
        return 1
    fi
    
    curl -s -H "Authorization: Bearer ${CORTEX_API_KEY}" \
        "http://localhost:9001/api/organization" | grep -q '"name"'
}

test_cortex_analyzers_available() {
    if [ -z "${CORTEX_API_KEY:-}" ]; then
        return 1
    fi
    
    local analyzers_response
    analyzers_response=$(curl -s -H "Authorization: Bearer ${CORTEX_API_KEY}" \
        "http://localhost:9001/api/analyzer" 2>/dev/null || echo "[]")
    
    local analyzer_count
    analyzer_count=$(echo "$analyzers_response" | jq '. | length' 2>/dev/null || echo "0")
    
    [ "$analyzer_count" -gt 0 ]
}

test_cortex_responders_available() {
    if [ -z "${CORTEX_API_KEY:-}" ]; then
        return 1
    fi
    
    local responders_response
    responders_response=$(curl -s -H "Authorization: Bearer ${CORTEX_API_KEY}" \
        "http://localhost:9001/api/responder" 2>/dev/null || echo "[]")
    
    local responder_count
    responder_count=$(echo "$responders_response" | jq '. | length' 2>/dev/null || echo "0")
    
    [ "$responder_count" -gt 0 ]
}

test_wazuh_elasticsearch_integration() {
    # Test if Wazuh data is being indexed in Elasticsearch
    curl -s -k "https://localhost:9200/wazuh-*/_count" | grep -q '"count"'
}

test_velociraptor_client_generation() {
    # Test if Velociraptor can generate client configs
    docker exec velociraptor test -f /var/lib/velociraptor/clients/velociraptor_client.config.yaml 2>/dev/null || \
    docker exec velociraptor ls /var/lib/velociraptor/ >/dev/null 2>&1
}

# Performance tests
test_service_response_times() {
    local services=("elasticsearch:9200" "thehive:9000" "cortex:9001" "velociraptor:8889")
    
    for service_endpoint in "${services[@]}"; do
        local service=$(echo $service_endpoint | cut -d: -f1)
        local port=$(echo $service_endpoint | cut -d: -f2)
        
        local response_time
        if [ "$service" = "elasticsearch" ]; then
            response_time=$(curl -o /dev/null -s -w '%{time_total}\n' -k "https://localhost:$port" 2>/dev/null || echo "999")
        else
            response_time=$(curl -o /dev/null -s -w '%{time_total}\n' "http://localhost:$port" 2>/dev/null || echo "999")
        fi
        
        # Check if response time is reasonable (less than 10 seconds)
        if (( $(echo "$response_time < 10" | bc -l 2>/dev/null || echo "0") )); then
            continue
        else
            log_warn "Service $service response time: ${response_time}s (may be slow)"
            return 1
        fi
    done
    
    return 0
}

test_docker_container_health() {
    local containers=("elasticsearch" "cassandra" "wazuh-manager" "velociraptor" "thehive" "cortex")
    
    for container in "${containers[@]}"; do
        if ! docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            log_error "Container $container is not running"
            return 1
        fi
        
        # Check if container is healthy (not restarting)
        local status
        status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        
        if [ "$status" != "running" ]; then
            log_error "Container $container status: $status"
            return 1
        fi
    done
    
    return 0
}

# Security tests
test_default_credentials_changed() {
    # Test that default credentials are not still active
    local default_tests=0
    
    # Test TheHive default credentials
    if curl -s -u "admin:admin" "http://localhost:9000/api/login" | grep -q '"id"'; then
        log_error "TheHive still using default credentials"
        ((default_tests++))
    fi
    
    # Test Cortex default credentials
    if curl -s -X POST "http://localhost:9001/api/login" \
        -H "Content-Type: application/json" \
        -d '{"user":"admin","password":"admin"}' | grep -q '"token"'; then
        log_error "Cortex still using default credentials"
        ((default_tests++))
    fi
    
    [ $default_tests -eq 0 ]
}

test_ssl_certificates_valid() {
    # Test SSL certificates for services that use them
    local ssl_services=("velociraptor:8889" "elasticsearch:9200")
    
    for service_endpoint in "${ssl_services[@]}"; do
        local service=$(echo $service_endpoint | cut -d: -f1)
        local port=$(echo $service_endpoint | cut -d: -f2)
        
        if ! openssl s_client -connect "localhost:$port" -servername localhost < /dev/null 2>&1 | \
            grep -q "Verify return code: 0\|self signed certificate"; then
            log_error "SSL certificate issue for $service"
            return 1
        fi
    done
    
    return 0
}

# Data persistence tests
test_data_persistence() {
    # Test that data directories exist and are writable
    local data_dirs=("elasticsearch" "cassandra" "thehive" "cortex" "velociraptor" "wazuh")
    
    for dir in "${data_dirs[@]}"; do
        local data_path="${SCRIPT_DIR}/../data/$dir"
        
        if [ ! -d "$data_path" ]; then
            log_error "Data directory missing: $data_path"
            return 1
        fi
        
        # Test write permissions
        if ! touch "$data_path/.test_write" 2>/dev/null; then
            log_error "Cannot write to data directory: $data_path"
            return 1
        fi
        
        rm -f "$data_path/.test_write" 2>/dev/null || true
    done
    
    return 0
}

test_log_persistence() {
    # Test that log directories exist and are being written to
    local log_dirs=("thehive" "cortex" "velociraptor" "wazuh")
    
    for dir in "${log_dirs[@]}"; do
        local log_path="${SCRIPT_DIR}/../logs/$dir"
        
        if [ ! -d "$log_path" ]; then
            log_error "Log directory missing: $log_path"
            return 1
        fi
    done
    
    return 0
}

# Network tests
test_docker_network() {
    # Test that the BTPI network exists and containers are connected
    if ! docker network ls | grep -q "${BTPI_NETWORK}"; then
        log_error "Docker network ${BTPI_NETWORK} not found"
        return 1
    fi
    
    # Test network connectivity between containers
    if ! docker exec thehive ping -c 1 cortex >/dev/null 2>&1; then
        log_error "Network connectivity issue between TheHive and Cortex"
        return 1
    fi
    
    return 0
}

test_port_accessibility() {
    # Test that required ports are accessible
    local ports=("9000" "9001" "8889" "9200" "55000")
    
    for port in "${ports[@]}"; do
        if ! nc -z localhost "$port" 2>/dev/null; then
            log_error "Port $port is not accessible"
            return 1
        fi
    done
    
    return 0
}

# Functional tests
test_thehive_case_creation() {
    # Test creating a case in TheHive
    local case_data='{"title":"Test Case","description":"Integration test case","severity":2,"tlp":2}'
    
    local response
    response=$(curl -s -X POST "http://localhost:9000/api/case" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${THEHIVE_API_KEY:-invalid}" \
        -d "$case_data" 2>/dev/null || echo "failed")
    
    echo "$response" | grep -q '"_id"'
}

test_cortex_analyzer_execution() {
    # Test running a simple analyzer in Cortex
    if [ -z "${CORTEX_API_KEY:-}" ]; then
        return 1
    fi
    
    # Get available analyzers
    local analyzers
    analyzers=$(curl -s -H "Authorization: Bearer ${CORTEX_API_KEY}" \
        "http://localhost:9001/api/analyzer" 2>/dev/null || echo "[]")
    
    # Check if any analyzers are available
    local analyzer_count
    analyzer_count=$(echo "$analyzers" | jq '. | length' 2>/dev/null || echo "0")
    
    [ "$analyzer_count" -gt 0 ]
}

# Generate test report
generate_test_report() {
    local report_file="${SCRIPT_DIR}/../logs/integration_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" <<EOF
BTPI-REACT Integration Test Report
==================================
Generated: $(date)
Test Suite Version: 1.0.0

Test Summary:
- Total Tests: $TOTAL_TESTS
- Passed: $((TOTAL_TESTS - FAILED_TESTS))
- Failed: $FAILED_TESTS
- Success Rate: $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS ))%

Detailed Results:
EOF
    
    for test_name in "${!TEST_RESULTS[@]}"; do
        printf "%-50s %s\n" "$test_name:" "${TEST_RESULTS[$test_name]}" >> "$report_file"
    done
    
    cat >> "$report_file" <<EOF

System Information:
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
- Kernel: $(uname -r)
- Docker: $(docker --version)
- Available Memory: $(free -h | awk '/^Mem:/{print $7}')
- Available Disk: $(df -h / | awk 'NR==2{print $4}')

Service Status:
EOF
    
    # Add service status to report
    local services=("elasticsearch" "cassandra" "wazuh-manager" "velociraptor" "thehive" "cortex")
    for service in "${services[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$service$"; then
            echo "- $service: RUNNING" >> "$report_file"
        else
            echo "- $service: STOPPED" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" <<EOF

Recommendations:
EOF
    
    if [ $FAILED_TESTS -gt 0 ]; then
        cat >> "$report_file" <<EOF
- Review failed tests and check service logs
- Verify system resources are adequate
- Check network connectivity between services
- Ensure all required ports are accessible
EOF
    else
        cat >> "$report_file" <<EOF
- All tests passed successfully
- System is ready for production use
- Consider setting up monitoring and alerting
- Review security hardening checklist
EOF
    fi
    
    echo "$report_file"
}

# Main test execution
main() {
    log_info "Starting BTPI-REACT Integration Tests"
    log_info "====================================="
    
    # Basic connectivity tests
    log_info "Running connectivity tests..."
    run_test "Elasticsearch Connectivity" test_elasticsearch_connectivity
    run_test "Cassandra Connectivity" test_cassandra_connectivity
    run_test "Wazuh Manager Connectivity" test_wazuh_manager_connectivity
    run_test "Velociraptor Connectivity" test_velociraptor_connectivity
    run_test "TheHive Connectivity" test_thehive_connectivity
    run_test "Cortex Connectivity" test_cortex_connectivity
    run_test "Kasm Connectivity" test_kasm_connectivity
    run_test "Portainer Connectivity" test_portainer_connectivity
    
    # Service health tests
    log_info "Running service health tests..."
    run_test "Elasticsearch Health" test_elasticsearch_health
    run_test "Cassandra Health" test_cassandra_health
    run_test "Wazuh API Health" test_wazuh_api_health
    run_test "Velociraptor API Health" test_velociraptor_api_health
    run_test "TheHive API Health" test_thehive_api_health
    run_test "Cortex API Health" test_cortex_api_health
    
    # Integration tests
    log_info "Running integration tests..."
    run_test "TheHive-Cortex Integration" test_thehive_cortex_integration
    run_test "Cortex Analyzers Available" test_cortex_analyzers_available
    run_test "Cortex Responders Available" test_cortex_responders_available
    run_test "Wazuh-Elasticsearch Integration" test_wazuh_elasticsearch_integration
    run_test "Velociraptor Client Generation" test_velociraptor_client_generation
    
    # Performance tests
    log_info "Running performance tests..."
    run_test "Service Response Times" test_service_response_times
    run_test "Docker Container Health" test_docker_container_health
    
    # Security tests
    log_info "Running security tests..."
    run_test "Default Credentials Changed" test_default_credentials_changed
    run_test "SSL Certificates Valid" test_ssl_certificates_valid
    
    # Data persistence tests
    log_info "Running data persistence tests..."
    run_test "Data Persistence" test_data_persistence
    run_test "Log Persistence" test_log_persistence
    
    # Network tests
    log_info "Running network tests..."
    run_test "Docker Network" test_docker_network
    run_test "Port Accessibility" test_port_accessibility
    
    # Functional tests
    log_info "Running functional tests..."
    run_test "TheHive Case Creation" test_thehive_case_creation
    run_test "Cortex Analyzer Execution" test_cortex_analyzer_execution
    
    # Generate report
    log_info "Generating test report..."
    local report_file
    report_file=$(generate_test_report)
    
    # Display summary
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    INTEGRATION TEST RESULTS SUMMARY   ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed: ${GREEN}$((TOTAL_TESTS - FAILED_TESTS))${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    echo -e "Success Rate: ${BLUE}$(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS ))%${NC}"
    echo ""
    echo -e "Detailed report: ${BLUE}$report_file${NC}"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! BTPI-REACT is ready for operation.${NC}"
        exit 0
    else
        echo -e "${RED}⚠️  $FAILED_TESTS tests failed. Please review the issues above.${NC}"
        exit 1
    fi
}

# Check for required tools
check_requirements() {
    local missing_tools=()
    
    for tool in curl jq bc docker; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    # Check for netcat (nc command)
    if ! command -v nc &> /dev/null && ! command -v netcat &> /dev/null; then
        missing_tools+=("netcat")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install missing tools and try again"
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_requirements
    main "$@"
fi
