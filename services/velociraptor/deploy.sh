#!/bin/bash
# Velociraptor Deployment Script - Enhanced with robust error handling
# Version: 2.1.1 - Fixed script execution and environment loading issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment with fallback
if [ -f "$PROJECT_ROOT/config/.env" ]; then
    source "$PROJECT_ROOT/config/.env"
else
    echo "Environment file not found. Run the main deployment script first."
    exit 1
fi

echo "🔍 Deploying Velociraptor with enhanced configuration..."

# Validate required commands
for cmd in docker openssl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Required command '$cmd' not found"
        exit 127
    fi
done

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

# Remove existing container if it exists
docker stop velociraptor 2>/dev/null || true
docker rm velociraptor 2>/dev/null || true

# Check if infra network exists, create if not
if ! docker network ls | grep -q "${BTPI_INFRA_NETWORK:-btpi-infra-network}"; then
    echo "Creating infrastructure network..."
    docker network create \
        --driver bridge \
        --subnet "${BTPI_INFRA_SUBNET:-172.22.0.0/16}" \ # IP-OK
        "${BTPI_INFRA_NETWORK:-btpi-infra-network}" 2>/dev/null || true
fi

# Deploy Velociraptor with enhanced configuration
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
    wlambert/velociraptor:latest \
    --config /etc/velociraptor/server.config.yaml \
    frontend -v

# Wait for Velociraptor to be ready
echo "⏳ Waiting for Velociraptor to start..."
sleep 20

# Verify Velociraptor is running
if docker ps --format "{{.Names}}" | grep -q "^velociraptor$"; then
    echo "✅ Velociraptor deployed successfully"
    echo "🔗 Web Interface: https://${SERVER_IP:-localhost}:8889"
    echo "🔗 Frontend API: https://${SERVER_IP:-localhost}:8000"
    echo "🔗 Admin API: https://${SERVER_IP:-localhost}:8001"
    echo "🔐 Username: admin"
    echo "🔐 Password: ${VELOCIRAPTOR_PASSWORD:-admin}"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Access the web interface and complete initial setup"
    echo "  2. Download and deploy agents to endpoints"
    echo "  3. Configure hunts and monitoring rules"
    exit 0
else
    echo "❌ Velociraptor failed to start"
    echo "🔍 Container status:"
    docker ps -a | grep velociraptor || echo "No velociraptor container found"
    echo "🔍 Container logs:"
    docker logs --tail=20 velociraptor 2>/dev/null || echo "Could not retrieve logs"
    exit 1
fi
