#!/bin/bash
# BTPI-REACT Security Hardening Script
# Purpose: Generate new passwords, rotate credentials, and update configurations securely

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/config/.env"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log_info() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] [SECURITY]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] [SECURITY ERROR]\033[0m $1"
}

log_warning() {
    echo -e "\033[0;33m[$(date +'%Y-%m-%d %H:%M:%S')] [SECURITY WARNING]\033[0m $1"
}

# Generate secure random password
generate_password() {
    local length=${1:-64}
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Generate JWT secret
generate_jwt_secret() {
    openssl rand -hex 64
}

# Generate cluster key
generate_cluster_key() {
    openssl rand -hex 32
}

# Backup current configuration
backup_current_config() {
    log_info "Creating backup of current configuration..."

    local backup_dir="$PROJECT_ROOT/backups/security-backup-$TIMESTAMP"
    mkdir -p "$backup_dir"

    # Backup .env file
    if [[ -f "$ENV_FILE" ]]; then
        cp "$ENV_FILE" "$backup_dir/.env.backup"
        log_info "✓ Environment file backed up"
    fi

    # Backup compose files
    for compose_file in "$PROJECT_ROOT/config/docker-compose"*.yml; do
        if [[ -f "$compose_file" ]]; then
            cp "$compose_file" "$backup_dir/$(basename "$compose_file").backup"
        fi
    done

    log_info "✓ Configuration backup completed: $backup_dir"
    echo "$backup_dir" > "$PROJECT_ROOT/.last-backup-path"
}

# Generate new credentials
generate_new_credentials() {
    log_info "Generating new secure credentials..."

    # Database passwords
    ELASTIC_PASSWORD=$(generate_password 43)
    CASSANDRA_PASSWORD=$(generate_password 43)
    POSTGRES_PASSWORD=$(generate_password 43)

    # Application passwords
    VELOCIRAPTOR_PASSWORD=$(generate_password 43)
    WAZUH_API_PASSWORD=$(generate_password 43)

    # KASM specific passwords
    KASM_DB_PASSWORD=$(generate_password 43)
    KASM_REDIS_PASSWORD=$(generate_password 43)
    KASM_API_TOKEN=$(generate_password 43)
    KASM_MANAGER_TOKEN=$(generate_password 43)
    KASM_ADMIN_PASSWORD=$(generate_password 24)

    # MISP passwords
    MISP_DB_ROOT_PASSWORD=$(generate_password 32)
    MISP_DB_PASSWORD=$(generate_password 32)
    MISP_REDIS_PASSWORD=$(generate_password 32)

    # Security keys
    WAZUH_CLUSTER_KEY=$(generate_cluster_key)
    JWT_SECRET=$(generate_jwt_secret)

    log_info "✓ All credentials generated successfully"
}

# Update .env file with new credentials
update_env_file() {
    log_info "Updating environment configuration with new credentials..."

    # Create new .env file with updated credentials
    cat > "$ENV_FILE" <<EOF
# BTPI-REACT Environment Configuration
# Generated: $(date)
# Deployment ID: $(uuidgen)
# SECURITY NOTE: This file contains sensitive credentials - protect accordingly

# System Configuration
BTPI_VERSION=2.0.1
DEPLOYMENT_ID=$(uuidgen)
DEPLOYMENT_DATE=$(date +%Y%m%d_%H%M%S)

# =============================================================================
# DATABASE CREDENTIALS (ROTATED: $TIMESTAMP)
# =============================================================================
ELASTIC_PASSWORD=$ELASTIC_PASSWORD
CASSANDRA_PASSWORD=$CASSANDRA_PASSWORD
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# =============================================================================
# APPLICATION CREDENTIALS (ROTATED: $TIMESTAMP)
# =============================================================================
VELOCIRAPTOR_PASSWORD=$VELOCIRAPTOR_PASSWORD
WAZUH_API_PASSWORD=$WAZUH_API_PASSWORD

# =============================================================================
# KASM WORKSPACES CREDENTIALS (ROTATED: $TIMESTAMP)
# =============================================================================
KASM_DB_PASSWORD=$KASM_DB_PASSWORD
KASM_REDIS_PASSWORD=$KASM_REDIS_PASSWORD
KASM_API_TOKEN=$KASM_API_TOKEN
KASM_MANAGER_TOKEN=$KASM_MANAGER_TOKEN
KASM_ADMIN_PASSWORD=$KASM_ADMIN_PASSWORD

# =============================================================================
# MISP CREDENTIALS (ROTATED: $TIMESTAMP)
# =============================================================================
MISP_DB_ROOT_PASSWORD=$MISP_DB_ROOT_PASSWORD
MISP_DB_PASSWORD=$MISP_DB_PASSWORD
MISP_REDIS_PASSWORD=$MISP_REDIS_PASSWORD

# =============================================================================
# SECURITY KEYS (ROTATED: $TIMESTAMP)
# =============================================================================
WAZUH_CLUSTER_KEY=$WAZUH_CLUSTER_KEY
JWT_SECRET=$JWT_SECRET

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================
DOMAIN_NAME=btpi.local
SERVER_IP=192.168.1.184

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

    log_info "✓ Environment file updated with new credentials"
}

# Update docker-compose files to use environment variables
update_compose_files() {
    log_info "Updating docker-compose files to use environment variables..."

    # Update docker-compose-enhanced.yml to use env vars instead of hardcoded passwords
    cat > "$PROJECT_ROOT/config/docker-compose-enhanced.yml" <<EOF
version: '3.8'

services:
  # Database for Kasm
  kasm-db:
    image: postgres:14-alpine
    container_name: kasm-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: kasm
      POSTGRES_USER: kasm
      POSTGRES_PASSWORD: \${KASM_DB_PASSWORD}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - /home/cmndcntrl/code/btpi-react/data/kasm/postgres:/var/lib/postgresql/data
      - /home/cmndcntrl/code/btpi-react/config/database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - btpi-infra-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U kasm"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  # Redis for Kasm
  kasm-redis:
    image: redis:7-alpine
    container_name: kasm-redis
    restart: unless-stopped
    command: redis-server --requirepass \${KASM_REDIS_PASSWORD}
    volumes:
      - /home/cmndcntrl/code/btpi-react/data/kasm/redis:/data
    networks:
      - btpi-infra-network
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Kasm API Server
  kasm-api:
    image: kasmweb/api:1.15.0
    container_name: kasm-api
    restart: unless-stopped
    environment:
      KASM_DB_HOST: kasm-db
      KASM_DB_PORT: 5432
      KASM_DB_NAME: kasm
      KASM_DB_USER: kasm
      KASM_DB_PASSWORD: \${KASM_DB_PASSWORD}
      KASM_REDIS_HOST: kasm-redis
      KASM_REDIS_PORT: 6379
      KASM_REDIS_PASSWORD: \${KASM_REDIS_PASSWORD}
      KASM_API_TOKEN: \${KASM_API_TOKEN}
      KASM_MANAGER_TOKEN: \${KASM_MANAGER_TOKEN}
    volumes:
      - /home/cmndcntrl/code/btpi-react/data/kasm/api:/opt/kasm/current/log
    depends_on:
      kasm-db:
        condition: service_healthy
      kasm-redis:
        condition: service_healthy
    networks:
      - btpi-infra-network
      - btpi-proxy-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  # Kasm Manager
  kasm-manager:
    image: kasmweb/manager:1.15.0
    container_name: kasm-manager
    restart: unless-stopped
    environment:
      KASM_API_HOST: kasm-api
      KASM_API_PORT: 8080
      KASM_API_TOKEN: \${KASM_API_TOKEN}
      KASM_MANAGER_TOKEN: \${KASM_MANAGER_TOKEN}
      KASM_ADMIN_EMAIL: btpi-nexus@btpi.local
      KASM_ADMIN_PASSWORD: \${KASM_ADMIN_PASSWORD}
      KASM_USER_PASSWORD: \${KASM_ADMIN_PASSWORD}
    volumes:
      - /home/cmndcntrl/code/btpi-react/data/kasm/manager:/opt/kasm/current/log
      - /home/cmndcntrl/code/btpi-react/config/kasm:/opt/kasm/current/conf:ro
    depends_on:
      kasm-api:
        condition: service_healthy
    networks:
      - btpi-infra-network
      - btpi-proxy-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8181/"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  # Kasm Agent with REMnux support
  kasm-agent:
    image: kasmweb/agent:1.15.0
    container_name: kasm-agent
    restart: unless-stopped
    privileged: true
    environment:
      KASM_API_HOST: kasm-api
      KASM_API_PORT: 8080
      KASM_API_TOKEN: \${KASM_API_TOKEN}
      KASM_AGENT_HOSTNAME: kasm-agent-01
      DOCKER_HOST: unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /home/cmndcntrl/code/btpi-react/data/kasm/agent:/opt/kasm/current/log
      - /home/cmndcntrl/code/btpi-react/data/kasm/workspaces:/opt/kasm/current/workspaces
      - /home/cmndcntrl/code/btpi-react/config/kasm:/opt/kasm/current/conf:ro
    depends_on:
      kasm-api:
        condition: service_healthy
    networks:
      - btpi-infra-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Nginx Proxy for Kasm
  kasm-proxy:
    image: nginx:alpine
    container_name: kasm-proxy
    restart: unless-stopped
    ports:
      - "6443:443"
      - "6080:80"
    volumes:
      - /home/cmndcntrl/code/btpi-react/config/nginx/kasm.conf:/etc/nginx/conf.d/default.conf:ro
      - /home/cmndcntrl/code/btpi-react/config/certificates/btpi.crt:/etc/nginx/ssl/btpi.crt:ro
      - /home/cmndcntrl/code/btpi-react/config/certificates/btpi.key:/etc/nginx/ssl/btpi.key:ro
      - /home/cmndcntrl/code/btpi-react/data/kasm/static:/opt/kasm/current/static:ro
      - /home/cmndcntrl/code/btpi-react/data/kasm/downloads:/opt/kasm/current/downloads:ro
    depends_on:
      kasm-api:
        condition: service_healthy
      kasm-manager:
        condition: service_healthy
    networks:
      - btpi-proxy-network
      - btpi-infra-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/"]
      interval: 30s
      timeout: 10s
      retries: 5

  # REMnux Desktop for Security Analysis
  remnux-desktop:
    image: kasmweb/remnux-focal-desktop:1.16.0-rolling-weekly
    container_name: remnux-desktop
    restart: unless-stopped
    ports:
      - "6901:6901"
    environment:
      VNC_PW: \${KASM_ADMIN_PASSWORD}
      USER: "btpi-nexus"
      PASSWORD: \${KASM_ADMIN_PASSWORD}
      KASM_VNC_HTTP: "1"
      KASM_PORT: "6901"
    volumes:
      - /home/cmndcntrl/code/btpi-react/data/remnux:/home/kasm-user/Desktop/shared:rw
    networks:
      - btpi-infra-network
    extra_hosts:
      - "host.docker.internal:host-gateway"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6901/"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  # MISP Database
  misp-db:
    image: mariadb:10.11 # IP-OK - version number, not IP
    container_name: misp-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: \${MISP_DB_ROOT_PASSWORD}
      MYSQL_DATABASE: misp
      MYSQL_USER: misp
      MYSQL_PASSWORD: \${MISP_DB_PASSWORD}
    volumes:
      - /home/cmndcntrl/code/btpi-react/data/misp/mysql:/var/lib/mysql
    networks:
      - btpi-infra-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p\${MISP_DB_ROOT_PASSWORD}"]
      interval: 30s
      timeout: 10s
      retries: 5

  # MISP Redis
  misp-redis:
    image: redis:7-alpine
    container_name: misp-redis
    restart: unless-stopped
    command: redis-server --requirepass \${MISP_REDIS_PASSWORD}
    volumes:
      - /home/cmndcntrl/code/btpi-react/data/misp/redis:/data
    networks:
      - btpi-infra-network
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

  # MISP Core Application
  misp-core:
    image: ghcr.io/misp/misp-docker/misp-core:latest
    container_name: misp-core
    restart: unless-stopped
    ports:
      - "8080:80"
      - "8443:443"
    environment:
      MYSQL_HOST: misp-db
      MYSQL_USER: misp
      MYSQL_PASSWORD: \${MISP_DB_PASSWORD}
      MYSQL_DATABASE: misp
      MISP_MODULES_FQDN: http://misp-modules
      WORKERS: 1
      NUM_WORKERS_DEFAULT: 2
      NUM_WORKERS_PRIO: 2
      NUM_WORKERS_EMAIL: 2
      NUM_WORKERS_UPDATE: 1
      NUM_WORKERS_CACHE: 2
      BASE_URL: https://\${DOMAIN_NAME}:8443
      DISABLE_IPV6: "true"
      ENABLE_DB_SETTINGS: "false"
    volumes:
      - /home/cmndcntrl/code/btpi-react/data/misp/files:/var/www/MISP/app/files
      - /home/cmndcntrl/code/btpi-react/data/misp/logs:/var/www/MISP/app/tmp/logs
      - /home/cmndcntrl/code/btpi-react/data/misp/config:/var/www/MISP/app/Config
      - /home/cmndcntrl/code/btpi-react/config/misp/ssl:/etc/nginx/certs
      - /home/cmndcntrl/code/btpi-react/data/misp/gnupg:/var/www/MISP/.gnupg
    depends_on:
      misp-db:
        condition: service_healthy
      misp-redis:
        condition: service_healthy
    networks:
      - btpi-infra-network
      - btpi-proxy-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/users/login"]
      interval: 60s
      timeout: 30s
      retries: 5
      start_period: 120s

  # MISP Modules
  misp-modules:
    image: ghcr.io/misp/misp-docker/misp-modules:latest
    container_name: misp-modules
    restart: unless-stopped
    environment:
      REDIS_BACKEND: misp-redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: \${MISP_REDIS_PASSWORD}
    depends_on:
      misp-redis:
        condition: service_healthy
    networks:
      - btpi-infra-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6666/modules"]
      interval: 30s
      timeout: 10s
      retries: 5

networks:
  btpi-core-network:
    external: true
    name: btpi-core-network
  btpi-wazuh-network:
    external: true
    name: btpi-wazuh-network
  btpi-infra-network:
    external: true
    name: btpi-infra-network
  btpi-proxy-network:
    external: true
    name: btpi-proxy-network

volumes:
  kasm-postgres:
  kasm-redis:
  kasm-api:
  kasm-manager:
  kasm-agent:
  misp-mysql:
  misp-redis:
  misp-files:
EOF

    log_info "✓ Docker compose files updated"
}

# Secure file permissions
secure_file_permissions() {
    log_info "Securing file permissions..."

    # Set restrictive permissions on .env file
    chmod 600 "$ENV_FILE"

    # Secure certificate directories
    if [[ -d "$PROJECT_ROOT/config/certificates" ]]; then
        chmod 700 "$PROJECT_ROOT/config/certificates"
        find "$PROJECT_ROOT/config/certificates" -type f -exec chmod 600 {} \;
    fi

    # Secure config directories
    find "$PROJECT_ROOT/config" -name "*.conf" -exec chmod 600 {} \;

    log_info "✓ File permissions secured"
}

# Generate credential summary
generate_credential_summary() {
    log_info "Generating credential summary..."

    local summary_file="$PROJECT_ROOT/logs/credential-rotation-$TIMESTAMP.txt"

    cat > "$summary_file" <<EOF
BTPI-REACT Credential Rotation Summary
=====================================
Rotation Date: $(date)
Backup Location: $(cat "$PROJECT_ROOT/.last-backup-path" 2>/dev/null || echo "Not available")

IMPORTANT SECURITY NOTICE:
- All default passwords have been rotated
- New credentials are stored in config/.env
- Previous credentials backed up securely
- File permissions have been hardened

Services Affected:
- Elasticsearch: Password rotated
- Cassandra: Password rotated
- PostgreSQL (Kasm): Password rotated
- Velociraptor: Password rotated
- Wazuh API: Password rotated
- KASM Workspaces: All credentials rotated
- MISP: All credentials rotated
- Security Keys: JWT Secret and Cluster Key rotated

Next Steps:
1. Restart all services with new credentials
2. Test service connectivity
3. Update any external integrations
4. Schedule regular credential rotation

Access Information (CHANGE IMMEDIATELY):
- Kasm Admin: btpi-nexus@btpi.local
- Domain: btpi.local (192.168.1.184) # IP-OK

WARNING: Store this file securely and delete after use.
EOF

    chmod 600 "$summary_file"
    log_info "✓ Credential summary: $summary_file"
}

# Main execution
main() {
    log_info "Starting BTPI-REACT Security Hardening..."
    log_info "This process will:"
    log_info "1. Backup current configuration"
    log_info "2. Generate new secure credentials"
    log_info "3. Update configuration files"
    log_info "4. Secure file permissions"
    log_info ""

    backup_current_config
    generate_new_credentials
    update_env_file
    update_compose_files
    secure_file_permissions
    generate_credential_summary

    log_info ""
    log_info "✅ Security hardening completed successfully!"
    log_info ""
    log_info "NEXT STEPS:"
    log_info "1. Review credential rotation summary in logs/"
    log_info "2. Restart services with: docker-compose up -d"
    log_info "3. Test service connectivity"
    log_info "4. Change default admin passwords"
    log_info ""
    log_warning "IMPORTANT: All services must be restarted to use new credentials"
}

# Handle interruption
trap 'log_error "Security hardening interrupted"; exit 1' INT TERM

main "$@"
