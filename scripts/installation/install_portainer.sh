#!/bin/bash
# Portainer Installation Script for Docker-in-Docker environment

set -e

echo "Installing Portainer CE..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not available"
    exit 1
fi

# Stop and remove existing Portainer container if it exists
docker stop portainer 2>/dev/null || true
docker rm portainer 2>/dev/null || true

# Create Portainer data volume
docker volume create portainer_data 2>/dev/null || true

# Run Portainer container
docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:2.21.0

echo "Portainer installation completed"
echo "Access Portainer at https://localhost:9443"
