#!/bin/bash
# BTPI-REACT Master Deployment Script
# Version: 2.0.0
# Purpose: Automated deployment of Blue Team Portable Infrastructure
# Author: BTPI-REACT Optimization Team

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
SERVICES_DIR="${SCRIPT_DIR}/services"
DATA_DIR="${SCRIPT_DIR}/data"
LOGS_DIR="${SCRIPT_DIR}/logs"
BACKUPS_DIR="${SCRIPT_DIR}/backups"

# Version information
BTPI_VERSION="2.0.0"
DEPLOYMENT_DATE=$(date +%Y%m%d_%H%M%S)
DEPLOYMENT_ID=$(uuidgen 2>/dev/null || openssl rand -hex 8)

# Service configuration with proper deployment order
declare -A SERVICES=(
    ["elasticsearch"]="database"
    ["cassandra"]="database"
    ["wazuh-indexer"]="database"
    ["wazuh-manager"]="security"
    ["velociraptor"]="security"
    ["thehive"]="security"
    ["cortex"]="security"
    ["nginx"]="frontend"
    ["kasm"]="infrastructure"
    ["portainer"]="infrastructure"
)

# Service dependencies mapping
declare -A SERVICE_DEPENDENCIES=(
    ["thehive"]="cassandra elasticsearch"
    ["cortex"]="cassandra elasticsearch"
    ["wazuh-manager"]="wazuh-indexer"
    ["wazuh-dashboard"]="wazuh-indexer wazuh-manager"
    ["nginx"]="thehive cortex wazuh-manager velociraptor"
)

# Required ports
declare -A SERVICE_PORTS=(
    ["elasticsearch"]="9200"
    ["cassandra"]="9042"
    ["wazuh-indexer"]="9200"
    ["wazuh-manager"]="1514,1515,55000"
    ["wazuh-dashboard"]="5601"
    ["velociraptor"]="8000,8889"
    ["thehive"]="9000"
    ["cortex"]="9001"
    ["nginx"]="80,443"
    ["kasm"]="6443"
    ["portainer"]="8000,9443"
)

# Error handling
handle_error() {
    local exit_code=$1
    local line_number=$2
    log_error "Script failed at line $line_number with exit code $exit_code"
    log_error "Deployment failed. Check logs in $LOGS_DIR for details."
    cleanup_on_failure
    exit $exit_code
}

trap 'handle_error $? $LINENO' ERR

# Logging functions
log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1" | tee -a "$LOGS_DIR/deployment.log"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARN]${NC} $1" | tee -a "$LOGS_DIR/deployment.log"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1" | tee -a "$LOGS_DIR/deployment.log"
}

log_debug() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG]${NC} $1" | tee -a "$LOGS_DIR/deployment.log"
}

log_success() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $1" | tee -a "$LOGS_DIR/deployment.log"
}

# Banner function
show_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
    ____  ______  ____  ____      ____  _________   ____________
   / __ )/_  __/ / __ \/  _/     / __ \/ ____/   | / ____/_  __/
  / __  | / /   / /_/ // /______/ /_/ / __/ / /| |/ /     / /   
 / /_/ / / /   / ____// /_____/ _, _/ /___/ ___ / /___  / /    
/_____/ /_/   /_/   /___/    /_/ |_/_____/_/  |_\____/ /_/     
                                                               
Blue Team Portable Infrastructure - Rapid Emergency Analysis & Counter-Threat
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Version: $BTPI_VERSION${NC}"
    echo -e "${GREEN}Deployment ID: $DEPLOYMENT_ID${NC}"
    echo -e "${GREEN}Date: $(date)${NC}"
    echo ""
}

# Pre-deployment checks
pre_deployment_checks() {
    log_info "Running comprehensive pre-deployment checks..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Check operating system
    if ! grep -q "Ubuntu 22.04\|Ubuntu 20.04\|Debian 11\|Debian 12" /etc/os-release; then
        log_warn "This script is optimized for Ubuntu 22.04/20.04 or Debian 11/12"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_info "Docker not found. Installing Docker..."
        install_docker
    else
        log_info "Docker found: $(docker --version)"
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed or not working"
        exit 1
    else
        log_info "Docker Compose found: $(docker compose version --short)"
    fi
    
    # Check system resources
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    local total_cpu=$(nproc)
    local available_disk=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    
    log_info "System Resources:"
    log_info "  CPU Cores: $total_cpu"
    log_info "  Memory: ${total_mem}GB"
    log_info "  Available Disk: ${available_disk}GB"
    
    if [ "$total_mem" -lt 16 ]; then
        log_warn "System has less than 16GB RAM. Performance may be impacted."
    fi
    
    if [ "$total_cpu" -lt 4 ]; then
        log_warn "System has less than 4 CPU cores. Performance may be impacted."
    fi
    
    if [ "$available_disk" -lt 100 ]; then
        log_error "Less than 100GB disk space available. Cannot proceed."
        exit 1
    fi
    
    # Check required ports
    check_port_conflicts
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "No internet connectivity. Cannot download required components."
        exit 1
    fi
    
    log_success "Pre-deployment checks completed successfully"
}

