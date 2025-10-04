#!/bin/bash
# BTPI-REACT Network Isolation Test Suite
# Purpose: Validate network isolation and service functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Import colors and logging functions
log_info() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] [TEST-ISOLATION]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] [TEST-ISOLATION ERROR]\033[0m $1"
}

log_warning() {
    echo -e "\033[0;33m[$(date +'%Y-%m-%d %H:%M:%S')] [TEST-ISOLATION WARNING]\033[0m $1"
}

log_success() {
    echo -e "\033[0;92m[$(date +'%Y-%m-%d %H:%M:%S')] [TEST-SUCCESS]\033[0m $1"
}

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Network definitions
declare -A EXPECTED_NETWORKS=(
    ["btpi-core-network"]="172.24.0.0/16" # IP-OK
    ["btpi-wazuh-network"]="172.21.0.0/16" # IP-OK
    ["btpi-infra-network"]="172.22.0.0/16" # IP-OK
    ["btpi-proxy-network"]="172.23.0.0/16" # IP-OK
)

declare -A SERVICE_NETWORKS=(
    ["elasticsearch"]="btpi-core-network"
    ["wazuh-indexer"]="btpi-wazuh-network"
    ["cassandra"]="btpi-core-network"
)

declare -A SERVICE_PORTS=(
    ["elasticsearch"]="9200"
    ["wazuh-indexer"]="9300"
    ["cassandra"]="9042"
)

# Test helper functions
run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TESTS_TOTAL++))

    echo -n "Testing: $test_name ... "

    if eval "$test_command" &>/dev/null; then
        echo -e "\033[0;32m✓ PASS\033[0m"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "\033[0;31m✗ FAIL\033[0m"
        ((TESTS_FAILED++))
        return 1
    fi
}

