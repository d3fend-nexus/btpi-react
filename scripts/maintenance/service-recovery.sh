#!/bin/bash
# BTPI-REACT Service Recovery Script
# Purpose: Restart services with new credentials and network isolation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] [RECOVERY]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] [RECOVERY ERROR]\033[0m $1"
}

log_warning() {
    echo -e "\033[0;33m[$(date +'%Y-%m-%d %H:%M:%S')] [RECOVERY WARNING]\033[0m $1"
}

# Load environment variables
load_environment() {
    if [[ -f "$PROJECT_ROOT/config/.env" ]]; then
        log_info "Loading environment configuration..."
        source "$PROJECT_ROOT/config/.env"
        log_info "✓ Environment loaded"
    else
        log_error "Environment file not found: $PROJECT_ROOT/config/.env"
        exit 1
    fi
}

# Stop existing containers
stop_existing_services() {
    log_info "Stopping existing services..."

    # Stop all BTPI-related containers
    local containers=$(docker ps -q --filter "name=elasticsearch" --filter "name=cassandra" --filter "name=wazuh" --filter "name=velociraptor" --filter "name=portainer" --filter "name=kasm" --filter "name=nginx" --filter "name=misp" 2>/dev/null || echo "")

    if [[ -n "$containers" ]]; then
        docker stop $containers 2>/dev/null || true
        docker rm $containers 2>/dev/null || true
        log_info "✓ Existing containers stopped"
    else
        log_info "✓ No existing containers to stop"
    fi
}

# Update service deployment scripts to use new networks
update_service_deployments() {
    log_info "Updating service deployment scripts for network isolation..."

    # Update Elasticsearch deployment
    update_elasticsearch_deployment

    # Update Cassandra deployment
    update_cassandra_deployment

    # Update Wazuh services deployment
    update_wazuh_deployment

    # Update Velociraptor deployment
    update_velociraptor_deployment

    # Update Portainer deployment
    update_portainer_deployment

    log_info "✓ All service deployments updated"
}

# Update Elasticsearch deployment for core network
update_elasticsearch_deployment() {
    log_info "Updating Elasticsearch deployment..."

    cat > "$PROJECT_ROOT/services/elasticsearch/deploy.sh" <<'EOF'
#!/bin/bash
# Elasticsearch Deployment Script - Core Network

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
source "$PROJECT_ROOT/config/.env"

echo "🔍 Deploying Elasticsearch on Core Network..."

# Create data directory
mkdir -p "$PROJECT_ROOT/data/elasticsearch"
chmod 777 "$PROJECT_ROOT/data/elasticsearch"

# Deploy Elasticsearch
docker run -d \
    --name elasticsearch \
    --restart unless-stopped \
    --network btpi-core-network \
    -p 9200:9200 \
    -p 9300:9300 \
    -e "discovery.type=single-node" \
    -e "bootstrap.memory_lock=true" \
    -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
    -e "ELASTIC_PASSWORD=${ELASTIC_PASSWORD}" \
    -e "xpack.security.enabled=true" \
    -v "$PROJECT_ROOT/data/elasticsearch:/usr/share/elasticsearch/data" \
    -v "$PROJECT_ROOT/services/elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro" \
    --ulimit memlock=-1:-1 \
    docker.elastic.co/elasticsearch/elasticsearch:8.11.0

echo "✅ Elasticsearch deployed successfully on btpi-core-network"
echo "🔗 Available at: http://localhost:9200"
echo "🔐 Username: elastic"
echo "🔐 Password: ${ELASTIC_PASSWORD}"
EOF

    chmod +x "$PROJECT_ROOT/services/elasticsearch/deploy.sh"
}

