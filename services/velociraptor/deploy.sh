#!/bin/bash
# BTPI-REACT Velociraptor Deployment Script with ARM64 Support
# Purpose: Deploy Velociraptor with platform-aware binary selection
# Supports: x86_64/amd64 and ARM64/aarch64 architectures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source platform detection and common utilities
source "${PROJECT_ROOT}/scripts/core/detect-platform.sh" --source
source "${PROJECT_ROOT}/scripts/core/common-utils.sh"

# Load environment with fallback
if [ -f "$PROJECT_ROOT/config/.env" ]; then
    source "$PROJECT_ROOT/config/.env"
else
    log_error "Environment file not found. Run the main deployment script first." "VELOCIRAPTOR"
    exit 1
fi

log_info "Deploying Velociraptor with platform-aware configuration..." "VELOCIRAPTOR"

# Initialize platform detection
detect_architecture

log_info "Platform: $BTPI_PLATFORM, Architecture: $BTPI_ARCH" "VELOCIRAPTOR"

# Velociraptor binary URLs based on platform
declare -A VELOCIRAPTOR_URLS=(
    ["amd64"]="https://github.com/Velocidex/velociraptor/releases/download/v0.75/velociraptor-v0.75.2-linux-amd64"
    ["arm64"]="https://github.com/Velocidex/velociraptor/releases/download/v0.75/velociraptor-v0.75.2-linux-arm64"
)

# Get platform-specific Velociraptor binary
get_velociraptor_binary_url() {
    echo "${VELOCIRAPTOR_URLS[$BTPI_PLATFORM]}"
}

# Validate required commands
for cmd in docker openssl curl; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command '$cmd' not found" "VELOCIRAPTOR"
        exit 127
    fi
done

log_info "Using Velociraptor binary for $BTPI_PLATFORM: $(get_velociraptor_binary_url)" "VELOCIRAPTOR"

# Create data directories with proper permissions
mkdir -p "$PROJECT_ROOT/data/velociraptor/config"
mkdir -p "$PROJECT_ROOT/data/velociraptor/logs"
mkdir -p "$PROJECT_ROOT/data/velociraptor/datastore"
chmod -R 755 "$PROJECT_ROOT/data/velociraptor"

# Generate Velociraptor configuration if it doesn't exist
if [ ! -f "$PROJECT_ROOT/data/velociraptor/config/server.config.yaml" ]; then
    echo "Generating Velociraptor server configuration..."

    cat > "$PROJECT_ROOT/data/velociraptor/config/server.config.yaml" <<EOF
version:
  name: velociraptor
  version: "0.7.0"
  commit: "unknown"
  build_time: "unknown"

Client:
  server_urls:
    - https://${SERVER_IP:-localhost}:8000/
  ca_certificate: |
$(openssl x509 -in "$PROJECT_ROOT/config/certificates/ca.crt" | sed 's/^/    /')

GUI:
  bind_address: 0.0.0.0
  bind_port: 8889
  gw_certificate: |
$(openssl x509 -in "$PROJECT_ROOT/config/certificates/btpi.crt" | sed 's/^/    /')
  gw_private_key: |
$(openssl rsa -in "$PROJECT_ROOT/config/certificates/btpi.key" | sed 's/^/    /')
  public_url: https://${SERVER_IP:-localhost}:8889/
  internal_cidr:
    - 127.0.0.1/12
    - 192.168.0.0/16 # IP-OK
    - 10.0.0.0/8 # IP-OK
    - 172.16.0.0/12 # IP-OK

Frontend:
  bind_address: 0.0.0.0
  bind_port: 8000
  certificate: |
$(openssl x509 -in "$PROJECT_ROOT/config/certificates/btpi.crt" | sed 's/^/    /')
  private_key: |
$(openssl rsa -in "$PROJECT_ROOT/config/certificates/btpi.key" | sed 's/^/    /')
  public_url: https://${SERVER_IP:-localhost}:8000/

API:
  bind_address: 0.0.0.0
  bind_port: 8001

Datastore:
  implementation: FileBaseDataStore
  location: /opt/velociraptor/datastore
  filestore_directory: /opt/velociraptor/datastore

