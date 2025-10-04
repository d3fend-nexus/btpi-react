#!/bin/bash
# Wazuh Manager Deployment Script - Enhanced with SSL Certificate Support
# Version: 2.1.1 - Fixed SSL certificate mounting

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

echo "🛡️ Deploying Wazuh Manager with SSL support..."

# Generate SSL certificates if they don't exist
if [ ! -f "$PROJECT_ROOT/config/certificates/root-ca.pem" ]; then
    echo "Generating missing SSL certificates..."
    bash "$PROJECT_ROOT/config/certificates/generate-wazuh-certs.sh"
fi

# Create data directories with proper permissions
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/api"
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/etc"
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/logs"
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/queue"
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/var"
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/ssl"

# Copy SSL certificates to wazuh-manager ssl directory
cp "$PROJECT_ROOT/config/certificates/root-ca.pem" "$PROJECT_ROOT/data/wazuh-manager/ssl/"
cp "$PROJECT_ROOT/config/certificates/filebeat.pem" "$PROJECT_ROOT/data/wazuh-manager/ssl/"
cp "$PROJECT_ROOT/config/certificates/filebeat-key.pem" "$PROJECT_ROOT/data/wazuh-manager/ssl/"

# Set proper permissions
chmod -R 755 "$PROJECT_ROOT/data/wazuh-manager"
chmod 644 "$PROJECT_ROOT/data/wazuh-manager/ssl"/*.pem
chmod 600 "$PROJECT_ROOT/data/wazuh-manager/ssl"/*-key.pem

# Remove existing container if it exists
docker stop wazuh-manager 2>/dev/null || true
docker rm wazuh-manager 2>/dev/null || true

# Deploy Wazuh Manager with proper SSL mounting
docker run -d \
    --name wazuh-manager \
    --restart unless-stopped \
    --network "${BTPI_WAZUH_NETWORK:-btpi-wazuh-network}" \
    -p 1514:1514/udp \
    -p 1515:1515 \
    -p 514:514/udp \
    -p 55000:55000 \
    -e "WAZUH_MANAGER_API_USER=wazuh" \
    -e "WAZUH_MANAGER_API_PASSWORD=${WAZUH_API_PASSWORD}" \
    -e "FILEBEAT_SSL_VERIFICATION_MODE=none" \
    -v "$PROJECT_ROOT/data/wazuh-manager/api:/var/ossec/api" \
    -v "$PROJECT_ROOT/data/wazuh-manager/etc:/var/ossec/etc" \
    -v "$PROJECT_ROOT/data/wazuh-manager/logs:/var/ossec/logs" \
    -v "$PROJECT_ROOT/data/wazuh-manager/queue:/var/ossec/queue" \
    -v "$PROJECT_ROOT/data/wazuh-manager/var:/var/ossec/var" \
    -v "$PROJECT_ROOT/data/wazuh-manager/ssl/root-ca.pem:/etc/ssl/root-ca.pem:ro" \
    -v "$PROJECT_ROOT/data/wazuh-manager/ssl/filebeat.pem:/etc/ssl/filebeat.pem:ro" \
    -v "$PROJECT_ROOT/data/wazuh-manager/ssl/filebeat-key.pem:/etc/ssl/filebeat-key.pem:ro" \
    --health-cmd="curl -f http://localhost:55000 || exit 1" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=5 \
    wazuh/wazuh-manager:4.9.0

echo "✅ Wazuh Manager deployed successfully on btpi-wazuh-network"
echo "🔗 Available at: https://localhost:55000"
echo "🔐 API User: wazuh"
echo "🔐 API Password: ${WAZUH_API_PASSWORD}"
