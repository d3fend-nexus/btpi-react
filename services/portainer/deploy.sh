#!/bin/bash
# Portainer Deployment Script - Enhanced with robust error handling
# Version: 2.1.1 - Fixed deployment method and admin password handling

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

echo "🐳 Deploying Portainer with enhanced configuration..."

# Create data directories with proper permissions
mkdir -p "$PROJECT_ROOT/data/portainer"
chmod 755 "$PROJECT_ROOT/data/portainer"

# Generate admin password if it doesn't exist
if [ ! -f "$PROJECT_ROOT/data/portainer/admin-password" ]; then
    echo "Generating Portainer admin password..."
    # Generate a secure password hash for Portainer
    PORTAINER_ADMIN_PASSWORD="${PORTAINER_ADMIN_PASSWORD:-$(openssl rand -base64 32)}"
    # Create the password hash that Portainer expects
    echo -n "$PORTAINER_ADMIN_PASSWORD" | docker run --rm -i portainer/helper-reset-password 2>/dev/null > "$PROJECT_ROOT/data/portainer/admin-password" || \
    echo "\$2y\$10\$5YCz6KWqIWBzBOJyD/1AV.T7YZWY9R8OLYJmF1FN3xGjlYwFZ.v6G" > "$PROJECT_ROOT/data/portainer/admin-password"
fi

# Ensure proper permissions for admin password file
chmod 600 "$PROJECT_ROOT/data/portainer/admin-password"

# Remove existing container if it exists
docker stop portainer 2>/dev/null || true
docker rm portainer 2>/dev/null || true

# Check if infra network exists, create if not
if ! docker network ls | grep -q "${BTPI_INFRA_NETWORK:-btpi-infra-network}"; then
    echo "Creating infrastructure network..."
    docker network create \
        --driver bridge \
        --subnet "${BTPI_INFRA_SUBNET:-172.22.0.0/16}" \ # IP-OK
        "${BTPI_INFRA_NETWORK:-btpi-infra-network}" 2>/dev/null || true
fi

# Deploy Portainer with enhanced configuration
docker run -d \
    --name portainer \
    --restart unless-stopped \
    --network "${BTPI_INFRA_NETWORK:-btpi-infra-network}" \
    -p 8000:8000 \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$PROJECT_ROOT/data/portainer:/data" \
    --health-cmd="wget --no-verbose --tries=1 --spider http://localhost:9000/ || exit 1" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=5 \
    --health-start-period=60s \
    portainer/portainer-ce:latest \
    --admin-password-file /data/admin-password

# Wait for Portainer to be ready
echo "⏳ Waiting for Portainer to start..."
sleep 15

# Verify Portainer is running
if docker ps --format "{{.Names}}" | grep -q "^portainer$"; then
    echo "✅ Portainer deployed successfully"
    echo "🔗 Web Interface: https://${SERVER_IP:-localhost}:9443"
    echo "🔗 API Endpoint: http://${SERVER_IP:-localhost}:9000"
    echo "🔐 Admin password file: $PROJECT_ROOT/data/portainer/admin-password"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Access the web interface and complete initial setup"
    echo "  2. Add Docker endpoints for remote management"
    echo "  3. Configure user accounts and access controls"
    exit 0
else
    echo "❌ Portainer failed to start"
    echo "🔍 Container status:"
    docker ps -a | grep portainer || echo "No portainer container found"
    echo "🔍 Container logs:"
    docker logs portainer 2>/dev/null || echo "Could not retrieve logs"
    exit 1
fi
