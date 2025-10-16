#!/bin/bash
# REMnux-Kasm Integration Deployment Script
# Purpose: Deploy and test REMnux integration with Kasm Workspaces

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/config"
DATA_DIR="${PROJECT_ROOT}/data"

# Import common utilities
source "${SCRIPT_DIR}/common-utils.sh" 2>/dev/null || {
    echo "Warning: common-utils.sh not found, defining minimal functions"
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warn() { echo "[WARN] $1"; }
}

# Configuration
KASM_PORT=6443
REMNUX_PORT=6901
BTPI_NETWORK="btpi-network"

# Function to create required directories
create_directories() {
    log_info "Creating required directories..."

    local dirs=(
        "${DATA_DIR}/remnux"
        "${DATA_DIR}/kasm/postgres"
        "${DATA_DIR}/kasm/redis"
        "${DATA_DIR}/kasm/api"
        "${DATA_DIR}/kasm/manager"
        "${DATA_DIR}/kasm/agent"
        "${DATA_DIR}/kasm/workspaces"
        "${DATA_DIR}/kasm/static"
        "${DATA_DIR}/kasm/downloads"
        "${CONFIG_DIR}/certificates"
        "${CONFIG_DIR}/kasm/workspaces"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    done

    # Set proper permissions
    chmod -R 755 "${DATA_DIR}/remnux"
    chmod -R 755 "${DATA_DIR}/kasm"

    log_success "Directories created successfully"
}

# Function to create Docker network
create_network() {
    log_info "Creating Docker network: $BTPI_NETWORK"

    if docker network ls | grep -q "$BTPI_NETWORK"; then
        log_info "Network $BTPI_NETWORK already exists"
    else
        docker network create "$BTPI_NETWORK"
        log_success "Network $BTPI_NETWORK created"
    fi
}

# Function to generate SSL certificates if needed
generate_certificates() {
    log_info "Checking SSL certificates..."

    if [[ ! -f "${CONFIG_DIR}/certificates/btpi.crt" ]]; then
        log_info "Generating SSL certificates..."

        # Get local IP address
        LOCAL_IP=$(hostname -I | awk '{print $1}')

        # Generate self-signed certificate
        openssl req -x509 -newkey rsa:4096 -keyout "${CONFIG_DIR}/certificates/btpi.key" \
            -out "${CONFIG_DIR}/certificates/btpi.crt" -days 365 -nodes \
            -subj "/CN=${LOCAL_IP}/O=BTPI-REACT/C=US"

        chmod 600 "${CONFIG_DIR}/certificates/btpi.key"
        chmod 644 "${CONFIG_DIR}/certificates/btpi.crt"

        log_success "SSL certificates generated"
    else
        log_info "SSL certificates already exist"
    fi
}

# Function to deploy containers using docker-compose
deploy_containers() {
    log_info "Deploying REMnux-Kasm integration containers..."

    cd "${CONFIG_DIR}"

    # Stop any existing containers
    log_info "Stopping existing containers..."
    docker-compose -f docker-compose-enhanced.yml down || true

    # Pull latest images
    log_info "Pulling container images..."
    docker-compose -f docker-compose-enhanced.yml pull

    # Start containers
    log_info "Starting containers..."
    docker-compose -f docker-compose-enhanced.yml up -d

    cd "${PROJECT_ROOT}"

    log_success "Containers deployed"
}

# Function to wait for services to be ready
wait_for_services() {
    log_info "Waiting for services to become ready..."

    local services=("kasm-db" "kasm-redis" "kasm-api" "kasm-manager" "kasm-proxy" "remnux-desktop")
    local max_wait=300
    local wait_interval=10

    for service in "${services[@]}"; do
        log_info "Waiting for $service..."
        local waited=0

        while [ $waited -lt $max_wait ]; do
            if docker ps --filter "name=${service}" --filter "status=running" | grep -q "${service}"; then
                log_success "$service is running"
                break
            fi

            log_info "Still waiting for $service... (${waited}s/${max_wait}s)"
            sleep $wait_interval
            waited=$((waited + wait_interval))
        done

        if [ $waited -ge $max_wait ]; then
            log_error "$service failed to start within ${max_wait}s"
            return 1
        fi
    done

    log_success "All services are running"
}

# Function to test connectivity
test_connectivity() {
    log_info "Testing service connectivity..."

    # Test Kasm Web Interface
    log_info "Testing Kasm web interface on port $KASM_PORT..."
    if curl -k -s --max-time 10 "https://localhost:${KASM_PORT}/" >/dev/null; then
        log_success "Kasm web interface is accessible"
    else
        log_warn "Kasm web interface test failed"
    fi

    # Test REMnux VNC Interface
    log_info "Testing REMnux VNC interface on port $REMNUX_PORT..."
    if curl -s --max-time 10 "http://localhost:${REMNUX_PORT}/" >/dev/null; then
        log_success "REMnux VNC interface is accessible"
    else
        log_warn "REMnux VNC interface test failed"
    fi

    # Test network connectivity between containers
    log_info "Testing inter-container connectivity..."
    if docker exec kasm-api ping -c 1 remnux-desktop >/dev/null 2>&1; then
        log_success "Inter-container connectivity verified"
    else
        log_warn "Inter-container connectivity test failed"
    fi
}

# Function to validate authentication
validate_authentication() {
    log_info "Validating authentication configuration..."

    # Check if Kasm is using the correct credentials
    local kasm_config=$(docker logs kasm-manager 2>&1 | grep -i "admin" || true)
    if [[ -n "$kasm_config" ]]; then
        log_info "Kasm admin configuration found in logs"
    fi

    # Test REMnux container environment
    log_info "Checking REMnux container environment..."
    if docker exec remnux-desktop printenv | grep -q "USER=btpi-nexus"; then
        log_success "REMnux container has correct user configuration"
    else
        log_warn "REMnux container user configuration may be incorrect"
    fi

    if docker exec remnux-desktop printenv | grep -q "PASSWORD=D3m0N0d3"; then
        log_success "REMnux container has password configured"
    else
        log_warn "REMnux container password configuration may be incorrect"
    fi
}

# Function to display access information
display_access_info() {
    local server_ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo "========================================="
    echo "    REMnux-Kasm Integration Deployed    "
    echo "========================================="
    echo ""
    echo "Access Information:"
    echo "  • Kasm Workspaces:  https://${server_ip}:${KASM_PORT}"
    echo "  • REMnux Desktop:   http://${server_ip}:${REMNUX_PORT}"
    echo ""
    echo "Authentication:"
    echo "  • Kasm Admin:       btpi-nexus@btpi.local / D3m0N0d3!()!@#"
    echo "  • REMnux VNC:       btpi-nexus / D3m0N0d3!()!@#"
    echo ""
    echo "Network Configuration:"
    echo "  • Docker Network:   ${BTPI_NETWORK}"
    echo "  • Host Gateway:     Available for REMnux container"
    echo ""
    echo "Data Directories:"
    echo "  • Kasm Data:        ${DATA_DIR}/kasm/"
    echo "  • REMnux Shared:    ${DATA_DIR}/remnux/"
    echo ""
    echo "Configuration Files:"
    echo "  • Docker Compose:   ${CONFIG_DIR}/docker-compose-enhanced.yml"
    echo "  • Nginx Config:     ${CONFIG_DIR}/nginx/kasm.conf"
    echo "  • REMnux Workspace: ${CONFIG_DIR}/kasm/workspaces/remnux-workspace.json"
    echo ""
    echo "Next Steps:"
    echo "  1. Access Kasm at https://${server_ip}:${KASM_PORT}"
    echo "  2. Login with btpi-nexus@btpi.local / D3m0N0d3!()!@#"
    echo "  3. Create REMnux workspace from admin panel"
    echo "  4. Access REMnux directly at http://${server_ip}:${REMNUX_PORT}"
    echo ""
    echo "========================================="
}

# Function to create documentation
create_documentation() {
    log_info "Creating deployment documentation..."

    local doc_file="${PROJECT_ROOT}/docs/REMNUX_KASM_INTEGRATION.md"
    mkdir -p "$(dirname "$doc_file")"

    cat > "$doc_file" <<EOF
# REMnux-Kasm Integration Guide

## Overview

This document describes the integration between REMnux and Kasm Workspaces in the BTPI-REACT platform.

## Architecture

- **Kasm Workspaces**: Provides web-based desktop management
- **REMnux Desktop**: Security analysis toolkit in containerized form
- **Integration**: REMnux runs as both standalone container and Kasm workspace

## Access Information

### Kasm Web Interface
- URL: \`https://[SERVER_IP]:6443\`
- Credentials: \`btpi-nexus@btpi.local\` / \`D3m0N0d3!()!@#\`

### REMnux Direct Access
- URL: \`http://[SERVER_IP]:6901\`
- Credentials: \`btpi-nexus\` / \`D3m0N0d3!()!@#\`

## Configuration Files

### Docker Compose
- Location: \`config/docker-compose-enhanced.yml\`
- Contains all service definitions including Kasm and REMnux

### Nginx Proxy
- Location: \`config/nginx/kasm.conf\`
- Handles SSL termination for Kasm

### REMnux Workspace Definition
- Location: \`config/kasm/workspaces/remnux-workspace.json\`
- Defines REMnux as a Kasm workspace

## Network Configuration

- Docker Network: \`btpi-network\`
- Host Gateway: Configured for REMnux container
- SSL Certificates: Auto-generated in \`config/certificates/\`

## Troubleshooting

### Common Issues

1. **Port Conflicts**: Ensure ports 6443 and 6901 are available
2. **SSL Certificates**: Check \`config/certificates/\` for valid certs
3. **Container Connectivity**: Verify \`btpi-network\` exists
4. **Authentication**: Confirm base64 encoded passwords are correct

### Log Locations

- Kasm API: \`data/kasm/api/\`
- Kasm Manager: \`data/kasm/manager/\`
- Container logs: \`docker logs [container-name]\`

### Commands

\`\`\`bash
# Check service status
docker-compose -f config/docker-compose-enhanced.yml ps

# View logs
docker logs kasm-manager
docker logs remnux-desktop

# Restart services
docker-compose -f config/docker-compose-enhanced.yml restart

# Stop all services
docker-compose -f config/docker-compose-enhanced.yml down
\`\`\`

## Security Considerations

- Change default passwords after deployment
- Use proper SSL certificates in production
- Restrict network access as needed
- Monitor container logs for security events

EOF

    log_success "Documentation created: $doc_file"
}

# Main deployment function
main() {
    log_info "Starting REMnux-Kasm integration deployment..."

    # Pre-deployment setup
    create_directories
    create_network
    generate_certificates

    # Deploy containers
    deploy_containers

    # Wait for services to be ready
    wait_for_services

    # Run tests
    test_connectivity
    validate_authentication

    # Create documentation
    create_documentation

    # Display access information
    display_access_info

    log_success "REMnux-Kasm integration deployment completed!"
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
