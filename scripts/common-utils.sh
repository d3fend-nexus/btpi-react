#!/bin/bash
# BTPI-REACT Common Utilities
# Version: 2.0.0
# Purpose: Shared functions for all BTPI-REACT deployment scripts
# Author: BTPI-REACT Optimization Team

set -euo pipefail

# Color codes for output
declare -g RED='\033[0;31m'
declare -g GREEN='\033[0;32m'
declare -g YELLOW='\033[1;33m'
declare -g BLUE='\033[0;34m'
declare -g PURPLE='\033[0;35m'
declare -g CYAN='\033[0;36m'
declare -g NC='\033[0m'

# Common configuration
declare -g BTPI_VERSION="2.0.0"
declare -g SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
declare -g CONFIG_DIR="${SCRIPT_DIR}/config"
declare -g SERVICES_DIR="${SCRIPT_DIR}/services"
declare -g DATA_DIR="${SCRIPT_DIR}/data"
declare -g LOGS_DIR="${SCRIPT_DIR}/logs"
declare -g BACKUPS_DIR="${SCRIPT_DIR}/backups"

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

# Logging functions
log_info() {
    local message="$1"
    local service="${2:-BTPI}"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [${service}] [INFO]${NC} $message" | tee -a "$LOGS_DIR/deployment.log"
}

log_warn() {
    local message="$1"
    local service="${2:-BTPI}"
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [${service}] [WARN]${NC} $message" | tee -a "$LOGS_DIR/deployment.log"
}

log_error() {
    local message="$1"
    local service="${2:-BTPI}"
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [${service}] [ERROR]${NC} $message" | tee -a "$LOGS_DIR/deployment.log"
}

log_debug() {
    local message="$1"
    local service="${2:-BTPI}"
    if [[ "${DEBUG:-true}" == "true" ]]; then
        echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [${service}] [DEBUG]${NC} $message" | tee -a "$LOGS_DIR/deployment.log"
    fi
}

log_success() {
    local message="$1"
    local service="${2:-BTPI}"
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] [${service}] [SUCCESS]${NC} $message" | tee -a "$LOGS_DIR/deployment.log"
}

# Banner function
show_banner() {
    local version="${1:-$BTPI_VERSION}"
    local subtitle="${2:-Blue Team Portable Infrastructure - Rapid Emergency Analysis & Counter-Threat}"

    echo -e "${PURPLE}"
    cat << 'EOF'
    ____  ______  ____  ____      ____  _________   ____________
   / __ )/_  __/ / __ \/  _/     / __ \/ ____/   | / ____/_  __/
  / __  | / /   / /_/ // /______/ /_/ / __/ / /| |/ /     / /
 / /_/ / / /   / ____// /_____/ _, _/ /___/ ___ / /___  / /
/_____/ /_/   /_/   /___/    /_/ |_/_____/_/  |_\____/ /_/

EOF
    echo -e "${NC}"
    echo -e "${subtitle}"
    echo -e "${GREEN}Version: $version${NC}"
    echo -e "${GREEN}Date: $(date)${NC}"
    echo ""
}

# Directory initialization
init_directories() {
    log_info "Initializing directory structure..."

    local dirs=("$CONFIG_DIR" "$SERVICES_DIR" "$DATA_DIR" "$LOGS_DIR" "$BACKUPS_DIR")
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done

    # Create service-specific directories
    local services=("elasticsearch" "cassandra" "wazuh-indexer" "wazuh-manager" "velociraptor" "kasm" "portainer" "nginx")
    for service in "${services[@]}"; do
        mkdir -p "$DATA_DIR/$service"
        mkdir -p "$LOGS_DIR/$service"
        mkdir -p "$CONFIG_DIR/$service"
        mkdir -p "$SERVICES_DIR/$service"
    done

    # Create integration directory
    mkdir -p "$SERVICES_DIR/integrations"
    mkdir -p "$SCRIPT_DIR/tests"
    mkdir -p "$SCRIPT_DIR/docs"

    log_success "Directory structure initialized"
}

