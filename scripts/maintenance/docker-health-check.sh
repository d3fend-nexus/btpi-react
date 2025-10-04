#!/bin/bash

# Docker Health Check and Configuration Validation Script
# Prevents Docker service failures due to configuration issues

set -euo pipefail

# Configuration
DOCKER_CONFIG_FILE="/etc/docker/daemon.json"
BACKUP_DIR="/etc/docker/backups"
LOG_FILE="/var/log/docker-health-check.log"
SCRIPT_NAME="docker-health-check"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# Print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Create backup directory if it doesn't exist
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        sudo mkdir -p "$BACKUP_DIR"
        log_info "Created backup directory: $BACKUP_DIR"
    fi
}

# Backup current Docker configuration
backup_config() {
    if [[ -f "$DOCKER_CONFIG_FILE" ]]; then
        local backup_file="${BACKUP_DIR}/daemon.json.$(date +%Y%m%d_%H%M%S)"
        sudo cp "$DOCKER_CONFIG_FILE" "$backup_file"
        log_info "Backed up Docker configuration to: $backup_file"
        echo "$backup_file"
    fi
}

# Validate JSON syntax
validate_json_syntax() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_warn "Docker configuration file not found: $config_file"
        return 1
    fi

    if ! sudo jq empty "$config_file" 2>/dev/null; then
        log_error "Invalid JSON syntax in Docker configuration file"
        return 1
    fi

    log_info "JSON syntax validation passed"
    return 0
}

# Get Docker version
get_docker_version() {
    if command -v docker >/dev/null 2>&1; then
        docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
    else
        echo "unknown"
    fi
}

# Check for deprecated configuration options
check_deprecated_options() {
    local config_file="$1"
    local docker_version="$2"
    local issues_found=0

    log_info "Checking for deprecated configuration options..."

    # Check for overlay2.override_kernel_check (deprecated in Docker 20.10+)
    if sudo jq -e '.["storage-opts"][]? | select(. | contains("overlay2.override_kernel_check"))' "$config_file" >/dev/null 2>&1; then
        log_error "Found deprecated option: overlay2.override_kernel_check"
        log_error "This option is not supported in Docker $docker_version"
        issues_found=1
    fi

    # Check for other deprecated options based on Docker version
    local major_version=$(echo "$docker_version" | cut -d. -f1)
    local minor_version=$(echo "$docker_version" | cut -d. -f2)

    if [[ "$major_version" -ge 20 ]]; then
        # Check for deprecated options in Docker 20+
        if sudo jq -e '.["userland-proxy-path"]' "$config_file" >/dev/null 2>&1; then
            log_warn "Option 'userland-proxy-path' is deprecated in Docker $docker_version"
        fi
    fi

    if [[ $issues_found -eq 0 ]]; then
        log_success "No deprecated options found"
    fi

    return $issues_found
}

# Validate Docker daemon configuration
validate_docker_config() {
    local config_file="$1"
    local docker_version="$2"

    log_info "Validating Docker daemon configuration..."

    # Validate JSON syntax
    if ! validate_json_syntax "$config_file"; then
        return 1
    fi

    # Check for deprecated options
    if ! check_deprecated_options "$config_file" "$docker_version"; then
        return 1
    fi

    # Test configuration by attempting to start Docker with --validate flag
    if sudo dockerd --config-file="$config_file" --validate 2>/dev/null; then
        log_success "Docker configuration validation passed"
        return 0
    else
        log_error "Docker configuration validation failed"
        return 1
    fi
}

# Fix common configuration issues
fix_deprecated_options() {
    local config_file="$1"
    local backup_file="$2"

    log_info "Attempting to fix deprecated configuration options..."

    # Create a temporary file for the fixed configuration
    local temp_file=$(mktemp)

    # Remove overlay2.override_kernel_check option
    if sudo jq -e '.["storage-opts"][]? | select(. | contains("overlay2.override_kernel_check"))' "$config_file" >/dev/null 2>&1; then
        log_info "Removing deprecated overlay2.override_kernel_check option"
        sudo jq 'if .["storage-opts"] then .["storage-opts"] = (.["storage-opts"] | map(select(. | contains("overlay2.override_kernel_check") | not))) else . end | if .["storage-opts"] == [] then del(.["storage-opts"]) else . end' "$config_file" > "$temp_file"

        # Validate the fixed configuration
        if validate_json_syntax "$temp_file"; then
            sudo cp "$temp_file" "$config_file"
            log_success "Fixed deprecated configuration options"
        else
            log_error "Failed to fix configuration - restoring backup"
            sudo cp "$backup_file" "$config_file"
            rm -f "$temp_file"
            return 1
        fi
    fi

    rm -f "$temp_file"
    return 0
}

