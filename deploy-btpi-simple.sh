#!/bin/bash
# BTPI-REACT Simplified Deployment Script
# Version: 2.0.1
# Purpose: Simplified deployment without Docker daemon configuration issues

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
BTPI_VERSION="2.0.1"
DEPLOYMENT_DATE=$(date +%Y%m%d_%H%M%S)
DEPLOYMENT_ID=$(uuidgen 2>/dev/null || openssl rand -hex 8)

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
    echo -e "${GREEN}Version: $BTPI_VERSION (Simplified)${NC}"
    echo -e "${GREEN}Deployment ID: $DEPLOYMENT_ID${NC}"
    echo -e "${GREEN}Date: $(date)${NC}"
    echo ""
}

# Pre-deployment checks
pre_deployment_checks() {
    log_info "Running simplified pre-deployment checks..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
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
    
    if [ "$available_disk" -lt 100 ]; then
        log_error "Less than 100GB disk space available. Cannot proceed."
        exit 1
    fi
    
    log_success "Pre-deployment checks completed successfully"
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
    local services=("elasticsearch" "cassandra" "thehive" "cortex" "velociraptor" "wazuh")
    for service in "${services[@]}"; do
        mkdir -p "$DATA_DIR/$service"
        mkdir -p "$LOGS_DIR/$service"
        mkdir -p "$CONFIG_DIR/$service"
    done
    
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

# Deploy existing services using legacy scripts
deploy_existing_services() {
    log_info "Deploying existing services..."
    
    # Deploy Kasm if available
    if [ -f "$SCRIPT_DIR/kasm/build_kasm.sh" ]; then
        log_info "Deploying Kasm Workspaces..."
        cd "$SCRIPT_DIR/kasm"
        bash build_kasm.sh || log_warn "Kasm deployment failed"
        cd "$SCRIPT_DIR"
    fi
    
    # Deploy Portainer if available
    if [ -f "$SCRIPT_DIR/portainer/build_portainer.sh" ]; then
        log_info "Deploying Portainer..."
        cd "$SCRIPT_DIR/portainer"
        bash build_portainer.sh || log_warn "Portainer deployment failed"
        cd "$SCRIPT_DIR"
    fi
    
    # Deploy Wazuh if available
    if [ -f "$SCRIPT_DIR/wazuh/build_wazuh.sh" ]; then
        log_info "Deploying Wazuh..."
        cd "$SCRIPT_DIR/wazuh"
        bash build_wazuh.sh || log_warn "Wazuh deployment failed"
        cd "$SCRIPT_DIR"
    fi
}

# Deploy new optimized services
deploy_optimized_services() {
    log_info "Deploying optimized security services..."
    
    # Deploy TheHive if script exists
    if [ -f "$SERVICES_DIR/thehive/deploy.sh" ]; then
        log_info "Deploying TheHive..."
        bash "$SERVICES_DIR/thehive/deploy.sh" || log_warn "TheHive deployment failed"
    fi
    
    # Deploy Cortex if script exists
    if [ -f "$SERVICES_DIR/cortex/deploy.sh" ]; then
        log_info "Deploying Cortex..."
        bash "$SERVICES_DIR/cortex/deploy.sh" || log_warn "Cortex deployment failed"
    fi
    
    # Deploy Velociraptor if script exists
    if [ -f "$SERVICES_DIR/velociraptor/deploy.sh" ]; then
        log_info "Deploying Velociraptor..."
        bash "$SERVICES_DIR/velociraptor/deploy.sh" || log_warn "Velociraptor deployment failed"
    fi
}

# Configure integrations
configure_integrations() {
    log_info "Configuring service integrations..."
    
    # Configure TheHive-Cortex integration if script exists
    if [ -f "$SERVICES_DIR/integrations/thehive-cortex.sh" ]; then
        log_info "Configuring TheHive-Cortex integration..."
        bash "$SERVICES_DIR/integrations/thehive-cortex.sh" || log_warn "Integration configuration failed"
    fi
    
    log_success "Service integrations configured"
}

# Run basic tests
run_basic_tests() {
    log_info "Running basic connectivity tests..."
    
    local failed_tests=0
    local services=("9000:TheHive" "9001:Cortex" "8889:Velociraptor" "6443:Kasm" "9443:Portainer")
    
    for service_port in "${services[@]}"; do
        local port=$(echo $service_port | cut -d: -f1)
        local name=$(echo $service_port | cut -d: -f2)
        
        if nc -z localhost "$port" 2>/dev/null; then
            log_success "$name connectivity test passed"
        else
            log_warn "$name connectivity test failed (port $port)"
            ((failed_tests++))
        fi
    done
    
    if [ $failed_tests -eq 0 ]; then
        log_success "All connectivity tests passed"
        return 0
    else
        log_warn "$failed_tests connectivity tests failed"
        return 1
    fi
}

# Generate deployment report
generate_report() {
    log_info "Generating deployment report..."
    
    local report_file="$LOGS_DIR/deployment_report_${DEPLOYMENT_DATE}.txt"
    
    cat > "$report_file" <<EOF
BTPI-REACT Simplified Deployment Report
=======================================
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

Access Information:
- TheHive: http://$SERVER_IP:9000
- Cortex: http://$SERVER_IP:9001
- Velociraptor: https://$SERVER_IP:8889
- Kasm Workspaces: https://$SERVER_IP:6443
- Portainer: https://$SERVER_IP:9443

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

EOF
    
    log_success "Deployment report saved to: $report_file"
    
    # Display summary
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    BTPI-REACT DEPLOYMENT COMPLETE     ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}Access your services:${NC}"
    echo -e "  • TheHive:         ${BLUE}http://$SERVER_IP:9000${NC}"
    echo -e "  • Cortex:          ${BLUE}http://$SERVER_IP:9001${NC}"
    echo -e "  • Velociraptor:    ${BLUE}https://$SERVER_IP:8889${NC}"
    echo -e "  • Kasm Workspaces: ${BLUE}https://$SERVER_IP:6443${NC}"
    echo -e "  • Portainer:       ${BLUE}https://$SERVER_IP:9443${NC}"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo -e "  • Credentials are in: ${BLUE}$CONFIG_DIR/.env${NC}"
    echo -e "  • Full report: ${BLUE}$report_file${NC}"
    echo -e "  • Change default passwords immediately${NC}"
    echo ""
}

# Main deployment function
main() {
    # Ensure logs directory exists before logging
    mkdir -p "$LOGS_DIR"
    
    # Show banner
    show_banner
    
    log_info "Starting BTPI-REACT simplified deployment v$BTPI_VERSION..."
    log_info "Deployment ID: $DEPLOYMENT_ID"
    
    # Run pre-deployment checks
    pre_deployment_checks
    
    # Initialize environment
    init_directories
    generate_secrets
    
    # Create Docker network
    create_docker_network
    
    # Deploy services
    log_info "Beginning service deployment phase..."
    deploy_existing_services
    deploy_optimized_services
    
    # Configure integrations
    log_info "Beginning integration configuration phase..."
    configure_integrations
    
    # Run tests
    log_info "Beginning testing phase..."
    if run_basic_tests; then
        log_success "Basic tests passed - deployment completed successfully"
        generate_report
        
        # Final success message
        echo ""
        echo -e "${GREEN}🎉 BTPI-REACT deployment completed successfully! 🎉${NC}"
        echo -e "${GREEN}Your SOC-in-a-Box is ready for operation.${NC}"
        echo ""
        
        exit 0
    else
        log_warn "Some tests failed - deployment completed with warnings"
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