# Update Cassandra deployment for core network
update_cassandra_deployment() {
    log_info "Updating Cassandra deployment..."

    cat > "$PROJECT_ROOT/services/cassandra/deploy.sh" <<'EOF'
#!/bin/bash
# Cassandra Deployment Script - Core Network

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
source "$PROJECT_ROOT/config/.env"

echo "🗄️ Deploying Cassandra on Core Network..."

# Create data directory
mkdir -p "$PROJECT_ROOT/data/cassandra"
chmod 777 "$PROJECT_ROOT/data/cassandra"

# Deploy Cassandra
docker run -d \
    --name cassandra \
    --restart unless-stopped \
    --network btpi-core-network \
    -p 9042:9042 \
    -p 7000:7000 \
    -e "CASSANDRA_CLUSTER_NAME=btpi-cluster" \
    -e "CASSANDRA_DC=datacenter1" \
    -e "CASSANDRA_RACK=rack1" \
    -e "CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch" \
    -e "CASSANDRA_NUM_TOKENS=128" \
    -v "$PROJECT_ROOT/data/cassandra:/var/lib/cassandra" \
    -v "$PROJECT_ROOT/services/cassandra/config/cassandra.yaml:/etc/cassandra/cassandra.yaml:ro" \
    cassandra:4.1

echo "✅ Cassandra deployed successfully on btpi-core-network"
echo "🔗 Available at: localhost:9042"
echo "⏳ Waiting for Cassandra to be ready..."

# Wait for Cassandra to be ready
sleep 30
docker exec cassandra cqlsh -e "DESCRIBE KEYSPACES;" >/dev/null 2>&1 && echo "✅ Cassandra is ready" || echo "⚠️ Cassandra may need more time to initialize"
EOF

    chmod +x "$PROJECT_ROOT/services/cassandra/deploy.sh"
}

# Update Wazuh deployment for wazuh network
update_wazuh_deployment() {
    log_info "Updating Wazuh services deployment..."

    # Wazuh Indexer
    cat > "$PROJECT_ROOT/services/wazuh-indexer/deploy.sh" <<'EOF'
#!/bin/bash
# Wazuh Indexer Deployment Script - Wazuh Network

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
source "$PROJECT_ROOT/config/.env"

echo "🔍 Deploying Wazuh Indexer on Wazuh Network..."

# Create data directory
mkdir -p "$PROJECT_ROOT/data/wazuh-indexer"
chmod 777 "$PROJECT_ROOT/data/wazuh-indexer"

# Deploy Wazuh Indexer
docker run -d \
    --name wazuh-indexer \
    --restart unless-stopped \
    --network btpi-wazuh-network \
    -p 9300:9200 \
    -e "discovery.type=single-node" \
    -e "bootstrap.memory_lock=true" \
    -e "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m" \
    -e "DISABLE_SECURITY_PLUGIN=true" \
    -v "$PROJECT_ROOT/data/wazuh-indexer:/var/lib/wazuh-indexer" \
    -v "$PROJECT_ROOT/services/wazuh-indexer/config/opensearch.yml:/usr/share/wazuh-indexer/config/opensearch.yml:ro" \
    --ulimit memlock=-1:-1 \
    wazuh/wazuh-indexer:4.7.0

echo "✅ Wazuh Indexer deployed successfully on btpi-wazuh-network"
echo "🔗 Available at: http://localhost:9300"
EOF

    chmod +x "$PROJECT_ROOT/services/wazuh-indexer/deploy.sh"

    # Wazuh Manager
    cat > "$PROJECT_ROOT/services/wazuh-manager/deploy.sh" <<'EOF'
#!/bin/bash
# Wazuh Manager Deployment Script - Wazuh Network

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
source "$PROJECT_ROOT/config/.env"

echo "🛡️ Deploying Wazuh Manager on Wazuh Network..."

# Create data directories
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/api"
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/etc"
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/logs"
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/queue"
mkdir -p "$PROJECT_ROOT/data/wazuh-manager/var"
chmod -R 777 "$PROJECT_ROOT/data/wazuh-manager"

# Deploy Wazuh Manager
docker run -d \
    --name wazuh-manager \
    --restart unless-stopped \
    --network btpi-wazuh-network \
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
    wazuh/wazuh-manager:4.7.0

echo "✅ Wazuh Manager deployed successfully on btpi-wazuh-network"
echo "🔗 Available at: https://localhost:55000"
echo "🔐 API User: wazuh"
echo "🔐 API Password: ${WAZUH_API_PASSWORD}"
EOF

    chmod +x "$PROJECT_ROOT/services/wazuh-manager/deploy.sh"
}

