#!/bin/bash
# BTPI-REACT Infrastructure-First Deployment Orchestrator
# Purpose: Deploy Portainer and Kasm first, then use these to deploy Velociraptor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PROJECT_ROOT}/scripts/common-utils.sh"

# Configuration
export SERVER_IP="${SERVER_IP:-$(ip route get 1 | awk '{print $7; exit}')}"
export BTPI_NETWORK="${BTPI_NETWORK:-btpi-network}"

# Service deployment status
PORTAINER_DEPLOYED=false
KASM_DEPLOYED=false
VELOCIRAPTOR_DEPLOYED=false

# Create summary function
display_deployment_summary() {
    log_info "BTPI-REACT Infrastructure-First Deployment Summary" "ORCHESTRATOR"
    echo "=================================================================="
    echo ""
    echo "Deployment Status:"
    echo "  Portainer:     $([ "$PORTAINER_DEPLOYED" = true ] && echo "✓ DEPLOYED" || echo "✗ FAILED")"
    echo "  Kasm:          $([ "$KASM_DEPLOYED" = true ] && echo "✓ DEPLOYED" || echo "✗ FAILED")"
    echo "  Velociraptor:  $([ "$VELOCIRAPTOR_DEPLOYED" = true ] && echo "✓ DEPLOYED" || echo "✗ FAILED")"
    echo ""
    echo "Service Endpoints:"
    if [ "$PORTAINER_DEPLOYED" = true ]; then
        echo "  Portainer HTTP:   http://${SERVER_IP}:9100"
        echo "  Portainer HTTPS:  https://${SERVER_IP}:9443"
    fi
    if [ "$KASM_DEPLOYED" = true ]; then
        echo "  Kasm HTTPS:       https://${SERVER_IP}:6443"
        echo "  Kasm HTTP:        http://${SERVER_IP}:6080"
    fi
    if [ "$VELOCIRAPTOR_DEPLOYED" = true ]; then
        echo "  Velociraptor GUI: https://${SERVER_IP}:8889"
        echo "  Velociraptor API: https://${SERVER_IP}:8001"
        echo "  Velociraptor CLI: https://${SERVER_IP}:8000"
    fi
    echo ""
    echo "Credentials Files:"
    if [ "$PORTAINER_DEPLOYED" = true ]; then
        echo "  Portainer:     ${PROJECT_ROOT}/data/portainer/credentials.env"
    fi
    if [ "$KASM_DEPLOYED" = true ]; then
        echo "  Kasm:          ${PROJECT_ROOT}/data/kasm/credentials.env"
    fi
    if [ "$VELOCIRAPTOR_DEPLOYED" = true ]; then
        echo "  Velociraptor:  ${PROJECT_ROOT}/data/velociraptor/credentials.env"
    fi
    echo ""
    echo "=================================================================="
}

# Ensure Docker network exists
ensure_network() {
    log_info "Ensuring Docker network exists..." "ORCHESTRATOR"

    if ! docker network ls | grep -q "$BTPI_NETWORK"; then
        log_info "Creating Docker network: $BTPI_NETWORK" "ORCHESTRATOR"
        docker network create "$BTPI_NETWORK"
    else
        log_info "Docker network already exists: $BTPI_NETWORK" "ORCHESTRATOR"
    fi

    log_success "Docker network ready" "ORCHESTRATOR"
}

# Deploy Phase 1: Infrastructure Management (Portainer + Kasm)
deploy_infrastructure_management() {
    log_info "Phase 1: Deploying Infrastructure Management Services" "ORCHESTRATOR"
    echo "=================================================================="

    # Deploy Portainer first
    log_info "Deploying Portainer (Container Management)..." "ORCHESTRATOR"
    if bash "${PROJECT_ROOT}/services/portainer/deploy.sh"; then
        PORTAINER_DEPLOYED=true
        log_success "Portainer deployment completed" "ORCHESTRATOR"
    else
        log_error "Portainer deployment failed" "ORCHESTRATOR"
        return 1
    fi

    echo "Waiting 30 seconds for Portainer to stabilize..." && sleep 30

    # Deploy Kasm second
    log_info "Deploying Kasm Workspaces (Browser-based Access)..." "ORCHESTRATOR"
    if bash "${PROJECT_ROOT}/services/kasm/deploy.sh"; then
        KASM_DEPLOYED=true
        log_success "Kasm deployment completed" "ORCHESTRATOR"
    else
        log_error "Kasm deployment failed" "ORCHESTRATOR"
        return 1
    fi

    log_success "Phase 1 completed successfully" "ORCHESTRATOR"
}

# Deploy Phase 2: Security Analysis Services (Velociraptor)
deploy_security_services() {
    log_info "Phase 2: Deploying Security Analysis Services" "ORCHESTRATOR"
    echo "=================================================================="

    # Deploy Velociraptor
    log_info "Deploying Velociraptor (Endpoint Monitoring)..." "ORCHESTRATOR"
    if bash "${PROJECT_ROOT}/services/velociraptor/deploy.sh"; then
        VELOCIRAPTOR_DEPLOYED=true
        log_success "Velociraptor deployment completed" "ORCHESTRATOR"
    else
        log_error "Velociraptor deployment failed" "ORCHESTRATOR"
    fi

    log_success "Phase 2 completed" "ORCHESTRATOR"
}