Logging:
  output_directory: /opt/velociraptor/logs
  separate_logs_per_component: true

Users:
  - name: admin
    password_hash: "\$2a\$10\$LYj.GV.LZwX.qxjqLYd.7eKDe6EKFZj4P2yj8K.7l8YhJk4PEH2XG"
    password_salt: "salt"

autocert_domain: ""
autocert_cert_cache: ""
EOF
fi

# Download platform-specific Velociraptor binary
download_velociraptor_binary() {
    local binary_url="$(get_velociraptor_binary_url)"
    local binary_path="/opt/velociraptor/bin/velociraptor"
    
    # Create directory for binary
    mkdir -p "/opt/velociraptor/bin"
    
    log_info "Downloading Velociraptor binary for $BTPI_PLATFORM..." "VELOCIRAPTOR"
    log_info "URL: $binary_url" "VELOCIRAPTOR"
    
    if [ ! -f "$binary_path" ]; then
        curl -L -o "$binary_path" "$binary_url"
        chmod +x "$binary_path"
        log_success "Velociraptor binary downloaded successfully" "VELOCIRAPTOR"
    else
        log_info "Velociraptor binary already exists" "VELOCIRAPTOR"
    fi
    
    # Verify binary works
    if "$binary_path" version >/dev/null 2>&1; then
        log_success "Velociraptor binary is functional" "VELOCIRAPTOR"
    else
        log_error "Downloaded Velociraptor binary is not functional" "VELOCIRAPTOR"
        return 1
    fi
}

# Deploy using native binary (recommended for ARM64)
deploy_velociraptor_native() {
    log_info "Deploying Velociraptor using native binary..." "VELOCIRAPTOR"
    
    # Download binary if needed
    download_velociraptor_binary
    
    local binary_path="/opt/velociraptor/bin/velociraptor"
    local config_path="$PROJECT_ROOT/data/velociraptor/config/server.config.yaml"
    
    # Stop existing service if running
    systemctl stop velociraptor 2>/dev/null || true
    
    # Create systemd service
    log_info "Creating systemd service..." "VELOCIRAPTOR"
    cat > /etc/systemd/system/velociraptor.service <<EOF
[Unit]
Description=Velociraptor DFIR Platform
After=network.target

[Service]
Type=simple
User=root
ExecStart=$binary_path --config $config_path frontend -v
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable velociraptor
    systemctl start velociraptor
    
    log_success "Velociraptor native service started" "VELOCIRAPTOR"
}

# Deploy using Docker (fallback for x86_64)
deploy_velociraptor_docker() {
    log_info "Deploying Velociraptor using Docker..." "VELOCIRAPTOR"
    
    # Remove existing container if it exists
    docker stop velociraptor 2>/dev/null || true
    docker rm velociraptor 2>/dev/null || true

    # Check if infra network exists, create if not
    if ! docker network ls | grep -q "${BTPI_INFRA_NETWORK:-btpi-infra-network}"; then
        log_info "Creating infrastructure network..." "VELOCIRAPTOR"
        docker network create \
            --driver bridge \
            --subnet "${BTPI_INFRA_SUBNET:-172.22.0.0/16}" \
            "${BTPI_INFRA_NETWORK:-btpi-infra-network}" 2>/dev/null || true
    fi

    # Deploy Velociraptor with enhanced configuration
    local docker_image="wlambert/velociraptor:latest"
    
    # Use platform-specific image if available
    if [ "$BTPI_PLATFORM" = "arm64" ]; then
        # For ARM64, prefer native deployment but try Docker as fallback
        log_warn "Docker image may not support ARM64 - consider using native deployment" "VELOCIRAPTOR"
        docker_image="--platform=linux/arm64 wlambert/velociraptor:latest"
    fi
    
    docker run -d \
        --name velociraptor \
        --restart unless-stopped \
        --network "${BTPI_INFRA_NETWORK:-btpi-infra-network}" \
        -p 8889:8889 \
        -p 8000:8000 \
        -p 8001:8001 \
        -e "VELOCIRAPTOR_USER=admin" \
        -e "VELOCIRAPTOR_PASSWORD=${VELOCIRAPTOR_PASSWORD:-admin}" \
        -v "$PROJECT_ROOT/data/velociraptor/config/server.config.yaml:/etc/velociraptor/server.config.yaml:ro" \
        -v "$PROJECT_ROOT/data/velociraptor/datastore:/opt/velociraptor/datastore" \
        -v "$PROJECT_ROOT/data/velociraptor/logs:/opt/velociraptor/logs" \
        --health-cmd="curl -k -f https://localhost:8889/ || exit 1" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-retries=5 \
        --health-start-period=60s \
        $docker_image \
        --config /etc/velociraptor/server.config.yaml \
        frontend -v
    
    log_success "Velociraptor Docker container started" "VELOCIRAPTOR"
}