run_test_verbose() {
    local test_name="$1"
    local test_command="$2"

    ((TESTS_TOTAL++))

    log_info "Testing: $test_name"

    if eval "$test_command"; then
        log_success "✓ $test_name - PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ $test_name - FAILED"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test network existence
test_networks_exist() {
    log_info "=== Testing Network Existence ==="

    for network in "${!EXPECTED_NETWORKS[@]}"; do
        run_test "Network $network exists" "docker network ls | grep -q '$network'"

        if docker network ls | grep -q "$network"; then
            # Test subnet assignment
            local actual_subnet=$(docker network inspect "$network" -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null)
            local expected_subnet="${EXPECTED_NETWORKS[$network]}"

            if [[ "$actual_subnet" == "$expected_subnet" ]]; then
                run_test "Network $network subnet correct" "true"
            else
                run_test "Network $network subnet correct" "false"
                log_warning "Expected: $expected_subnet, Got: $actual_subnet"
            fi
        fi
    done
}

# Test service network assignment
test_service_networks() {
    log_info "=== Testing Service Network Assignment ==="

    for service in "${!SERVICE_NETWORKS[@]}"; do
        local expected_network="${SERVICE_NETWORKS[$service]}"

        if docker ps --format "table {{.Names}}" | grep -q "^$service$"; then
            run_test_verbose "Service $service is running" "docker ps | grep -q '$service'"

            # Check if service is connected to expected network
            local connected_networks=$(docker inspect "$service" -f '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null || echo "")

            if [[ "$connected_networks" =~ $expected_network ]]; then
                run_test "Service $service on $expected_network" "true"

                # Get service IP in the network
                local service_ip=$(docker inspect "$service" -f "{{.NetworkSettings.Networks.$expected_network.IPAddress}}" 2>/dev/null || echo "")
                if [[ -n "$service_ip" && "$service_ip" != "<no value>" ]]; then
                    log_info "Service $service IP in $expected_network: $service_ip"
                fi
            else
                run_test "Service $service on $expected_network" "false"
                log_error "Service $service connected to: $connected_networks"
            fi
        else
            log_warning "Service $service not running - skipping network tests"
        fi
    done
}

# Test network isolation (services can't reach other networks directly)
test_network_isolation() {
    log_info "=== Testing Network Isolation ==="

    # Test if elasticsearch (core network) can reach wazuh-indexer network directly
    if docker ps | grep -q elasticsearch && docker ps | grep -q wazuh-indexer; then
        local wazuh_ip=$(docker inspect wazuh-indexer -f '{{.NetworkSettings.Networks.btpi-wazuh-network.IPAddress}}' 2>/dev/null || echo "")

        if [[ -n "$wazuh_ip" && "$wazuh_ip" != "<no value>" ]]; then
            # This should fail (proving isolation)
            run_test "Elasticsearch CANNOT reach Wazuh-indexer directly" \
                "! docker exec elasticsearch ping -c 1 -W 1 $wazuh_ip"
        fi
    fi

    # Test reverse isolation
    if docker ps | grep -q wazuh-indexer && docker ps | grep -q elasticsearch; then
        local es_ip=$(docker inspect elasticsearch -f '{{.NetworkSettings.Networks.btpi-core-network.IPAddress}}' 2>/dev/null || echo "")

        if [[ -n "$es_ip" && "$es_ip" != "<no value>" ]]; then
            # This should fail (proving isolation)
            run_test "Wazuh-indexer CANNOT reach Elasticsearch directly" \
                "! docker exec wazuh-indexer ping -c 1 -W 1 $es_ip"
        fi
    fi
}

# Test external port accessibility
test_external_connectivity() {
    log_info "=== Testing External Port Accessibility ==="

    # Test Elasticsearch on port 9200
    run_test "Elasticsearch accessible on port 9200" \
        "curl -s -f http://localhost:9200/_cluster/health"

    # Test Wazuh indexer on port 9300
    run_test "Wazuh-indexer accessible on port 9300" \
        "curl -s -f http://localhost:9300/_cluster/health || curl -s -k -f https://localhost:9300/_cluster/health"

    # Test that old Wazuh port 9201 is no longer in use
    run_test "Old Wazuh port 9201 NOT accessible" \
        "! nc -z localhost 9201"
}

# Test service functionality within isolated networks
test_service_functionality() {
    log_info "=== Testing Service Functionality ==="

    # Test Elasticsearch functionality
    if curl -s "http://localhost:9200/_cluster/health" >/dev/null 2>&1; then
        run_test "Elasticsearch cluster health" \
            "curl -s 'http://localhost:9200/_cluster/health' | grep -q '\"status\":\"\\(green\\|yellow\\)\"'"

        # Test index creation
        local test_index="isolation-test-$(date +%s)"
        run_test "Elasticsearch index operations" \
            "curl -s -X PUT 'http://localhost:9200/$test_index' -H 'Content-Type: application/json' -d '{\"settings\":{\"number_of_shards\":1}}' && \
             curl -s -X DELETE 'http://localhost:9200/$test_index'"
    fi

    # Test Wazuh indexer functionality
    local wazuh_available=false
    if curl -s "http://localhost:9300/_cluster/health" >/dev/null 2>&1; then
        wazuh_available=true
    elif curl -s -k "https://localhost:9300/_cluster/health" >/dev/null 2>&1; then
        wazuh_available=true
    fi

    if $wazuh_available; then
        run_test "Wazuh-indexer cluster response" \
            "curl -s 'http://localhost:9300/_cluster/health' || curl -s -k 'https://localhost:9300/_cluster/health'"

        # Test basic Wazuh indexer operations
        local test_index="wazuh-isolation-test-$(date +%s)"
        run_test "Wazuh-indexer index operations" \
            "curl -s -X PUT 'http://localhost:9300/$test_index' -H 'Content-Type: application/json' -d '{\"settings\":{\"number_of_shards\":1}}' && \
             curl -s -X DELETE 'http://localhost:9300/$test_index'"
    fi
}

# Test network gateway connectivity
test_gateway_connectivity() {
    log_info "=== Testing Network Gateway Connectivity ==="

    for network in "${!EXPECTED_NETWORKS[@]}"; do
        if docker network ls | grep -q "$network"; then
            local gateway=$(docker network inspect "$network" -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "")

            if [[ -n "$gateway" ]]; then
                run_test "Network $network gateway ($gateway) reachable" \
                    "ping -c 1 -W 2 $gateway"
            fi
        fi
    done
}

# Test network bridge configuration
test_bridge_config() {
    log_info "=== Testing Network Bridge Configuration ==="

    for network in "${!EXPECTED_NETWORKS[@]}"; do
        if docker network ls | grep -q "$network"; then
            # Test bridge exists
            local bridge_name="br-$(echo $network | cut -c1-10)"
            run_test "Bridge for $network exists" \
                "ip link show | grep -q $bridge_name || brctl show | grep -q $network"
        fi
    done
}

# Generate detailed network report
generate_network_report() {
    log_info "=== Generating Network Report ==="

    echo ""
    echo "======================================"
    echo "BTPI-REACT Network Isolation Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""

    echo "Network Status:"
    for network in "${!EXPECTED_NETWORKS[@]}"; do
        if docker network ls | grep -q "$network"; then
            local subnet=$(docker network inspect "$network" -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null)
            local gateway=$(docker network inspect "$network" -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
            echo "  ✓ $network: $subnet (Gateway: $gateway)"

            # List containers
            local containers=$(docker network inspect "$network" -f '{{range $id,$container := .Containers}}{{$container.Name}} {{end}}' 2>/dev/null)
            if [[ -n "$containers" && "$containers" != " " ]]; then
                echo "    Containers: $containers"
            fi
        else
            echo "  ✗ $network: NOT FOUND"
        fi
    done

    echo ""
    echo "Service Network Assignment:"
    for service in "${!SERVICE_NETWORKS[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$service$"; then
            local expected="${SERVICE_NETWORKS[$service]}"
            local networks=$(docker inspect "$service" -f '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null)
            echo "  $service: $networks (expected: $expected)"
        else
            echo "  $service: NOT RUNNING"
        fi
    done

    echo ""
    echo "Port Accessibility:"
    for service in "${!SERVICE_PORTS[@]}"; do
        local port="${SERVICE_PORTS[$service]}"
        if nc -z localhost "$port" 2>/dev/null; then
            echo "  ✓ $service: localhost:$port"
        else
            echo "  ✗ $service: localhost:$port (not accessible)"
        fi
    done
}

# Main test execution
main() {
    log_info "Starting BTPI-REACT Network Isolation Test Suite..."
    echo ""

    # Run all tests
    test_networks_exist
    echo ""

    test_service_networks
    echo ""

    test_network_isolation
    echo ""

    test_external_connectivity
    echo ""

    test_service_functionality
    echo ""

    test_gateway_connectivity
    echo ""

    test_bridge_config
    echo ""

    # Generate report
    generate_network_report
    echo ""

    # Test summary
    echo "======================================"
    echo "TEST SUMMARY"
    echo "======================================"
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! Network isolation is working correctly."
        echo ""
        log_info "Key Achievements:"
        log_info "✓ Services are isolated in their designated networks"
        log_info "✓ External port access is working correctly"
        log_info "✓ Network isolation prevents cross-network direct communication"
        log_info "✓ Service functionality is maintained within networks"
        return 0
    else
        log_error "$TESTS_FAILED tests failed. Network isolation needs attention."
        return 1
    fi
}

# Handle script interruption
trap 'log_error "Test interrupted"; exit 1' INT TERM

main "$@"