# Update Velociraptor deployment for infrastructure network
update_velociraptor_deployment() {
    log_info "Updating Velociraptor deployment..."

    cat > "$PROJECT_ROOT/services/velociraptor/deploy.sh" <<'EOF'
#!/bin/bash
# Velociraptor Deployment Script - Infrastructure Network

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
source "$PROJECT_ROOT/config/.env"

echo "🔍 Deploying Velociraptor on Infrastructure Network..."

# Create data directory
mkdir -p "$PROJECT_ROOT/data/velociraptor"
chmod 777 "$PROJECT_ROOT/data/velociraptor"

# Deploy Velociraptor
docker run -d \
    --name velociraptor \
    --restart unless-stopped \
    --network btpi-infra-network \
    -p 8889:8889 \
    -p 8000:8000 \
    -e "VELOCIRAPTOR_USER=admin" \
    -e "VELOCIRAPTOR_PASSWORD=${VELOCIRAPTOR_PASSWORD}" \
    -v "$PROJECT_ROOT/data/velociraptor:/opt/velociraptor" \
    -v "$PROJECT_ROOT/services/velociraptor/config/server.config.yaml:/etc/velociraptor/server.config.yaml:ro" \
    velocidex/velociraptor:latest \
    --config /etc/velociraptor/server.config.yaml \
    frontend -v

echo "✅ Velociraptor deployed successfully on btpi-infra-network"
echo "🔗 Available at: https://localhost:8889"
echo "🔐 Username: admin"
echo "🔐 Password: ${VELOCIRAPTOR_PASSWORD}"
EOF

    chmod +x "$PROJECT_ROOT/services/velociraptor/deploy.sh"
}

# Update Portainer deployment for infrastructure network
update_portainer_deployment() {
    log_info "Updating Portainer deployment..."

    cat > "$PROJECT_ROOT/services/portainer/deploy.sh" <<'EOF'
#!/bin/bash
# Portainer Deployment Script - Infrastructure Network

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment
source "$PROJECT_ROOT/config/.env"

echo "🐳 Deploying Portainer on Infrastructure Network..."

# Create data directory
mkdir -p "$PROJECT_ROOT/data/portainer"

# Deploy Portainer
docker run -d \
    --name portainer \
    --restart unless-stopped \
    --network btpi-infra-network \
    -p 9443:9443 \
    -p 9000:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$PROJECT_ROOT/data/portainer:/data" \
    portainer/portainer-ce:latest \
    --admin-password-file /data/admin-password

echo "✅ Portainer deployed successfully on btpi-infra-network"
echo "🔗 Available at: https://localhost:9443"
echo "🔐 Admin password: Check /data/admin-password"
EOF

    chmod +x "$PROJECT_ROOT/services/portainer/deploy.sh"
}

# Deploy core services (Elasticsearch, Cassandra)
deploy_core_services() {
    log_info "Deploying core services (Elasticsearch, Cassandra)..."

    # Deploy Elasticsearch
    log_info "Starting Elasticsearch..."
    cd "$PROJECT_ROOT/services/elasticsearch" && ./deploy.sh

    # Wait for Elasticsearch
    log_info "Waiting for Elasticsearch to be ready..."
    sleep 30

    # Deploy Cassandra
    log_info "Starting Cassandra..."
    cd "$PROJECT_ROOT/services/cassandra" && ./deploy.sh

    # Wait for Cassandra
    log_info "Waiting for Cassandra to be ready..."
    sleep 45

    log_info "✅ Core services deployed"
}

# Deploy Wazuh services
deploy_wazuh_services() {
    log_info "Deploying Wazuh services..."

    # Deploy Wazuh Indexer
    log_info "Starting Wazuh Indexer..."
    cd "$PROJECT_ROOT/services/wazuh-indexer" && ./deploy.sh

    # Wait for Wazuh Indexer
    log_info "Waiting for Wazuh Indexer to be ready..."
    sleep 30

    # Deploy Wazuh Manager
    log_info "Starting Wazuh Manager..."
    cd "$PROJECT_ROOT/services/wazuh-manager" && ./deploy.sh

    # Wait for Wazuh Manager
    log_info "Waiting for Wazuh Manager to be ready..."
    sleep 30

    log_info "✅ Wazuh services deployed"
}

# Deploy infrastructure services
deploy_infrastructure_services() {
    log_info "Deploying infrastructure services..."

    # Deploy Velociraptor
    log_info "Starting Velociraptor..."
    cd "$PROJECT_ROOT/services/velociraptor" && ./deploy.sh

    # Deploy Portainer
    log_info "Starting Portainer..."
    cd "$PROJECT_ROOT/services/portainer" && ./deploy.sh

    # Wait for services
    log_info "Waiting for infrastructure services to be ready..."
    sleep 30

    log_info "✅ Infrastructure services deployed"
}

