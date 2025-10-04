#!/bin/bash
# BTPI Network Setup Script
# This script creates all required Docker networks for BTPI-REACT deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🌐 Setting up BTPI Docker Networks..."

# Load environment variables
if [ -f "$PROJECT_ROOT/config/.env" ]; then
    source "$PROJECT_ROOT/config/.env"
    echo "✅ Loaded environment configuration"
else
    echo "❌ Environment file not found at $PROJECT_ROOT/config/.env"
    exit 1
fi

# Function to create network if it doesn't exist
create_network() {
    local network_name="$1"
    local subnet="$2"
    local description="$3"

    if docker network ls --format "{{.Name}}" | grep -q "^${network_name}$"; then
        echo "✅ Network ${network_name} already exists"
    else
        echo "🔧 Creating network: ${network_name} (${subnet}) - ${description}"
        docker network create --driver bridge --subnet="${subnet}" "${network_name}"
        echo "✅ Created network: ${network_name}"
    fi
}

# Create all networks as defined in .env
create_network "${BTPI_CORE_NETWORK}" "${BTPI_CORE_SUBNET}" "Core Network (Elasticsearch, Cassandra)"
create_network "${BTPI_WAZUH_NETWORK}" "${BTPI_WAZUH_SUBNET}" "Wazuh Network (Wazuh-indexer, Wazuh Manager, Dashboard)"
create_network "${BTPI_INFRA_NETWORK}" "${BTPI_INFRA_SUBNET}" "Infrastructure Network (Velociraptor, Portainer, GRR)"
create_network "${BTPI_PROXY_NETWORK}" "${BTPI_PROXY_SUBNET}" "Proxy Network (NGINX, external access)"

# Verify legacy network exists for backward compatibility
create_network "${BTPI_NETWORK}" "172.20.0.0/16" "Legacy Network (KASM, backward compatibility)" # IP-OK

echo ""
echo "🌐 Network Setup Summary:"
echo "========================"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep -E "(NAME|btpi-)"

echo ""
echo "✅ BTPI Network setup completed successfully!"
echo "🔗 All services can now connect to their designated networks"
echo ""
echo "Network Usage:"
echo "- Core Network (${BTPI_CORE_NETWORK}): Elasticsearch, Cassandra"
echo "- Wazuh Network (${BTPI_WAZUH_NETWORK}): Wazuh-indexer, Wazuh Manager, Dashboard"
echo "- Infrastructure Network (${BTPI_INFRA_NETWORK}): Velociraptor, Portainer, GRR"
echo "- Proxy Network (${BTPI_PROXY_NETWORK}): NGINX, external access"
echo "- Legacy Network (${BTPI_NETWORK}): KASM services, backward compatibility"
