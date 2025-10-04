#!/bin/bash
# BTPI-REACT Network Isolation Setup
# Purpose: Create isolated networks for service roles to prevent conflicts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] [NETWORK-SETUP]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] [NETWORK-SETUP ERROR]\033[0m $1"
}

log_warning() {
    echo -e "\033[0;33m[$(date +'%Y-%m-%d %H:%M:%S')] [NETWORK-SETUP WARNING]\033[0m $1"
}

# Network configuration
declare -A BTPI_NETWORKS=(
    ["btpi-core-network"]="172.24.0.0/16" # IP-OK
    ["btpi-wazuh-network"]="172.21.0.0/16" # IP-OK
    ["btpi-infra-network"]="172.22.0.0/16" # IP-OK
    ["btpi-proxy-network"]="172.23.0.0/16" # IP-OK
)

# Service to network mapping
declare -A SERVICE_NETWORKS=(
    # Core Analytics Network
    ["elasticsearch"]="btpi-core-network"
    ["cassandra"]="btpi-core-network"

    # Wazuh Security Network
    ["wazuh-indexer"]="btpi-wazuh-network"
    ["wazuh-manager"]="btpi-wazuh-network"
    ["wazuh-dashboard"]="btpi-wazuh-network"

    # Infrastructure Network
    ["velociraptor"]="btpi-infra-network"
    ["portainer"]="btpi-infra-network"
    ["grr"]="btpi-infra-network"

    # Proxy Network (multi-network)
    ["nginx-proxy"]="btpi-proxy-network"
    ["kasm"]="btpi-infra-network"
)

# Port ranges for networks
declare -A NETWORK_PORT_RANGES=(
    ["btpi-core-network"]="9000-9299"
    ["btpi-wazuh-network"]="9300-9599"
    ["btpi-infra-network"]="9600-9899"
    ["btpi-proxy-network"]="8000-8999"
)