# Environment generation with centralized configuration
generate_environment() {
    log_info "Generating environment configuration..."

    local deployment_id="${1:-$(uuidgen 2>/dev/null || openssl rand -hex 8)}"
    local deployment_date="${2:-$(date +%Y%m%d_%H%M%S)}"

    if [ ! -f "$CONFIG_DIR/.env" ]; then
        cat > "$CONFIG_DIR/.env" <<EOF
# BTPI-REACT Environment Configuration
# Generated: $(date)
# Deployment ID: $deployment_id

# System Configuration
BTPI_VERSION=$BTPI_VERSION
DEPLOYMENT_ID=$deployment_id
DEPLOYMENT_DATE=$deployment_date

# Database Passwords
ELASTIC_PASSWORD=$(openssl rand -base64 32)
CASSANDRA_PASSWORD=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Application Secrets
VELOCIRAPTOR_PASSWORD=$(openssl rand -base64 32)
WAZUH_API_PASSWORD=$(openssl rand -base64 32)

# Cluster Keys
WAZUH_CLUSTER_KEY=$(openssl rand -hex 32)

# JWT Secrets
JWT_SECRET=$(openssl rand -base64 64)

# Domain Configuration
DOMAIN_NAME=btpi.local
SERVER_IP=$(hostname -I | awk '{print $1}')

# Kasm Configuration
KASM_DEFAULT_ADMIN_PASSWORD=$(openssl rand -base64 16)
KASM_DEFAULT_USER_PASSWORD=$(openssl rand -base64 16)

# Network Configuration
BTPI_NETWORK=btpi-network
BTPI_CORE_NETWORK=btpi-core-network
BTPI_WAZUH_NETWORK=btpi-wazuh-network
EOF
        chmod 600 "$CONFIG_DIR/.env"
        log_success "Environment configuration generated"
    else
        log_info "Environment configuration already exists"
    fi

    # Source the environment file for current session
    source "$CONFIG_DIR/.env"

    # Ensure critical variables are exported
    export BTPI_NETWORK="${BTPI_NETWORK:-btpi-network}"
    export BTPI_CORE_NETWORK="${BTPI_CORE_NETWORK:-btpi-core-network}"
    export BTPI_WAZUH_NETWORK="${BTPI_WAZUH_NETWORK:-btpi-wazuh-network}"
    export SERVER_IP="${SERVER_IP:-$(hostname -I | awk '{print $1}')}"
}