# Install Docker if not present
install_docker() {
    log_info "Installing Docker Engine..."
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Update package index
    apt-get update -y
    
    # Install prerequisites
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl enable docker
    systemctl start docker
    
    # Add current user to docker group if not root
    if [ "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
        log_info "Added $SUDO_USER to docker group"
    fi
    
    log_success "Docker installation completed"
}

# Check for port conflicts
check_port_conflicts() {
    log_info "Checking for port conflicts..."
    
    local conflicts=0
    for service in "${!SERVICE_PORTS[@]}"; do
        IFS=',' read -ra PORTS <<< "${SERVICE_PORTS[$service]}"
        for port in "${PORTS[@]}"; do
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                local process=$(lsof -Pi :$port -sTCP:LISTEN | tail -n 1 | awk '{print $1}')
                log_warn "Port $port is already in use by $process (required for $service)"
                ((conflicts++))
            fi
        done
    done
    
    if [ $conflicts -gt 0 ]; then
        log_error "Found $conflicts port conflicts. Please resolve before continuing."
        read -p "Attempt to stop conflicting services? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            resolve_port_conflicts
        else
            exit 1
        fi
    else
        log_success "No port conflicts detected"
    fi
}

# Resolve port conflicts
resolve_port_conflicts() {
    log_info "Attempting to resolve port conflicts..."
    
    # Common services that might conflict
    local services_to_stop=("apache2" "nginx" "httpd" "elasticsearch" "kibana")
    
    for service in "${services_to_stop[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_info "Stopping $service..."
            systemctl stop "$service" || true
            systemctl disable "$service" || true
        fi
    done
    
    # Kill processes on specific ports if needed
    for service in "${!SERVICE_PORTS[@]}"; do
        IFS=',' read -ra PORTS <<< "${SERVICE_PORTS[$service]}"
        for port in "${PORTS[@]}"; do
            if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                log_info "Killing process on port $port..."
                lsof -ti:$port | xargs kill -9 2>/dev/null || true
            fi
        done
    done
    
    sleep 5
    log_success "Port conflict resolution completed"
}

# Initialize directory structure
init_directories() {
    log_info "Initializing directory structure..."
    
    local dirs=("$CONFIG_DIR" "$SERVICES_DIR" "$DATA_DIR" "$LOGS_DIR" "$BACKUPS_DIR")
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done
    
    # Create service-specific directories
    for service in "${!SERVICES[@]}"; do
        mkdir -p "$DATA_DIR/$service"
        mkdir -p "$LOGS_DIR/$service"
        mkdir -p "$CONFIG_DIR/$service"
        mkdir -p "$SERVICES_DIR/$service"
    done
    
    # Create integration directory
    mkdir -p "$SERVICES_DIR/integrations"
    
    # Create tests directory
    mkdir -p "$SCRIPT_DIR/tests"
    
    # Create docs directory
    mkdir -p "$SCRIPT_DIR/docs"
    
    log_success "Directory structure initialized"
}

# Generate secrets and certificates
generate_secrets() {
    log_info "Generating secrets and certificates..."
    
    # Generate master environment file
    if [ ! -f "$CONFIG_DIR/.env" ]; then
        cat > "$CONFIG_DIR/.env" <<EOF
# BTPI-REACT Environment Configuration
# Generated: $(date)
# Deployment ID: $DEPLOYMENT_ID

# System Configuration
BTPI_VERSION=$BTPI_VERSION
DEPLOYMENT_ID=$DEPLOYMENT_ID
DEPLOYMENT_DATE=$DEPLOYMENT_DATE

# Database Passwords
ELASTIC_PASSWORD=$(openssl rand -base64 32)
CASSANDRA_PASSWORD=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Application Secrets
THEHIVE_SECRET=$(openssl rand -base64 64)
THEHIVE_ADMIN_PASSWORD=$(openssl rand -base64 16)
THEHIVE_KEYSTORE_PASSWORD=$(openssl rand -base64 16)
CORTEX_SECRET=$(openssl rand -base64 64)
CORTEX_ADMIN_PASSWORD=$(openssl rand -base64 16)
CORTEX_API_KEY=$(openssl rand -hex 32)
CORTEX_ATTACHMENT_PASSWORD=$(openssl rand -base64 32)
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
EOF
        chmod 600 "$CONFIG_DIR/.env"
        log_success "Environment configuration generated"
    else
        log_info "Environment configuration already exists"
    fi
    
    # Source the environment file
    source "$CONFIG_DIR/.env"
    
    # Generate SSL certificates
    if [ ! -f "$CONFIG_DIR/certificates/btpi.crt" ]; then
        log_info "Generating SSL certificates..."
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
IP.2 = $SERVER_IP
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

# Create Docker network
create_docker_network() {
    log_info "Creating Docker network..."
    
    if ! docker network ls | grep -q "$BTPI_NETWORK"; then
        docker network create \
            --driver bridge \
            --subnet=172.20.0.0/16 \
            --ip-range=172.20.240.0/20 \
            "$BTPI_NETWORK"
        log_success "Docker network '$BTPI_NETWORK' created"
    else
        log_info "Docker network '$BTPI_NETWORK' already exists"
    fi
}

# Deploy infrastructure services
deploy_infrastructure() {
    log_info "Deploying infrastructure services..."
    
    # Deploy databases first
    for service in "${!SERVICES[@]}"; do
        if [ "${SERVICES[$service]}" = "database" ]; then
            deploy_service "$service"
        fi
    done
    
    # Deploy infrastructure services
    for service in "${!SERVICES[@]}"; do
        if [ "${SERVICES[$service]}" = "infrastructure" ]; then
            deploy_service "$service"
        fi
    done
}

# Deploy security services
deploy_security_services() {
    log_info "Deploying security services..."
    
    for service in "${!SERVICES[@]}"; do
        if [ "${SERVICES[$service]}" = "security" ]; then
            deploy_service "$service"
        fi
    done
}

# Deploy frontend services
deploy_frontend() {
    log_info "Deploying frontend services..."
    
    for service in "${!SERVICES[@]}"; do
        if [ "${SERVICES[$service]}" = "frontend" ]; then
            deploy_service "$service"
        fi
    done
}

# Deploy individual service
deploy_service() {
    local service=$1
    log_info "Deploying $service..."
    
    # Check dependencies
    if [[ -v SERVICE_DEPENDENCIES[$service] ]]; then
        for dependency in ${SERVICE_DEPENDENCIES[$service]}; do
            if ! wait_for_service "$dependency" 60; then
                log_error "Dependency $dependency not ready for $service"
                return 1
            fi
        done
    fi
    
    # Deploy service using dedicated script if available
    if [ -f "$SERVICES_DIR/$service/deploy.sh" ]; then
        log_debug "Using dedicated deployment script for $service"
        bash "$SERVICES_DIR/$service/deploy.sh"
    else
        log_debug "Using legacy deployment method for $service"
        deploy_service_legacy "$service"
    fi
    
    # Wait for service to be ready
    if ! wait_for_service "$service" 300; then
        log_error "Service $service failed to become ready"
        return 1
    fi
    
    log_success "Service $service deployed successfully"
}

# Legacy service deployment for existing scripts
deploy_service_legacy() {
    local service=$1
    
    case $service in
        "kasm")
            if [ -f "$SCRIPT_DIR/kasm/build_kasm.sh" ]; then
                cd "$SCRIPT_DIR/kasm"
                bash build_kasm.sh
                cd "$SCRIPT_DIR"
            fi
            ;;
        "portainer")
            if [ -f "$SCRIPT_DIR/portainer/build_portainer.sh" ]; then
                cd "$SCRIPT_DIR/portainer"
                bash build_portainer.sh
                cd "$SCRIPT_DIR"
            fi
            ;;
        "wazuh-manager"|"wazuh-indexer")
            if [ -f "$SCRIPT_DIR/wazuh/build_wazuh.sh" ]; then
                cd "$SCRIPT_DIR/wazuh"
                bash build_wazuh.sh
                cd "$SCRIPT_DIR"
            fi
            ;;
        *)
            log_warn "No deployment method found for $service"
            ;;
    esac
}

