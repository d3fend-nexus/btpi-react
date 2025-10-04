#!/bin/bash
# Wazuh Installation Script for Docker-in-Docker environment

set -e

echo "Installing Wazuh..."

# Check if Docker and docker-compose are available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not available"
    exit 1
fi

# Set working directory
WORK_DIR="/opt/wazuh"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Install git if not available
if ! command -v git &> /dev/null; then
    apk add --no-cache git
fi

# Clone Wazuh Docker repository
echo "Cloning Wazuh Docker repository..."
git clone https://github.com/wazuh/wazuh-docker.git -b v4.9.2 .

# Generate indexer certificates
echo "Generating indexer certificates..."
if [ -f "generate-indexer-certs.yml" ]; then
    docker-compose -f generate-indexer-certs.yml run --rm generator
fi

# Start Wazuh services
echo "Starting Wazuh services..."
docker compose up -d

echo "Wazuh installation completed"
echo "Access Wazuh Dashboard at https://localhost:443"
echo "Default credentials: admin/SecretPassword (change after first login)"