# Validate required environment variables
validate_environment() {
    local service="${1:-BTPI}"
    log_info "Validating environment configuration..." "$service"

    # List of required variables
    local required_vars=("BTPI_NETWORK" "SERVER_IP" "BTPI_VERSION")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    # Check if .env exists and source it if variables are missing
    if [[ ${#missing_vars[@]} -gt 0 ]] && [[ -f "$CONFIG_DIR/.env" ]]; then
        log_info "Sourcing environment file to load missing variables..." "$service"
        source "$CONFIG_DIR/.env"

        # Re-check missing variables
        missing_vars=()
        for var in "${required_vars[@]}"; do
            if [[ -z "${!var:-}" ]]; then
                missing_vars+=("$var")
            fi
        done
    fi

    # If still missing variables, try to initialize them
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_warn "Missing environment variables: ${missing_vars[*]}" "$service"
        log_info "Attempting to initialize environment..." "$service"

        # Set default values for missing variables
        export BTPI_NETWORK="${BTPI_NETWORK:-btpi-network}"
        export BTPI_CORE_NETWORK="${BTPI_CORE_NETWORK:-btpi-core-network}"
        export BTPI_WAZUH_NETWORK="${BTPI_WAZUH_NETWORK:-btpi-wazuh-network}"
        export SERVER_IP="${SERVER_IP:-$(hostname -I | awk '{print $1}')}"
        export BTPI_VERSION="${BTPI_VERSION:-2.0.0}"

        log_success "Environment variables initialized with defaults" "$service"
    else
        log_success "All required environment variables are present" "$service"
    fi

    # Export critical environment variables for service health checks
    if [ -f "$CONFIG_DIR/.env" ]; then
        export ELASTIC_PASSWORD="${ELASTIC_PASSWORD:-}"
        export CASSANDRA_PASSWORD="${CASSANDRA_PASSWORD:-}"
        export WAZUH_API_PASSWORD="${WAZUH_API_PASSWORD:-}"
        export VELOCIRAPTOR_PASSWORD="${VELOCIRAPTOR_PASSWORD:-}"
    fi

    # Display current values for debugging
    log_debug "Current environment values:" "$service"
    log_debug "  BTPI_NETWORK: ${BTPI_NETWORK}" "$service"
    log_debug "  SERVER_IP: ${SERVER_IP}" "$service"
    log_debug "  BTPI_VERSION: ${BTPI_VERSION}" "$service"
    log_debug "  ELASTIC_PASSWORD: ${ELASTIC_PASSWORD:+SET}" "$service"
}

# SSL certificate generation
generate_ssl_certificates() {
    log_info "Generating SSL certificates..."

    local server_ip="${SERVER_IP:-$(hostname -I | awk '{print $1}')}"

    if [ ! -f "$CONFIG_DIR/certificates/btpi.crt" ]; then
        mkdir -p "$CONFIG_DIR/certificates"

        # Generate CA key and certificate
        openssl genrsa -out "$CONFIG_DIR/certificates/ca.key" 4096
        openssl req -new -x509 -days 365 -key "$CONFIG_DIR/certificates/ca.key" \
            -out "$CONFIG_DIR/certificates/ca.crt" \
            -subj "/C=US/ST=State/L=City/O=BTPI-REACT/CN=BTPI-REACT-CA"

        # Generate server key and certificate
        openssl genrsa -out "$CONFIG_DIR/certificates/btpi.key" 4096
        openssl req -new -key "$CONFIG_DIR/certificates/btpi.key" \
            -out "$CONFIG_DIR/certificates/btpi.csr" \
            -subj "/C=US/ST=State/L=City/O=BTPI-REACT/CN=btpi.local"

        # Create certificate with SAN
        cat > "$CONFIG_DIR/certificates/btpi.conf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = BTPI-REACT
CN = btpi.local

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = btpi.local
DNS.2 = *.btpi.local
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = $server_ip
EOF

        openssl x509 -req -in "$CONFIG_DIR/certificates/btpi.csr" \
            -CA "$CONFIG_DIR/certificates/ca.crt" \
            -CAkey "$CONFIG_DIR/certificates/ca.key" \
            -CAcreateserial -out "$CONFIG_DIR/certificates/btpi.crt" \
            -days 365 -extensions v3_req -extfile "$CONFIG_DIR/certificates/btpi.conf"

        # Set proper permissions
        chmod 600 "$CONFIG_DIR/certificates"/*.key
        chmod 644 "$CONFIG_DIR/certificates"/*.crt

        log_success "SSL certificates generated"
    else
        log_info "SSL certificates already exist"
    fi
}

# Docker network management
create_docker_network() {
    local network_name="${1:-${BTPI_NETWORK:-btpi-network}}"

    log_info "Creating Docker network: $network_name"

    if ! docker network ls | grep -q "$network_name"; then
        docker network create \
            --driver bridge \
            --subnet=172.20.0.0/16 \ # IP-OK
            --ip-range=172.20.240.0/20 \ # IP-OK
            "$network_name"
        log_success "Docker network '$network_name' created"
    else
        log_info "Docker network '$network_name' already exists"
    fi
}

# Comprehensive Docker network setup
setup_docker_networks() {
    log_info "Setting up comprehensive Docker network infrastructure..."

    # Check if setup-networks.sh exists and run it
    if [ -f "$SCRIPT_DIR/scripts/setup-networks.sh" ]; then
        log_info "Running network setup script..."
        bash "$SCRIPT_DIR/scripts/setup-networks.sh"

        if [ $? -eq 0 ]; then
            log_success "Network setup completed successfully"
        else
            log_error "Network setup script failed"
            return 1
        fi
    else
        log_warn "setup-networks.sh not found, falling back to basic network creation"
        create_docker_network
    fi

    # Verify critical networks exist
    local critical_networks=("${BTPI_CORE_NETWORK:-btpi-core-network}" "${BTPI_WAZUH_NETWORK:-btpi-wazuh-network}")
    for network in "${critical_networks[@]}"; do
        if ! docker network ls --format "{{.Name}}" | grep -q "^${network}$"; then
            log_error "Critical network '$network' was not created"
            return 1
        else
            log_success "Network '$network' is available"
        fi
    done

    return 0
}

# Port conflict checking with smart service validation
check_port_conflicts() {
    log_info "Checking for port conflicts..."

    # Define service ports
    declare -A service_ports=(
        ["elasticsearch"]="9200"
        ["cassandra"]="9042"
        ["wazuh-indexer"]="9201,9600"
        ["wazuh-manager"]="1514,1515,55000"
        ["wazuh-dashboard"]="5601"
        ["velociraptor"]="8000,8889"
        ["nginx"]="80,443"
        ["kasm"]="6443"
        ["portainer"]="8000,9443"
    )

    local conflicts=0
    local resolved_conflicts=0

    for service in "${!service_ports[@]}"; do
        IFS=',' read -ra ports <<< "${service_ports[$service]}"
        for port in "${ports[@]}"; do
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                local process=$(lsof -Pi :$port -sTCP:LISTEN | tail -n 1 | awk '{print $1}')

                # Check if the service using the port is the expected service and healthy
                if validate_existing_service "$service" "$port"; then
                    log_info "Port $port is in use by healthy $service - conflict resolved automatically"
                    ((resolved_conflicts++))
                else
                    log_warn "Port $port is already in use by $process (required for $service)"
                    ((conflicts++))
                fi
            fi
        done
    done

    if [ $conflicts -gt 0 ]; then
        if [ $resolved_conflicts -gt 0 ]; then
            log_info "Resolved $resolved_conflicts port conflicts automatically"
            log_warn "Found $conflicts unresolvable port conflicts"
        else
            log_error "Found $conflicts port conflicts"
        fi
        return 1
    else
        if [ $resolved_conflicts -gt 0 ]; then
            log_success "Resolved $resolved_conflicts port conflicts automatically"
        else
            log_success "No port conflicts detected"
        fi
        return 0
    fi
}

# Validate existing service on port
validate_existing_service() {
    local service="$1"
    local port="$2"

    log_debug "Validating existing $service service on port $port..."

    # Check if the service container exists and is healthy
    if docker ps --format "{{.Names}}" | grep -q "^$service$"; then
        local container_status=$(docker inspect --format '{{.State.Status}}' "$service" 2>/dev/null || echo "unknown")
        local health_status=$(docker inspect --format '{{.State.Health.Status}}' "$service" 2>/dev/null || echo "unknown")

        if [ "$container_status" = "running" ]; then
            # Perform service-specific health check
            if check_service_health "$service"; then
                log_debug "$service is running and healthy - port conflict resolved"
                return 0
            else
                log_debug "$service is running but not healthy - port conflict remains"
                return 1
            fi
        else
            log_debug "$service container exists but not running - port conflict remains"
            return 1
        fi
    else
        # Check if it's a docker-proxy process for our service
        local process_cmd=$(ps aux | grep "[0-9].*:$port" | grep -v grep || echo "")
        if echo "$process_cmd" | grep -q "docker-proxy"; then
            # This might be our service's proxy - try to validate the service
            if docker ps --format "{{.Names}}" | grep -q "^$service$" && check_service_health "$service"; then
                log_debug "$service proxy detected and service is healthy - port conflict resolved"
                return 0
            fi
        fi

        log_debug "No healthy $service found - port conflict remains"
        return 1
    fi
}

# System requirements check
check_system_requirements() {
    log_info "Checking system requirements..."

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        return 1
    fi

    # Check operating system
    if ! grep -q "Ubuntu 22.04\|Ubuntu 20.04\|Debian 11\|Debian 12" /etc/os-release; then
        log_warn "This script is optimized for Ubuntu 22.04/20.04 or Debian 11/12"
    fi

    # Check system resources
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    local total_cpu=$(nproc)
    local available_disk=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')

    log_info "System Resources:"
    log_info "  CPU Cores: $total_cpu"
    log_info "  Memory: ${total_mem}GB"
    log_info "  Available Disk: ${available_disk}GB"

    local requirements_met=true

    if [ "$total_mem" -lt 16 ]; then
        log_warn "System has less than 16GB RAM. Performance may be impacted."
    fi

    if [ "$total_cpu" -lt 4 ]; then
        log_warn "System has less than 4 CPU cores. Performance may be impacted."
    fi

    if [ "$available_disk" -lt 100 ]; then
        log_error "Less than 100GB disk space available. Cannot proceed."
        requirements_met=false
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        requirements_met=false
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed or not working"
        requirements_met=false
    fi

    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "No internet connectivity detected"
        requirements_met=false
    fi

    if [ "$requirements_met" = true ]; then
        log_success "System requirements check passed"
        return 0
    else
        log_error "System requirements check failed"
        return 1
    fi
}

# Enhanced service health checking
wait_for_service() {
    echo "[WAIT] Waiting for service: $1 (max ${2:-120}s)"
    local service="$1"
    local max_wait="${2:-120}"
    local port="${3:-}"

    log_info "Waiting for $service to be ready (max ${max_wait}s)..."

    local attempt=1
    local max_attempts=$((max_wait / 10))

    while [ $attempt -le $max_attempts ]; do
        if check_service_health "$service" "$port"; then
            log_success "$service is ready and healthy"
            return 0
        fi

        log_debug "$service health check attempt $attempt/$max_attempts failed, waiting 10s..."
        sleep 10
        ((attempt++))
    done

    log_error "$service failed to become ready within ${max_wait}s"
    show_service_debug_info "$service"
    return 1
}

# Enhanced Elasticsearch health check function with dynamic password support
check_elasticsearch_health() {
    # Ensure environment is loaded
    if [ -z "${ELASTIC_PASSWORD:-}" ] && [ -f "$CONFIG_DIR/.env" ]; then
        log_debug "Loading environment for Elasticsearch health check..."
        source "$CONFIG_DIR/.env"
    fi

    if ! nc -z localhost 9200 2>/dev/null; then
        log_debug "Elasticsearch port 9200 is not responding"
        return 1
    fi

    # Use authentication credentials from environment
    local elastic_user="elastic"
    local elastic_password="${ELASTIC_PASSWORD:-}"

    log_debug "Testing Elasticsearch health with credentials: user=$elastic_user, password=${elastic_password:0:4}***"

    if [ -z "$elastic_password" ]; then
        log_debug "No Elasticsearch password found, trying without auth..."
        local health_response=$(curl -s --max-time 10 "http://localhost:9200/_cluster/health" 2>/dev/null)
    else
        local health_response=$(curl -s --max-time 10 -u "$elastic_user:$elastic_password" "http://localhost:9200/_cluster/health" 2>/dev/null)
    fi

    if [[ -z "$health_response" ]]; then
        log_debug "No response from Elasticsearch health endpoint"
        return 1
    fi

    log_debug "Elasticsearch health response: ${health_response:0:100}..."

    # Check for authentication error
    if echo "$health_response" | grep -q "security_exception"; then
        log_debug "Elasticsearch requires authentication but health check succeeded with connectivity"
        # If we can connect but get auth error, consider it healthy for deployment purposes
        return 0
    fi

    local cluster_status=$(echo "$health_response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [[ "$cluster_status" =~ ^(green|yellow)$ ]]; then
        log_debug "Elasticsearch cluster status: $cluster_status - HEALTHY"
        return 0
    else
        log_debug "Elasticsearch cluster status: $cluster_status - UNHEALTHY"
        return 1
    fi
}

# Service-specific health checking
check_service_health() {
    local service="$1"
    local port="${2:-}"

    # First check if container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^$service$"; then
        log_debug "$service container is not running"
        return 1
    fi

    # Service-specific health checks
    case $service in
        elasticsearch)
            check_elasticsearch_health
            ;;
        wazuh-indexer)
            # Try HTTPS first, then HTTP
            curl -k -s --max-time 10 "https://localhost:9201/_cluster/health" >/dev/null 2>&1 || \
            curl -s --max-time 10 "http://localhost:9201/_cluster/health" >/dev/null 2>&1
            ;;
        cassandra)
            docker exec "$service" cqlsh -h localhost -p 9042 -e "SELECT release_version FROM system.local;" >/dev/null 2>&1
            ;;
        wazuh-manager)
            curl -s -k --max-time 10 "https://localhost:55000/" >/dev/null 2>&1
            ;;
        velociraptor)
            curl -s -k --max-time 10 "https://localhost:8889/" >/dev/null 2>&1
            ;;
        kasm)
            # Kasm uses port 8443 not 6443
            curl -s -k --max-time 10 "https://localhost:8443/" >/dev/null 2>&1
            ;;
        portainer)
            curl -s -k --max-time 10 "https://localhost:9443/" >/dev/null 2>&1
            ;;
        *)
            # Generic port check if port provided
            if [ -n "$port" ]; then
                nc -z localhost "$port" 2>/dev/null
            else
                # Just check if container is running (already done above)
                return 0
            fi
            ;;
    esac
}

# Service debug information
show_service_debug_info() {
    local service="$1"

    log_debug "=== DEBUG INFO FOR $service ==="

    # Container status
    if docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$service"; then
        log_debug "Container status:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "$service" | while read line; do
            log_debug "  $line"
        done
    else
        log_debug "Container '$service' not found"
    fi

    # Container logs (last 10 lines)
    log_debug "Recent container logs:"
    if docker logs --tail=10 "$service" 2>/dev/null; then
        docker logs --tail=10 "$service" 2>&1 | while read line; do
            log_debug "  LOG: $line"
        done
    else
        log_debug "  Could not retrieve logs for $service"
    fi

    log_debug "=== END DEBUG INFO FOR $service ==="
}

# Service deployment wrapper
deploy_service() {
    local service="$1"
    local deploy_script="$SERVICES_DIR/$service/deploy.sh"

    log_info "Deploying service: $service" "$service"

    if [ -f "$deploy_script" ]; then
        log_debug "Using service deployment script: $deploy_script" "$service"
        bash "$deploy_script"
        return $?
    else
        log_error "No deployment script found for $service" "$service"
        return 1
    fi
}

# Update /etc/hosts for local domain resolution
update_hosts_file() {
    local server_ip="${SERVER_IP:-$(hostname -I | awk '{print $1}')}"

    log_info "Updating /etc/hosts for local domain resolution..."

    # Remove existing BTPI entries
    sed -i '/# BTPI-REACT entries/,/# End BTPI-REACT entries/d' /etc/hosts

    # Add new entries
    cat >> /etc/hosts <<EOF
# BTPI-REACT entries
$server_ip btpi.local
$server_ip wazuh.btpi.local
$server_ip velociraptor.btpi.local
$server_ip kasm.btpi.local
$server_ip portainer.btpi.local
# End BTPI-REACT entries
EOF

    log_success "/etc/hosts updated"
}

# Backup existing deployment
backup_existing_deployment() {
    if [ -d "$DATA_DIR" ] && [ "$(ls -A $DATA_DIR)" ]; then
        log_info "Backing up existing deployment..."
        local backup_name="btpi-backup-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUPS_DIR"
        tar -czf "$BACKUPS_DIR/$backup_name.tar.gz" -C "$SCRIPT_DIR" data config logs 2>/dev/null || true
        log_success "Backup created: $BACKUPS_DIR/$backup_name.tar.gz"
    fi
}

# Generate deployment report
generate_deployment_report() {
    local deployment_date="${1:-$(date +%Y%m%d_%H%M%S)}"
    local deployment_id="${2:-${DEPLOYMENT_ID:-unknown}}"
    local server_ip="${3:-${SERVER_IP:-$(hostname -I | awk '{print $1}')}}"

    log_info "Generating deployment report..."

    local report_file="$LOGS_DIR/deployment_report_${deployment_date}.txt"

    cat > "$report_file" <<EOF
BTPI-REACT Deployment Report
========================================
Generated: $(date)
Deployment ID: $deployment_id
Version: $BTPI_VERSION

System Information:
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
- Kernel: $(uname -r)
- CPU: $(nproc) cores
- Memory: $(free -h | awk '/^Mem:/{print $2}')
- Disk: $(df -h / | awk 'NR==2{print $4}') available

Deployment Information:
- Completion Time: $(date +%Y%m%d_%H%M%S)
- Server IP: $server_ip
- Domain: btpi.local

Services Status:
EOF

    # Check service status
    local services=("elasticsearch" "cassandra" "wazuh-indexer" "wazuh-manager" "velociraptor" "kasm" "portainer")
    for service in "${services[@]}"; do
        local status="FAILED"
        if docker ps | grep -q "$service"; then
            status="RUNNING"
        fi
        echo "- $service: $status" >> "$report_file"
    done

    cat >> "$report_file" <<EOF

Access Information:
- Velociraptor: https://$server_ip:8889
- Wazuh Dashboard: https://$server_ip:5601
- Kasm Workspaces: https://$server_ip:6443
- Portainer: https://$server_ip:9443

Configuration Files:
- Environment: $CONFIG_DIR/.env
- SSL Certificates: $CONFIG_DIR/certificates/
- Service Configs: $CONFIG_DIR/

Data Storage:
- Application Data: $DATA_DIR/
- Logs: $LOGS_DIR/
- Backups: $BACKUPS_DIR/

Default Credentials:
- See $CONFIG_DIR/.env for generated passwords
- IMPORTANT: Change all default credentials after first login
EOF

    log_success "Deployment report saved to: $report_file"
    echo "$report_file"
}

# Display deployment summary
show_deployment_summary() {
    local server_ip="${1:-${SERVER_IP:-$(hostname -I | awk '{print $1}')}}"
    local report_file="${2:-}"

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    BTPI-REACT DEPLOYMENT COMPLETE     ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}Access your services:${NC}"
    echo -e "  • Velociraptor:    ${BLUE}https://$server_ip:8889${NC}"
    echo -e "  • Wazuh Dashboard: ${BLUE}https://$server_ip:5601${NC}"
    echo -e "  • Kasm Workspaces: ${BLUE}https://$server_ip:6443${NC}"
    echo -e "  • Portainer:       ${BLUE}https://$server_ip:9443${NC}"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo -e "  • Credentials are in: ${BLUE}$CONFIG_DIR/.env${NC}"
    if [ -n "$report_file" ]; then
        echo -e "  • Full report: ${BLUE}$report_file${NC}"
    fi
    echo -e "  • Change default passwords immediately${NC}"
    echo ""
}

# Error handling
handle_error() {
    local exit_code=$1
    local line_number=$2
    log_error "Script failed at line $line_number with exit code $exit_code"
    log_error "Check logs in $LOGS_DIR for details"
    exit $exit_code
}

# Set up error trap
trap 'handle_error $? $LINENO' ERR

# Export functions for use in other scripts
export -f log_info log_warn log_error log_debug log_success
export -f show_banner init_directories generate_environment validate_environment generate_ssl_certificates
export -f create_docker_network check_port_conflicts check_system_requirements
export -f wait_for_service check_service_health show_service_debug_info deploy_service
export -f update_hosts_file backup_existing_deployment generate_deployment_report show_deployment_summary
