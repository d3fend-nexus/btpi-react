#!/bin/bash
# Google Rapid Response (GRR) Installation Script for Docker-in-Docker environment

set -e

echo "Installing Google Rapid Response (GRR)..."

# Check if Docker and docker-compose are available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not available"
    exit 1
fi

# Set working directory
WORK_DIR="/opt/grr"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Install git if not available
if ! command -v git &> /dev/null; then
    apk add --no-cache git
fi

# Clone GRR repository
echo "Cloning GRR repository..."
git clone https://github.com/google/grr .

# Initialize certificates
echo "Initializing certificates..."
if [ -f "./docker_config_files/init_certs.sh" ]; then
    bash ./docker_config_files/init_certs.sh
fi

# Modify compose.yaml to use port 8500 instead of 8000 (to avoid conflicts)
if [ -f "compose.yaml" ]; then
    echo "Configuring GRR ports..."
    sed -i 's/ports:\s*-\s*"8000:8000"/ports:\n      - "8500:8000"/; s/expose:\s*-\s*"8000"/expose:\n      - "8500"/' compose.yaml
fi

# Start GRR using docker-compose
echo "Starting GRR services..."
docker compose up -d

echo "GRR installation completed"
echo "Access GRR at http://localhost:8500"