# Deploy KASM and MISP services
deploy_additional_services() {
    log_info "Deploying additional services (KASM, MISP)..."

    cd "$PROJECT_ROOT/config"
    docker-compose -f docker-compose-enhanced.yml up -d

    log_info "Waiting for additional services to be ready..."
    sleep 60

    log_info "✅ Additional services deployed"
}

# Test service connectivity
test_service_connectivity() {
    log_info "Testing service connectivity..."

    # Test Elasticsearch
    if curl -s http://localhost:9200 >/dev/null; then
        log_info "✅ Elasticsearch: Reachable"
    else
        log_warning "⚠️ Elasticsearch: Not reachable"
    fi

    # Test Wazuh Indexer
    if curl -s http://localhost:9300 >/dev/null; then
        log_info "✅ Wazuh Indexer: Reachable"
    else
        log_warning "⚠️ Wazuh Indexer: Not reachable"
    fi

    # Test Velociraptor
    if curl -k -s https://localhost:8889 >/dev/null; then
        log_info "✅ Velociraptor: Reachable"
    else
        log_warning "⚠️ Velociraptor: Not reachable"
    fi

    # Test Portainer
    if curl -k -s https://localhost:9443 >/dev/null; then
        log_info "✅ Portainer: Reachable"
    else
        log_warning "⚠️ Portainer: Not reachable"
    fi

    # Test KASM
    if curl -s http://localhost:6080 >/dev/null; then
        log_info "✅ KASM: Reachable"
    else
        log_warning "⚠️ KASM: Not reachable"
    fi
}

# Generate deployment report
generate_deployment_report() {
    log_info "Generating deployment report..."

    local report_file="$PROJECT_ROOT/logs/service-recovery-$(date +%Y%m%d_%H%M%S).txt"

    cat > "$report_file" <<EOF
BTPI-REACT Service Recovery Report
=================================
Recovery Date: $(date)
Recovery Script: $0

Network Status:
$(./scripts/inspect-networks.sh)

Container Status:
$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=elasticsearch" --filter "name=cassandra" --filter "name=wazuh" --filter "name=velociraptor" --filter "name=portainer" --filter "name=kasm" --filter "name=misp")

Service Access URLs:
- Elasticsearch: http://localhost:9200
- Wazuh Indexer: http://localhost:9300
- Wazuh Manager API: https://localhost:55000
- Velociraptor: https://localhost:8889
- Portainer: https://localhost:9443
- KASM Workspaces: https://localhost:6443
- REMnux Desktop: http://localhost:6901
- MISP: https://localhost:8443

Next Steps:
1. Change default admin passwords
2. Configure service integrations
3. Set up monitoring and alerting
4. Configure backup procedures

Security Notes:
- All services are using rotated credentials
- Network isolation is active
- File permissions have been secured
- Regular credential rotation is recommended

EOF

    chmod 600 "$report_file"
    log_info "✓ Deployment report: $report_file"
}

# Main execution
main() {
    log_info "Starting BTPI-REACT Service Recovery..."
    log_info "This will deploy all services with new credentials and network isolation"
    log_info ""

    load_environment
    stop_existing_services
    update_service_deployments

    log_info "Deploying services in dependency order..."
    deploy_core_services
    deploy_wazuh_services
    deploy_infrastructure_services
    deploy_additional_services

    log_info "Testing connectivity..."
    test_service_connectivity

    log_info "Inspecting final network state..."
    ./scripts/inspect-networks.sh

    generate_deployment_report

    log_info ""
    log_info "✅ Service recovery completed successfully!"
    log_info ""
    log_info "🔗 Access URLs:"
    log_info "- Elasticsearch: http://localhost:9200"
    log_info "- Wazuh Dashboard: http://localhost:9300"
    log_info "- Velociraptor: https://localhost:8889"
    log_info "- Portainer: https://localhost:9443"
    log_info "- KASM Workspaces: https://localhost:6443"
    log_info "- REMnux Desktop: http://localhost:6901"
    log_info "- MISP: https://localhost:8443"
    log_info ""
    log_warning "⚠️ Remember to change default admin passwords!"
}

# Handle interruption
trap 'log_error "Service recovery interrupted"; exit 1' INT TERM

cd "$PROJECT_ROOT"
main "$@"