# Wait for service readiness with enhanced dependency checking
wait_for_service() {
    local service=$1
    local max_wait=${2:-120}
    local attempt=1
    local wait_interval=10
    local max_attempts=$((max_wait / wait_interval))
    
    log_debug "Waiting for $service to be ready (max ${max_wait}s)..."
    
    while [ $attempt -le $max_attempts ]; do
        case $service in
            elasticsearch|wazuh-indexer)
                if curl -s -k "https://localhost:9200/_cluster/health" >/dev/null 2>&1; then
                    log_debug "$service is ready"
                    return 0
                fi
                ;;
            cassandra)
                if docker exec cassandra cqlsh -e "DESC KEYSPACES" >/dev/null 2>&1; then
                    log_debug "$service is ready"
                    return 0
                fi
                ;;
            wazuh-manager)
                if curl -s -k "https://localhost:55000/" >/dev/null 2>&1; then
                    log_debug "$service is ready"
                    return 0
                fi
                ;;
            velociraptor)
                if curl -s -k "https://localhost:8889/api/v1/GetVersion" >/dev/null 2>&1; then
                    log_debug "$service is ready"
                    return 0
                fi
                ;;
            thehive)
                if curl -s "http://localhost:9000/api/status" >/dev/null 2>&1; then
                    log_debug "$service is ready"
                    return 0
                fi
                ;;
            cortex)
                if curl -s "http://localhost:9001/api/status" >/dev/null 2>&1; then
                    log_debug "$service is ready"
                    return 0
                fi
                ;;
            kasm)
                if curl -s -k "https://localhost:6443/" >/dev/null 2>&1; then
                    log_debug "$service is ready"
                    return 0
                fi
                ;;
            portainer)
                if curl -s -k "https://localhost:9443/" >/dev/null 2>&1; then
                    log_debug "$service is ready"
                    return 0
                fi
                ;;
            *)
                # Generic container check
                if docker ps --format "table {{.Names}}" | grep -q "^$service$"; then
                    log_debug "$service container is running"
                    return 0
                fi
                ;;
        esac
        
        log_debug "Attempt $attempt/$max_attempts: $service not ready, waiting ${wait_interval}s..."
        sleep $wait_interval
        ((attempt++))
    done
    
    log_error "$service failed to become ready within ${max_wait}s"
    return 1
}