# Create isolated Docker networks
create_isolated_networks() {
    log_info "Creating isolated Docker networks..."

    for network in "${!BTPI_NETWORKS[@]}"; do
        subnet="${BTPI_NETWORKS[$network]}"

        # Check if network already exists
        if docker network ls | grep -q "$network"; then
            log_warning "Network $network already exists, removing..."
            # Get containers using this network
            containers=$(docker network inspect "$network" -f '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")
            if [[ -n "$containers" ]]; then
                log_warning "Disconnecting containers from $network: $containers"
                for container in $containers; do
                    docker network disconnect "$network" "$container" 2>/dev/null || true
                done
            fi
            docker network rm "$network" 2>/dev/null || true
        fi

        # Create new network with specific subnet
        log_info "Creating network: $network ($subnet)"
        docker network create \
            --driver bridge \
            --subnet "$subnet" \
            --opt com.docker.network.bridge.name="br-$(echo $network | cut -c1-10)" \
            --opt com.docker.network.bridge.enable_icc=true \
            --opt com.docker.network.bridge.enable_ip_masquerade=true \
            --opt com.docker.network.driver.mtu=1500 \
            --label btpi.network.role="$(echo $network | cut -d'-' -f2)" \
            --label btpi.network.version="2.0" \
            "$network"

        log_info "✓ Network $network created successfully"
    done
}

# Update .env file with new network configuration
update_env_config() {
    log_info "Updating environment configuration..."

    ENV_FILE="$PROJECT_ROOT/config/.env"

    # Backup current .env
    cp "$ENV_FILE" "$ENV_FILE.backup.$(date +%s)"

    # Add network configuration
    cat >> "$ENV_FILE" <<EOF

# Network Isolation Configuration
# Generated: $(date)

# Core Network (Elasticsearch, Cassandra)
BTPI_CORE_NETWORK=btpi-core-network
BTPI_CORE_SUBNET=172.24.0.0/16 # IP-OK

# Wazuh Network (Wazuh-indexer, Wazuh Manager, Wazuh Dashboard)
BTPI_WAZUH_NETWORK=btpi-wazuh-network
BTPI_WAZUH_SUBNET=172.21.0.0/16 # IP-OK

# Infrastructure Network (Velociraptor, Portainer, GRR)
BTPI_INFRA_NETWORK=btpi-infra-network
BTPI_INFRA_SUBNET=172.22.0.0/16 # IP-OK

# Proxy Network (NGINX, external access)
BTPI_PROXY_NETWORK=btpi-proxy-network
BTPI_PROXY_SUBNET=172.23.0.0/16 # IP-OK

# Legacy network (for backward compatibility)
BTPI_NETWORK=btpi-network

# Port range assignments
CORE_PORT_RANGE=9000-9299
WAZUH_PORT_RANGE=9300-9599
INFRA_PORT_RANGE=9600-9899
PROXY_PORT_RANGE=8000-8999
EOF

    log_info "✓ Environment configuration updated"
}

# Create network management utilities
create_network_utilities() {
    log_info "Creating network management utilities..."

    # Network inspection script
    cat > "$PROJECT_ROOT/scripts/inspect-networks.sh" <<'EOF'
#!/bin/bash
# BTPI-REACT Network Inspection Utility

echo "=== BTPI-REACT Network Status ==="
echo

for network in btpi-core-network btpi-wazuh-network btpi-infra-network btpi-proxy-network; do
    if docker network ls | grep -q "$network"; then
        echo "📡 Network: $network"
        echo "   Subnet: $(docker network inspect $network -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}')"
        echo "   Gateway: $(docker network inspect $network -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')"

        # List containers
        containers=$(docker network inspect $network -f '{{range $id,$container := .Containers}}{{$container.Name}} {{end}}' 2>/dev/null)
        if [[ -n "$containers" && "$containers" != " " ]]; then
            echo "   Containers: $containers"
        else
            echo "   Containers: (none)"
        fi

        # Show container IPs
        docker network inspect $network -f '{{range $id,$container := .Containers}}{{$container.Name}}: {{$container.IPv4Address}} {{end}}' 2>/dev/null | while read line; do
            if [[ -n "$line" && "$line" != ": " ]]; then
                echo "     $line"
            fi
        done
        echo
    else
        echo "❌ Network: $network (not found)"
        echo
    fi
done

echo "=== Port Allocations ==="
echo "Core Services (9000-9299): Elasticsearch:9200, Available:9000-9001"
echo "Wazuh Services (9300-9599): Wazuh-indexer:9300, Wazuh-manager:9400, Wazuh-dashboard:9500"
echo "Infrastructure (9600-9899): Velociraptor:9600, Portainer:9700, GRR:9800"
echo "Proxy Services (8000-8999): NGINX:8080, External access gateway"
echo

echo "=== Network Connectivity Test ==="
for network in btpi-core-network btpi-wazuh-network btpi-infra-network btpi-proxy-network; do
    if docker network ls | grep -q "$network"; then
        gateway=$(docker network inspect $network -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
        if ping -c 1 -W 1 "$gateway" >/dev/null 2>&1; then
            echo "✅ $network gateway ($gateway) reachable"
        else
            echo "❌ $network gateway ($gateway) unreachable"
        fi
    fi
done
EOF

    chmod +x "$PROJECT_ROOT/scripts/inspect-networks.sh"

    # Network cleanup script
    cat > "$PROJECT_ROOT/scripts/cleanup-networks.sh" <<'EOF'
#!/bin/bash
# BTPI-REACT Network Cleanup Utility

echo "=== BTPI-REACT Network Cleanup ==="
echo

networks=(btpi-core-network btpi-wazuh-network btpi-infra-network btpi-proxy-network btpi-network)

for network in "${networks[@]}"; do
    if docker network ls | grep -q "$network"; then
        echo "🔄 Cleaning up network: $network"

        # Get connected containers
        containers=$(docker network inspect "$network" -f '{{range $id,$container := .Containers}}{{$container.Name}} {{end}}' 2>/dev/null)

        if [[ -n "$containers" && "$containers" != " " ]]; then
            echo "   Disconnecting containers: $containers"
            for container in $containers; do
                echo "   - Disconnecting $container"
                docker network disconnect "$network" "$container" 2>/dev/null || true
            done
        fi

        echo "   - Removing network $network"
        docker network rm "$network" 2>/dev/null || true
        echo "   ✅ Network $network removed"
    else
        echo "   ℹ️  Network $network not found"
    fi
    echo
done

echo "=== Cleanup Complete ==="
EOF

    chmod +x "$PROJECT_ROOT/scripts/cleanup-networks.sh"

    log_info "✓ Network utilities created"
}

# Validate network creation
validate_networks() {
    log_info "Validating network creation..."

    for network in "${!BTPI_NETWORKS[@]}"; do
        if docker network ls | grep -q "$network"; then
            subnet=$(docker network inspect "$network" -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
            gateway=$(docker network inspect "$network" -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')

            log_info "✓ Network $network: $subnet (Gateway: $gateway)"

            # Test gateway connectivity
            if ping -c 1 -W 1 "$gateway" >/dev/null 2>&1; then
                log_info "✓ Gateway $gateway reachable"
            else
                log_warning "⚠ Gateway $gateway unreachable (this may be normal)"
            fi
        else
            log_error "✗ Network $network not found"
            return 1
        fi
    done

    log_info "✓ All networks validated successfully"
}

# Main setup function
main() {
    log_info "Starting BTPI-REACT Network Isolation Setup..."

    # Stop existing services that might be running
    log_info "Stopping existing services..."
    docker stop wazuh-indexer elasticsearch 2>/dev/null || true

    # Create isolated networks
    create_isolated_networks

    # Update environment configuration
    update_env_config

    # Create management utilities
    create_network_utilities

    # Validate setup
    validate_networks

    log_info "Network isolation setup completed successfully!"
    log_info ""
    log_info "Next Steps:"
    log_info "1. Update individual service deployment scripts"
    log_info "2. Restart services with new network configuration"
    log_info "3. Test service connectivity within networks"
    log_info ""
    log_info "Utilities:"
    log_info "- Inspect networks: ./scripts/inspect-networks.sh"
    log_info "- Cleanup networks: ./scripts/cleanup-networks.sh"
}

# Handle script interruption
trap 'log_error "Setup interrupted"; exit 1' INT TERM

main "$@"