# Check Docker service status
check_docker_service() {
    log_info "Checking Docker service status..."

    if systemctl is-active --quiet docker.service; then
        log_success "Docker service is running"
        return 0
    else
        log_error "Docker service is not running"
        return 1
    fi
}

# Test Docker functionality
test_docker_functionality() {
    log_info "Testing Docker functionality..."

    # Test basic Docker commands
    if docker info >/dev/null 2>&1; then
        log_success "Docker info command successful"
    else
        log_error "Docker info command failed"
        return 1
    fi

    # Test Docker version
    if docker --version >/dev/null 2>&1; then
        log_success "Docker version command successful"
    else
        log_error "Docker version command failed"
        return 1
    fi

    log_success "Docker functionality test passed"
    return 0
}

# Restart Docker service safely
restart_docker_service() {
    log_info "Restarting Docker service..."

    # Stop Docker service and socket
    if sudo systemctl stop docker.service docker.socket; then
        log_info "Docker service stopped"
    else
        log_warn "Failed to stop Docker service gracefully"
    fi

    # Wait a moment for cleanup
    sleep 2

    # Start Docker service
    if sudo systemctl start docker.service; then
        log_info "Docker service started"

        # Wait for Docker to be ready
        local retries=10
        while [[ $retries -gt 0 ]]; do
            if docker info >/dev/null 2>&1; then
                log_success "Docker service is ready"
                return 0
            fi
            log_info "Waiting for Docker to be ready... ($retries retries left)"
            sleep 2
            ((retries--))
        done

        log_error "Docker service failed to become ready"
        return 1
    else
        log_error "Failed to start Docker service"
        return 1
    fi
}

# Main health check function
perform_health_check() {
    local fix_issues="${1:-false}"

    print_status "$BLUE" "=== Docker Health Check Started ==="
    log_info "Starting Docker health check (fix_issues=$fix_issues)"

    # Create backup directory
    create_backup_dir

    # Get Docker version
    local docker_version=$(get_docker_version)
    log_info "Docker version: $docker_version"

    # Backup current configuration
    local backup_file=""
    if [[ -f "$DOCKER_CONFIG_FILE" ]]; then
        backup_file=$(backup_config)
    fi

    # Validate configuration
    if validate_docker_config "$DOCKER_CONFIG_FILE" "$docker_version"; then
        log_success "Docker configuration is valid"
    else
        log_error "Docker configuration validation failed"

        if [[ "$fix_issues" == "true" && -n "$backup_file" ]]; then
            if fix_deprecated_options "$DOCKER_CONFIG_FILE" "$backup_file"; then
                log_info "Configuration issues fixed, restarting Docker service"
                if restart_docker_service; then
                    log_success "Docker service restarted successfully"
                else
                    log_error "Failed to restart Docker service"
                    return 1
                fi
            else
                log_error "Failed to fix configuration issues"
                return 1
            fi
        else
            return 1
        fi
    fi

    # Check service status
    if ! check_docker_service; then
        if [[ "$fix_issues" == "true" ]]; then
            log_info "Attempting to start Docker service"
            if restart_docker_service; then
                log_success "Docker service started successfully"
            else
                log_error "Failed to start Docker service"
                return 1
            fi
        else
            return 1
        fi
    fi

    # Test functionality
    if ! test_docker_functionality; then
        log_error "Docker functionality test failed"
        return 1
    fi

    print_status "$GREEN" "=== Docker Health Check Completed Successfully ==="
    log_success "Docker health check completed successfully"
    return 0
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Docker Health Check and Configuration Validation Script

OPTIONS:
    --check         Perform health check only (default)
    --fix           Perform health check and attempt to fix issues
    --validate      Validate configuration file only
    --help          Show this help message

EXAMPLES:
    $0                  # Perform health check
    $0 --check          # Perform health check
    $0 --fix            # Perform health check and fix issues
    $0 --validate       # Validate configuration only

EOF
}

# Main script execution
main() {
    local action="check"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                action="check"
                shift
                ;;
            --fix)
                action="fix"
                shift
                ;;
            --validate)
                action="validate"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Ensure log file exists and is writable
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"

    case $action in
        check)
            perform_health_check false
            ;;
        fix)
            perform_health_check true
            ;;
        validate)
            local docker_version=$(get_docker_version)
            validate_docker_config "$DOCKER_CONFIG_FILE" "$docker_version"
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