# Configure service integrations
configure_integrations() {
    log_info "Configuring service integrations..."
    
    # Configure TheHive-Cortex integration
    if [ -f "$SERVICES_DIR/integrations/thehive-cortex.sh" ]; then
        log_info "Configuring TheHive-Cortex integration..."
        bash "$SERVICES_DIR/integrations/thehive-cortex.sh"
    fi
    
    # Configure Wazuh integrations
    if [ -f "$SERVICES_DIR/integrations/wazuh-integrations.sh" ]; then
        log_info "Configuring Wazuh integrations..."
        bash "$SERVICES_DIR/integrations/wazuh-integrations.sh"
    fi
    
    # Configure Velociraptor integrations
    if [ -f "$SERVICES_DIR/integrations/velociraptor-integrations.sh" ]; then
        log_info "Configuring Velociraptor integrations..."
        bash "$SERVICES_DIR/integrations/velociraptor-integrations.sh"
    fi
    
    log_success "Service integrations configured"
}

# Run post-deployment tests
run_tests() {
    log_info "Running post-deployment tests..."
    
    if [ -f "$SCRIPT_DIR/tests/integration-tests.sh" ]; then
        bash "$SCRIPT_DIR/tests/integration-tests.sh"
        return $?
    else
        log_warn "Integration tests not found, running basic connectivity tests..."
        run_basic_tests
        return $?
    fi
}

# Basic connectivity tests
run_basic_tests() {
    local failed_tests=0
    
    # Test service connectivity
    for service in "${!SERVICES[@]}"; do
        if ! test_service_health "$service"; then
            log_error "$service health check failed"
            ((failed_tests++))
        else
            log_success "$service health check passed"
        fi
    done
    
    if [ $failed_tests -eq 0 ]; then
        log_success "All basic tests passed"
        return 0
    else
        log_error "$failed_tests basic tests failed"
        return 1
    fi
}