# Verify all services are running
verify_services() {
    log_info "Verifying deployed services..." "ORCHESTRATOR"

    local services_ok=true

    # Check Portainer
    if [ "$PORTAINER_DEPLOYED" = true ]; then
        if docker ps --filter "name=portainer" | grep -q "portainer"; then
            log_success "Portainer is running" "ORCHESTRATOR"
        else
            log_error "Portainer is not running" "ORCHESTRATOR"
            services_ok=false
        fi
    fi

    # Check Kasm
    if [ "$KASM_DEPLOYED" = true ]; then
        if docker ps --filter "name=kasm" | grep -q "kasm"; then
            log_success "Kasm services are running" "ORCHESTRATOR"
        else
            log_warn "Kasm services may not be running" "ORCHESTRATOR"
        fi
    fi


    # Check Velociraptor
    if [ "$VELOCIRAPTOR_DEPLOYED" = true ]; then
        if docker ps --filter "name=velociraptor" | grep -q "velociraptor"; then
            log_success "Velociraptor is running" "ORCHESTRATOR"
        else
            log_error "Velociraptor is not running" "ORCHESTRATOR"
            services_ok=false
        fi
    fi

    if [ "$services_ok" = true ]; then
        log_success "All deployed services are running" "ORCHESTRATOR"
    else
        log_warn "Some services may have issues - check individual logs" "ORCHESTRATOR"
    fi
}

# Create post-deployment management scripts
create_management_scripts() {
    log_info "Creating post-deployment management scripts..." "ORCHESTRATOR"

    local scripts_dir="${PROJECT_ROOT}/data/management"
    mkdir -p "$scripts_dir"

    # Create service status script
    cat > "${scripts_dir}/check-all-services.sh" <<EOF
#!/bin/bash
# Check status of all BTPI-REACT services

echo "BTPI-REACT Service Status"
echo "========================"
echo ""

echo "Docker Network:"
docker network ls | grep btpi-network || echo "❌ BTPI Network not found"
echo ""

echo "Running Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(portainer|kasm|velociraptor)" || echo "❌ No services running"
echo ""

echo "Service Endpoints:"
echo "  Portainer:     http://${SERVER_IP}:9100 (HTTP) | https://${SERVER_IP}:9443 (HTTPS)"
echo "  Kasm:          http://${SERVER_IP}:6080 (HTTP) | https://${SERVER_IP}:6443 (HTTPS)"
echo "  Velociraptor:  https://${SERVER_IP}:8889 (GUI) | https://${SERVER_IP}:8001 (API)"
echo ""
EOF

    # Create restart all script
    cat > "${scripts_dir}/restart-all-services.sh" <<EOF
#!/bin/bash
# Restart all BTPI-REACT services

echo "Restarting all BTPI-REACT services..."

services=("portainer" "kasm-proxy" "kasm-api" "kasm-manager" "kasm-agent" "kasm-db" "kasm-redis" "velociraptor")

for service in "\${services[@]}"; do
    if docker ps -a --format "{{.Names}}" | grep -q "^\$service\$"; then
        echo "Restarting \$service..."
        docker restart "\$service" || echo "Failed to restart \$service"
    fi
done

echo "Restart completed"
EOF

    # Create stop all script
    cat > "${scripts_dir}/stop-all-services.sh" <<EOF
#!/bin/bash
# Stop all BTPI-REACT services

echo "Stopping all BTPI-REACT services..."

services=("velociraptor" "kasm-agent" "kasm-manager" "kasm-api" "kasm-proxy" "kasm-redis" "kasm-db" "portainer")

for service in "\${services[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "^\$service\$"; then
        echo "Stopping \$service..."
        docker stop "\$service" || echo "Failed to stop \$service"
    fi
done

echo "All services stopped"
EOF

    # Make scripts executable
    chmod +x "${scripts_dir}"/*.sh

    log_success "Management scripts created in ${scripts_dir}/" "ORCHESTRATOR"
}

# Main deployment function
main() {
    log_info "Starting BTPI-REACT Infrastructure-First Deployment" "ORCHESTRATOR"
    echo "=================================================================="
    echo "This deployment strategy:"
    echo "1. Deploys Portainer (container management) first"
    echo "2. Deploys Kasm (browser-based workspace access) second"
    echo "3. Uses these tools to deploy and manage Velociraptor"
    echo "=================================================================="

    # Ensure prerequisites
    ensure_network

    # Phase 1: Deploy infrastructure management
    if ! deploy_infrastructure_management; then
        log_error "Phase 1 failed - cannot continue with security services" "ORCHESTRATOR"
        display_deployment_summary
        exit 1
    fi

    # Brief pause between phases
    echo "Pausing 30 seconds between deployment phases..." && sleep 30

    # Phase 2: Deploy security services
    deploy_security_services

    # Final verification
    verify_services

    # Create management tools
    create_management_scripts

    # Display final summary
    display_deployment_summary

    # Final status
    if [ "$PORTAINER_DEPLOYED" = true ] && [ "$KASM_DEPLOYED" = true ]; then
        log_success "BTPI-REACT Infrastructure-First Deployment completed successfully" "ORCHESTRATOR"
        echo ""
        echo "Next Steps:"
        echo "1. Access Portainer at https://${SERVER_IP}:9443 to manage containers"
        echo "2. Access Kasm at https://${SERVER_IP}:6443 for browser-based access"
        echo "3. Use management scripts in ${PROJECT_ROOT}/data/management/"
        echo "4. Check service credentials in individual data directories"
        echo ""
    else
        log_error "Critical infrastructure services failed - deployment incomplete" "ORCHESTRATOR"
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