# Choose deployment method based on platform
choose_deployment_method() {
    local deployment_method="${VELOCIRAPTOR_DEPLOYMENT_METHOD:-auto}"
    
    case "$deployment_method" in
        native)
            deploy_velociraptor_native
            ;;
        docker)
            deploy_velociraptor_docker
            ;;
        auto|*)
            # Auto-select based on platform
            if [ "$BTPI_PLATFORM" = "arm64" ]; then
                log_info "ARM64 platform detected - using native binary deployment" "VELOCIRAPTOR"
                deploy_velociraptor_native
            else
                log_info "AMD64 platform detected - using Docker deployment" "VELOCIRAPTOR"
                deploy_velociraptor_docker
            fi
            ;;
    esac
}

# Deploy Velociraptor
choose_deployment_method

# Wait for Velociraptor to be ready
log_info "Waiting for Velociraptor to start..." "VELOCIRAPTOR"
sleep 20

# Verify Velociraptor is running (check both systemd service and Docker container)
velociraptor_running=false

# Check systemd service
if systemctl is-active --quiet velociraptor 2>/dev/null; then
    log_success "Velociraptor systemd service is running" "VELOCIRAPTOR"
    velociraptor_running=true
fi

# Check Docker container
if docker ps --format "{{.Names}}" | grep -q "^velociraptor$"; then
    log_success "Velociraptor Docker container is running" "VELOCIRAPTOR"
    velociraptor_running=true
fi

# Final verification with port check
if nc -z localhost 8889 2>/dev/null; then
    log_success "Velociraptor web interface is accessible on port 8889" "VELOCIRAPTOR"
    velociraptor_running=true
fi

if [ "$velociraptor_running" = true ]; then
    log_success "Velociraptor deployed successfully!" "VELOCIRAPTOR"
    log_info "Web Interface: https://${SERVER_IP:-localhost}:8889" "VELOCIRAPTOR"
    log_info "Frontend API: https://${SERVER_IP:-localhost}:8000" "VELOCIRAPTOR"
    log_info "Admin API: https://${SERVER_IP:-localhost}:8001" "VELOCIRAPTOR"
    log_info "Username: admin" "VELOCIRAPTOR"
    log_info "Password: ${VELOCIRAPTOR_PASSWORD:-admin}" "VELOCIRAPTOR"
    echo ""
    log_info "Next steps:" "VELOCIRAPTOR"
    log_info "  1. Access the web interface and complete initial setup" "VELOCIRAPTOR"
    log_info "  2. Download and deploy agents to endpoints" "VELOCIRAPTOR"
    log_info "  3. Configure hunts and monitoring rules" "VELOCIRAPTOR"
    exit 0
else
    log_error "Velociraptor failed to start" "VELOCIRAPTOR"
    
    # Show systemd status if native deployment was used
    if systemctl list-units --type=service | grep -q velociraptor; then
        log_error "Systemd service status:" "VELOCIRAPTOR"
        systemctl status velociraptor --no-pager || true
    fi
    
    # Show Docker status if container deployment was used
    if docker ps -a --format "{{.Names}}" | grep -q velociraptor; then
        log_error "Container status:" "VELOCIRAPTOR"
        docker ps -a | grep velociraptor || true
        log_error "Container logs:" "VELOCIRAPTOR"
        docker logs --tail=20 velociraptor 2>/dev/null || true
    fi
    
    exit 1
fi