# Test service health
test_service_health() {
    local service=$1
    
    case $service in
        elasticsearch|wazuh-indexer)
            curl -s -k "https://localhost:9200/_cluster/health" | grep -q '"status":"green\|yellow"'
            ;;
        wazuh-manager)
            curl -s -k "https://localhost:55000/" >/dev/null 2>&1
            ;;
        velociraptor)
            curl -s -k "https://localhost:8889/" >/dev/null 2>&1
            ;;
        thehive)
            curl -s "http://localhost:9000/api/status" | grep -q '"versions"'
            ;;
        cortex)
            curl -s "http://localhost:9001/api/status" | grep -q '"versions"'
            ;;
        kasm)
            curl -s -k "https://localhost:6443/" >/dev/null 2>&1
            ;;
        portainer)
            curl -s -k "https://localhost:9443/" >/dev/null 2>&1
            ;;
        *)
            return 0
            ;;
    esac
}

# Generate deployment report
generate_report() {
    log_info "Generating deployment report..."
    
    local report_file="$LOGS_DIR/deployment_report_${DEPLOYMENT_DATE}.txt"
    
    cat > "$report_file" <<EOF
BTPI-REACT Deployment Report
========================================
Generated: $(date)
Deployment ID: $DEPLOYMENT_ID
Version: $BTPI_VERSION

System Information:
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
- Kernel: $(uname -r)
- CPU: $(nproc) cores
- Memory: $(free -h | awk '/^Mem:/{print $2}')
- Disk: $(df -h / | awk 'NR==2{print $4}') available

Deployment Information:
- Start Time: $DEPLOYMENT_DATE
- Completion Time: $(date +%Y%m%d_%H%M%S)
- Server IP: $SERVER_IP
- Domain: $DOMAIN_NAME

Services Deployed:
EOF
    
    for service in "${!SERVICES[@]}"; do
        local status="RUNNING"
        if ! docker ps | grep -q "$service"; then
            status="FAILED"
        fi
        echo "- $service: $status" >> "$report_file"
    done
    
    cat >> "$report_file" <<EOF

Access Information:
- Kasm Workspaces: https://$SERVER_IP:6443
- Portainer: https://$SERVER_IP:9443
- TheHive: http://$SERVER_IP:9000
- Cortex: http://$SERVER_IP:9001
- Velociraptor: https://$SERVER_IP:8889
- Wazuh Dashboard: https://$SERVER_IP:5601

Default Credentials:
- See $CONFIG_DIR/.env for generated passwords
- IMPORTANT: Change all default credentials after first login

Configuration Files:
- Environment: $CONFIG_DIR/.env
- SSL Certificates: $CONFIG_DIR/certificates/
- Service Configs: $CONFIG_DIR/

Data Storage:
- Application Data: $DATA_DIR/
- Logs: $LOGS_DIR/
- Backups: $BACKUPS_DIR/

Next Steps:
1. Access each service and complete initial setup
2. Configure user accounts and permissions
3. Import threat intelligence feeds
4. Configure alerting and notifications
5. Review security hardening checklist
6. Set up backup procedures
7. Configure monitoring and alerting

Support:
- Documentation: $SCRIPT_DIR/docs/
- Logs: $LOGS_DIR/
- Configuration: $CONFIG_DIR/

Security Notes:
- All services are configured with generated passwords
- SSL certificates are self-signed (replace with proper certs for production)
- Default firewall rules may need adjustment
- Regular security updates are recommended

EOF
    
    log_success "Deployment report saved to: $report_file"
    
    # Display summary
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    BTPI-REACT DEPLOYMENT COMPLETE     ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}Access your services:${NC}"
    echo -e "  • Kasm Workspaces: ${BLUE}https://$SERVER_IP:6443${NC}"
    echo -e "  • Portainer:       ${BLUE}https://$SERVER_IP:9443${NC}"
    echo -e "  • TheHive:         ${BLUE}http://$SERVER_IP:9000${NC}"
    echo -e "  • Cortex:          ${BLUE}http://$SERVER_IP:9001${NC}"
    echo -e "  • Velociraptor:    ${BLUE}https://$SERVER_IP:8889${NC}"
    echo -e "  • Wazuh Dashboard: ${BLUE}https://$SERVER_IP:5601${NC}"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo -e "  • Credentials are in: ${BLUE}$CONFIG_DIR/.env${NC}"
    echo -e "  • Full report: ${BLUE}$report_file${NC}"
    echo -e "  • Change default passwords immediately${NC}"
    echo ""
}

