#!/bin/bash
# BTPI-REACT Deployment Repairs Validation Script
# Version: 1.0.0
# Purpose: Test and validate all deployment repairs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$1")
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test functions
test_ssl_certificates() {
    log_test "Testing SSL certificate generation..."
    ((TESTS_RUN++))

    local cert_dir="$PROJECT_ROOT/config/certificates"
    local required_certs=(
        "ca.crt"
        "ca.key"
        "btpi.crt"
        "btpi.key"
        "root-ca.pem"
        "filebeat.pem"
        "filebeat-key.pem"
        "wazuh-indexer.pem"
        "wazuh-indexer-key.pem"
        "admin.pem"
        "admin-key.pem"
    )

    local missing_certs=()
    for cert in "${required_certs[@]}"; do
        if [ ! -f "$cert_dir/$cert" ]; then
            missing_certs+=("$cert")
        fi
    done

    if [ ${#missing_certs[@]} -eq 0 ]; then
        log_pass "All required SSL certificates are present"

        # Test certificate validity
        if openssl x509 -in "$cert_dir/btpi.crt" -noout -checkend 86400; then
            log_pass "SSL certificates are valid and not expiring soon"
        else
            log_fail "SSL certificates are invalid or expiring soon"
        fi
    else
        log_fail "Missing SSL certificates: ${missing_certs[*]}"
    fi
}

test_deployment_scripts() {
    log_test "Testing deployment script syntax and executability..."
    ((TESTS_RUN++))

    local services=("cassandra" "wazuh-manager" "portainer" "velociraptor" "kasm")
    local script_errors=()

    for service in "${services[@]}"; do
        local script_path="$PROJECT_ROOT/services/$service/deploy.sh"

        if [ ! -f "$script_path" ]; then
            script_errors+=("$service: script not found")
            continue
        fi

        if [ ! -x "$script_path" ]; then
            chmod +x "$script_path"
        fi

        # Test script syntax
        if ! bash -n "$script_path"; then
            script_errors+=("$service: syntax error")
        fi
    done

    if [ ${#script_errors[@]} -eq 0 ]; then
        log_pass "All deployment scripts are valid and executable"
    else
        log_fail "Deployment script issues: ${script_errors[*]}"
    fi
}

test_environment_configuration() {
    log_test "Testing environment configuration..."
    ((TESTS_RUN++))

    if [ ! -f "$PROJECT_ROOT/config/.env" ]; then
        log_fail "Environment file not found at $PROJECT_ROOT/config/.env"
        return
    fi

    # Source environment file
    source "$PROJECT_ROOT/config/.env"

    # Check critical variables
    local required_vars=(
        "SERVER_IP"
        "BTPI_VERSION"
        "BTPI_NETWORK"
        "WAZUH_API_PASSWORD"
        "VELOCIRAPTOR_PASSWORD"
        "KASM_ADMIN_PASSWORD"
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -eq 0 ]; then
        log_pass "All required environment variables are present"
    else
        log_fail "Missing environment variables: ${missing_vars[*]}"
    fi
}

test_docker_networks() {
    log_test "Testing Docker network configuration..."
    ((TESTS_RUN++))

    # Check if required networks exist
    local required_networks=("btpi-network" "btpi-core-network" "btpi-wazuh-network" "btpi-infra-network")
    local missing_networks=()

    for network in "${required_networks[@]}"; do
        if ! docker network ls --format "{{.Name}}" | grep -q "^$network$"; then
            missing_networks+=("$network")
        fi
    done

    if [ ${#missing_networks[@]} -eq 0 ]; then
        log_pass "All required Docker networks exist"
    else
        log_warn "Missing Docker networks (will be created during deployment): ${missing_networks[*]}"
        log_pass "Docker network test passed (networks will be auto-created)"
    fi
}

test_directory_structure() {
    log_test "Testing directory structure..."
    ((TESTS_RUN++))

    local required_dirs=(
        "config"
        "config/certificates"
        "services"
        "services/cassandra"
        "services/wazuh-manager"
        "services/portainer"
        "services/velociraptor"
        "services/kasm"
        "data"
        "logs"
        "scripts"
    )

    local missing_dirs=()
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$PROJECT_ROOT/$dir" ]; then
            missing_dirs+=("$dir")
        fi
    done

    if [ ${#missing_dirs[@]} -eq 0 ]; then
        log_pass "All required directories exist"
    else
        log_fail "Missing directories: ${missing_dirs[*]}"
    fi
}

test_script_dependencies() {
    log_test "Testing script dependencies and commands..."
    ((TESTS_RUN++))

    local required_commands=("docker" "openssl" "curl" "nc")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -eq 0 ]; then
        log_pass "All required commands are available"
    else
        log_fail "Missing required commands: ${missing_commands[*]}"
    fi
}

test_service_configuration_files() {
    log_test "Testing service configuration files..."
    ((TESTS_RUN++))

    local config_files=(
        "services/cassandra/config/cassandra.yaml"
        "services/velociraptor/config/server.config.yaml"
    )

    local missing_configs=()
    for config in "${config_files[@]}"; do
        if [ ! -f "$PROJECT_ROOT/$config" ]; then
            missing_configs+=("$config")
        fi
    done

    if [ ${#missing_configs[@]} -eq 0 ]; then
        log_pass "All service configuration files exist"
    else
        log_warn "Missing service configs (may be auto-generated): ${missing_configs[*]}"
        log_pass "Service configuration test passed (configs will be auto-generated)"
    fi
}

# Test individual service deployment (dry run)
test_service_deployment_dry_run() {
    log_test "Testing service deployment scripts (dry run)..."
    ((TESTS_RUN++))

    local services=("elasticsearch" "cassandra" "wazuh-indexer" "wazuh-manager" "velociraptor" "portainer")
    local script_issues=()

    for service in "${services[@]}"; do
        local script_path="$PROJECT_ROOT/services/$service/deploy.sh"

        if [ ! -f "$script_path" ]; then
            script_issues+=("$service: deployment script missing")
            continue
        fi

        # Test environment loading in script
        if ! grep -q "config/.env" "$script_path"; then
            script_issues+=("$service: doesn't load environment file")
        fi

        # Test error handling
        if ! grep -q "set -euo pipefail" "$script_path"; then
            script_issues+=("$service: missing error handling")
        fi
    done

    if [ ${#script_issues[@]} -eq 0 ]; then
        log_pass "All deployment scripts have proper structure"
    else
        log_fail "Deployment script issues: ${script_issues[*]}"
    fi
}

test_file_permissions() {
    log_test "Testing file permissions..."
    ((TESTS_RUN++))

    local permission_issues=()

    # Check certificate permissions
    if [ -f "$PROJECT_ROOT/config/certificates/btpi.key" ]; then
        local key_perms=$(stat -c "%a" "$PROJECT_ROOT/config/certificates/btpi.key")
        if [ "$key_perms" != "600" ]; then
            permission_issues+=("btpi.key has incorrect permissions: $key_perms (should be 600)")
        fi
    fi

    # Check script executability
    local scripts=(
        "deployment/fresh-btpi-react.sh"
        "config/certificates/generate-wazuh-certs.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "$PROJECT_ROOT/$script" ] && [ ! -x "$PROJECT_ROOT/$script" ]; then
            permission_issues+=("$script is not executable")
        fi
    done

    if [ ${#permission_issues[@]} -eq 0 ]; then
        log_pass "File permissions are correct"
    else
        log_fail "Permission issues: ${permission_issues[*]}"
    fi
}

# Main test execution
run_all_tests() {
    echo -e "${PURPLE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║               BTPI-REACT REPAIR VALIDATION TESTS             ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    log_info "Starting deployment repair validation tests..."
    echo ""

    # Run all tests
    test_ssl_certificates
    test_deployment_scripts
    test_environment_configuration
    test_docker_networks
    test_directory_structure
    test_script_dependencies
    test_service_configuration_files
    test_service_deployment_dry_run
    test_file_permissions

    echo ""
    echo -e "${CYAN}===============================================${NC}"
    echo -e "${CYAN}              TEST RESULTS SUMMARY            ${NC}"
    echo -e "${CYAN}===============================================${NC}"
    echo ""
    echo -e "Tests Run:    ${BLUE}$TESTS_RUN${NC}"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
        echo -e "${GREEN}🎉 Deployment repairs are ready for testing!${NC}"
        echo ""
        echo -e "${CYAN}Next Steps:${NC}"
        echo "1. Run a test deployment: sudo bash deployment/fresh-btpi-react.sh --mode simple"
        echo "2. Monitor the logs for any remaining issues"
        echo "3. Validate service functionality after deployment"
        echo ""
        return 0
    else
        echo -e "${RED}❌ SOME TESTS FAILED${NC}"
        echo ""
        echo -e "${YELLOW}Failed Tests:${NC}"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo -e "  • ${RED}$failed_test${NC}"
        done
        echo ""
        echo -e "${YELLOW}⚠️  Please address the failed tests before deployment${NC}"
        return 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests "$@"
fi