# Cleanup on failure
cleanup_on_failure() {
    log_error "Cleaning up failed deployment..."
    
    # Stop and remove containers that might be partially deployed
    local containers_to_remove=("elasticsearch" "cassandra" "wazuh-indexer" "wazuh-manager" "wazuh-dashboard" "velociraptor" "thehive" "cortex" "nginx")
    
    for container in "${containers_to_remove[@]}"; do
        if docker ps -a --format "table {{.Names}}" | grep -q "^$container$"; then
            log_info "Removing container: $container"
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        fi
    done
    
    # Remove Docker network if created
    if docker network ls | grep -q "$BTPI_NETWORK"; then
        log_info "Removing Docker network: $BTPI_NETWORK"
        docker network rm "$BTPI_NETWORK" 2>/dev/null || true
    fi
    
    log_info "Cleanup completed"
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

# System optimization
optimize_system() {
    log_info "Applying system optimizations..."
    
    # Increase file descriptor limits
    cat >> /etc/security/limits.conf <<EOF
# BTPI-REACT optimizations
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF
    
    # Optimize kernel parameters
    cat >> /etc/sysctl.conf <<EOF
# BTPI-REACT optimizations
vm.max_map_count=262144
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
fs.file-max=65536
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
EOF
    
    # Apply sysctl changes
    sysctl -p >/dev/null 2>&1 || true
    
    # Configure Docker daemon
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF
    
    # Restart Docker to apply changes
    systemctl restart docker
    
    log_success "System optimizations applied"
}

# Update /etc/hosts for local domain resolution
update_hosts_file() {
    log_info "Updating /etc/hosts for local domain resolution..."
    
    # Remove existing BTPI entries
    sed -i '/# BTPI-REACT entries/,/# End BTPI-REACT entries/d' /etc/hosts
    
    # Add new entries
    cat >> /etc/hosts <<EOF
# BTPI-REACT entries
$SERVER_IP btpi.local
$SERVER_IP wazuh.btpi.local
$SERVER_IP velociraptor.btpi.local
$SERVER_IP thehive.btpi.local
$SERVER_IP cortex.btpi.local
$SERVER_IP kasm.btpi.local
$SERVER_IP portainer.btpi.local
# End BTPI-REACT entries
EOF
    
    log_success "/etc/hosts updated"
}

# Install additional system packages
install_system_packages() {
    log_info "Installing additional system packages..."
    
    apt-get update -y
    apt-get install -y \
        htop \
        iotop \
        netstat-nat \
        tcpdump \
        nmap \
        jq \
        curl \
        wget \
        unzip \
        zip \
        git \
        vim \
        nano \
        tree \
        lsof \
        strace \
        ltrace \
        dnsutils \
        net-tools \
        iputils-ping \
        telnet \
        netcat-openbsd \
        openssl \
        ca-certificates \
        gnupg \
        software-properties-common \
        apt-transport-https \
        python3 \
        python3-pip \
        python3-venv \
        build-essential \
        make \
        gcc \
        g++ \
        libc6-dev \
        pkg-config
    
    # Install Docker Compose standalone (backup)
    if ! command -v docker-compose &> /dev/null; then
        log_info "Installing Docker Compose standalone..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    log_success "System packages installed"
}

# Main deployment function
main() {
    # Ensure logs directory exists before logging
    mkdir -p "$LOGS_DIR"
    
    # Show banner
    show_banner
    
    log_info "Starting BTPI-REACT deployment v$BTPI_VERSION..."
    log_info "Deployment ID: $DEPLOYMENT_ID"
    
    # Backup existing deployment if present
    backup_existing_deployment
    
    # Run pre-deployment checks
    pre_deployment_checks
    
    # Install additional system packages
    install_system_packages
    
    # Apply system optimizations
    optimize_system
    
    # Initialize environment
    init_directories
    generate_secrets
    update_hosts_file
    
    # Create Docker network
    create_docker_network
    
    # Deploy services in order
    log_info "Beginning service deployment phase..."
    deploy_infrastructure
    deploy_security_services
    deploy_frontend
    
    # Configure integrations
    log_info "Beginning integration configuration phase..."
    configure_integrations
    
    # Run tests
    log_info "Beginning testing phase..."
    if run_tests; then
        log_success "All tests passed - deployment completed successfully"
        generate_report
        
        # Final success message
        echo ""
        echo -e "${GREEN}🎉 BTPI-REACT deployment completed successfully! 🎉${NC}"
        echo -e "${GREEN}Your SOC-in-a-Box is ready for operation.${NC}"
        echo ""
        
        exit 0
    else
        log_error "Some tests failed - deployment completed with warnings"
        generate_report
        
        echo ""
        echo -e "${YELLOW}⚠️  BTPI-REACT deployment completed with warnings ⚠️${NC}"
        echo -e "${YELLOW}Check the logs and test results for details.${NC}"
        echo ""
        
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
