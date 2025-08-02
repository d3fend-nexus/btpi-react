#!/bin/bash
# Cortex Deployment Script
# Purpose: Deploy Cortex analysis platform with comprehensive analyzer suite

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/.env"

log_info() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] [CORTEX]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] [CORTEX ERROR]\033[0m $1"
}

# Create Cortex configuration
create_cortex_config() {
    log_info "Creating Cortex configuration..."
    
    mkdir -p "${SCRIPT_DIR}/config"
    
    cat > "${SCRIPT_DIR}/config/application.conf" <<EOF
# Cortex Configuration for BTPI-REACT
include file("/etc/cortex/application.conf")

## HTTP Configuration
http {
  address: 0.0.0.0
  port: 9001
  
  # CORS Configuration
  cors {
    enabled: true
    allowedOrigins: ["http://thehive:9000", "https://thehive:9000", "http://localhost:9000"]
    allowedHeaders: ["*"]
    allowedMethods: ["*"]
  }
}

## Database Configuration
db.janusgraph {
  storage.backend: cql
  storage.hostname: ["cassandra"]
  storage.port: 9042
  storage.cql.keyspace: cortex
  storage.username: cassandra
  storage.password: cassandra
  
  storage.cql.cluster-name: thehive-cluster
  storage.cql.keyspace-replication-factor: 1
  storage.cql.keyspace-replication-strategy-class: SimpleStrategy
  
  # Index Configuration  
  index.search.backend: elasticsearch
  index.search.hostname: ["elasticsearch"]
  index.search.port: 9200
  index.search.elasticsearch.ssl: false
  index.search.index-name: cortex
}

## Application Secret
play.http.secret.key: "${CORTEX_SECRET}"

## Authentication
auth {
  provider: [local]
  defaultUserDomain: "btpi.local"
  
  # Multi-organization support
  multitenant: true
}

## Analyzer Configuration
analyzer {
  # Analyzer auto-extraction
  auto-extract: true
  
  # Analyzer timeout (in seconds)
  timeout: 300
  
  # Analyzer paths
  path: [
    "/opt/cortex/analyzers"
  ]
  
  # Fork join pool configuration
  fork-join-executor {
    parallelism-min: 2
    parallelism-factor: 2.0
    parallelism-max: 4
  }
}

## Responder Configuration
responder {
  # Responder paths
  path: [
    "/opt/cortex/responders"
  ]
  
  # Fork join pool configuration
  fork-join-executor {
    parallelism-min: 2
    parallelism-factor: 2.0
    parallelism-max: 4
  }
}

## Job Configuration
job {
  runner: [docker, process]
  
  # Docker configuration
  docker {
    # Auto-remove containers after job completion
    auto-remove: true
    
    # Container resource limits
    cpu: 1.0
    memory: 512m
    
    # Network configuration
    network: ${BTPI_NETWORK}
  }
}

## Cache Configuration
cache {
  job: 10 minutes
  user: 5 minutes
}

## Service Configuration
services {
  LocalUserSrv {
    method: init
    params {
      organisation: btpi-react
      login: admin
      name: "Cortex Administrator"
      password: ${CORTEX_ADMIN_PASSWORD}
      key: ${CORTEX_API_KEY}
    }
  }
  
  LocalOrganisationSrv {
    method: init
    params {
      organisation: btpi-react
      name: "BTPI-REACT Organization"
      description: "Blue Team Portable Infrastructure Analysis"
    }
  }
}

## Datastore Configuration
datastore {
  name: data
  
  # File storage configuration
  attachment.password: ${CORTEX_ATTACHMENT_PASSWORD}
}

## Stream Configuration
stream.live.subscribe {
  # Refresh interval for live updates
  refresh: 1s
  
  # Buffer size
  buffer.size: 50
}
EOF
}

# Deploy analyzer configurations
deploy_analyzers() {
    log_info "Deploying Cortex analyzers..."
    
    mkdir -p "${SCRIPT_DIR}/analyzers-config"
    
    # VirusTotal Analyzer Configuration
    cat > "${SCRIPT_DIR}/analyzers-config/VirusTotal.json" <<EOF
{
  "name": "VirusTotal_GetReport",
  "version": "3.1",
  "author": "Eric Capuano, Nils Kuhnert, Cedric Hien",
  "url": "https://github.com/TheHive-Project/Cortex-Analyzers",
  "license": "AGPL-V3",
  "description": "Retrieve the latest VirusTotal report for a file, hash, domain or IP address",
  "dataTypeList": ["file", "hash", "domain", "ip", "url"],
  "command": "VirusTotal/virustotal.py",
  "baseConfig": "VirusTotal",
  "config": {
    "service": "GetReport"
  },
  "configurationItems": [
    {
      "name": "key",
      "description": "API key for VirusTotal",
      "type": "string",
      "multi": false,
      "required": true,
      "defaultValue": null
    },
    {
      "name": "polling_interval", 
      "description": "Define time interval between two requests attempts for the report",
      "type": "number",
      "multi": false,
      "required": false,
      "defaultValue": 60
    }
  ]
}
EOF

    # File_Info Analyzer Configuration
    cat > "${SCRIPT_DIR}/analyzers-config/File_Info.json" <<EOF
{
  "name": "File_Info",
  "version": "2.0",
  "author": "Eric Capuano",
  "url": "https://github.com/TheHive-Project/Cortex-Analyzers",
  "license": "AGPL-V3",
  "description": "Parse files in several formats such as OLE and OpenXML to detect VBA macros, extract their source code, generate useful information for malware analysis",
  "dataTypeList": ["file"],
  "command": "FileInfo/fileinfo.py",
  "baseConfig": "FileInfo",
  "config": {},
  "configurationItems": []
}
EOF

    # Yara Analyzer Configuration  
    cat > "${SCRIPT_DIR}/analyzers-config/Yara.json" <<EOF
{
  "name": "Yara",
  "version": "2.0", 
  "author": "Eric Capuano",
  "url": "https://github.com/TheHive-Project/Cortex-Analyzers",
  "license": "AGPL-V3",
  "description": "Check files against YARA rules",
  "dataTypeList": ["file"],
  "command": "Yara/yara_analyzer.py",
  "baseConfig": "Yara",
  "config": {},
  "configurationItems": [
    {
      "name": "rules",
      "description": "Path to YARA rules directory",
      "type": "string", 
      "multi": false,
      "required": true,
      "defaultValue": "/opt/yara-rules"
    }
  ]
}
EOF

    # MaxMind GeoIP Analyzer
    cat > "${SCRIPT_DIR}/analyzers-config/MaxMind_GeoIP.json" <<EOF
{
  "name": "MaxMind_GeoIP",
  "version": "2.0",
  "author": "Nils Kuhnert, Cedric Hien",
  "url": "https://github.com/TheHive-Project/Cortex-Analyzers", 
  "license": "AGPL-V3",
  "description": "Geolocate an IP Address via MaxMind GeoIP",
  "dataTypeList": ["ip"],
  "command": "MaxMind/maxmind.py",
  "baseConfig": "MaxMind",
  "config": {},
  "configurationItems": [
    {
      "name": "database_path",
      "description": "Location of MaxMind database file",
      "type": "string",
      "multi": false, 
      "required": true,
      "defaultValue": "/opt/maxmind/GeoLite2-City.mmdb"
    }
  ]
}
EOF

    # URLVoid Analyzer
    cat > "${SCRIPT_DIR}/analyzers-config/URLVoid.json" <<EOF
{
  "name": "URLVoid",
  "version": "1.0",
  "author": "BTPI-REACT Team",
  "url": "https://github.com/TheHive-Project/Cortex-Analyzers",
  "license": "AGPL-V3",
  "description": "Check URLs against URLVoid database",
  "dataTypeList": ["url", "domain"],
  "command": "URLVoid/urlvoid.py",
  "baseConfig": "URLVoid",
  "config": {},
  "configurationItems": [
    {
      "name": "key",
      "description": "URLVoid API key",
      "type": "string",
      "multi": false,
      "required": true,
      "defaultValue": null
    }
  ]
}
EOF

    # Shodan Analyzer
    cat > "${SCRIPT_DIR}/analyzers-config/Shodan.json" <<EOF
{
  "name": "Shodan_Info",
  "version": "2.0",
  "author": "Nils Kuhnert, Cedric Hien",
  "url": "https://github.com/TheHive-Project/Cortex-Analyzers",
  "license": "AGPL-V3",
  "description": "Retrieve information from Shodan",
  "dataTypeList": ["ip"],
  "command": "Shodan/shodan_analyzer.py",
  "baseConfig": "Shodan",
  "config": {},
  "configurationItems": [
    {
      "name": "key",
      "description": "Shodan API key",
      "type": "string",
      "multi": false,
      "required": true,
      "defaultValue": null
    }
  ]
}
EOF
}

# Deploy responder configurations
deploy_responders() {
    log_info "Deploying Cortex responders..."
    
    mkdir -p "${SCRIPT_DIR}/responders-config"
    
    # TheHive Create Case Responder
    cat > "${SCRIPT_DIR}/responders-config/TheHive_CreateCase.json" <<EOF
{
  "name": "TheHive_CreateCase",
  "version": "1.0",
  "author": "BTPI-REACT Team",
  "url": "https://github.com/TheHive-Project/Cortex-Analyzers",
  "license": "AGPL-V3", 
  "description": "Create a case in TheHive from Cortex analysis results",
  "dataTypeList": ["thehive:case", "thehive:alert"],
  "command": "TheHive/thehive_create_case.py",
  "baseConfig": "TheHive",
  "config": {},
  "configurationItems": [
    {
      "name": "thehive_url",
      "description": "TheHive instance URL",
      "type": "string",
      "multi": false,
      "required": true,
      "defaultValue": "http://thehive:9000"
    },
    {
      "name": "thehive_apikey", 
      "description": "TheHive API key",
      "type": "string",
      "multi": false,
      "required": true,
      "defaultValue": null
    }
  ]
}
EOF

    # Email Notification Responder
    cat > "${SCRIPT_DIR}/responders-config/Mailer.json" <<EOF
{
  "name": "Mailer",
  "version": "1.0",
  "author": "BTPI-REACT Team", 
  "url": "https://github.com/TheHive-Project/Cortex-Analyzers",
  "license": "AGPL-V3",
  "description": "Send email notifications based on analysis results",
  "dataTypeList": ["thehive:case", "thehive:case_task", "thehive:alert"],
  "command": "Mailer/mailer.py",
  "baseConfig": "Mailer",
  "config": {},
  "configurationItems": [
    {
      "name": "smtp_host",
      "description": "SMTP server hostname",
      "type": "string", 
      "multi": false,
      "required": true,
      "defaultValue": "localhost"
    },
    {
      "name": "smtp_port",
      "description": "SMTP server port",
      "type": "number",
      "multi": false,
      "required": true, 
      "defaultValue": 587
    }
  ]
}
EOF

    # Wazuh Responder
    cat > "${SCRIPT_DIR}/responders-config/Wazuh.json" <<EOF
{
  "name": "Wazuh_AddToActiveResponse",
  "version": "1.0",
  "author": "BTPI-REACT Team",
  "url": "https://github.com/TheHive-Project/Cortex-Analyzers",
  "license": "AGPL-V3",
  "description": "Add IOCs to Wazuh active response",
  "dataTypeList": ["ip", "domain", "hash"],
  "command": "Wazuh/wazuh_responder.py",
  "baseConfig": "Wazuh",
  "config": {},
  "configurationItems": [
    {
      "name": "wazuh_url",
      "description": "Wazuh manager URL",
      "type": "string",
      "multi": false,
      "required": true,
      "defaultValue": "https://wazuh-manager:55000"
    },
    {
      "name": "wazuh_user",
      "description": "Wazuh API user",
      "type": "string",
      "multi": false,
      "required": true,
      "defaultValue": "admin"
    },
    {
      "name": "wazuh_password",
      "description": "Wazuh API password",
      "type": "string",
      "multi": false,
      "required": true,
      "defaultValue": null
    }
  ]
}
EOF
}

# Deploy Cortex container
deploy_cortex() {
    log_info "Deploying Cortex container..."
    
    docker run -d \
        --name cortex \
        --restart unless-stopped \
        --network ${BTPI_NETWORK} \
        -p 9001:9001 \
        -e JVM_OPTS="-Xms1g -Xmx2g" \
        -v "${SCRIPT_DIR}/config/application.conf:/etc/cortex/application.conf:ro" \
        -v "${SCRIPT_DIR}/analyzers-config:/opt/cortex/analyzers:ro" \
        -v "${SCRIPT_DIR}/responders-config:/opt/cortex/responders:ro" \
        -v "${SCRIPT_DIR}/../../data/cortex:/opt/cortex/data" \
        -v "${SCRIPT_DIR}/../../logs/cortex:/var/log/cortex" \
        -v "/var/run/docker.sock:/var/run/docker.sock:ro" \
        --depends-on cassandra \
        --depends-on elasticsearch \
        thehiveproject/cortex:3.1.8

    log_info "Cortex container deployed"
}

# Download and configure analyzer dependencies
configure_dependencies() {
    log_info "Configuring analyzer dependencies..."
    
    # Create directories for analyzer data
    mkdir -p "${SCRIPT_DIR}/../../data/cortex/yara-rules"
    mkdir -p "${SCRIPT_DIR}/../../data/cortex/maxmind"
    
    # Download YARA rules
    log_info "Downloading YARA rules..."
    if [ ! -d "${SCRIPT_DIR}/../../data/cortex/yara-rules/community-rules" ]; then
        git clone https://github.com/Yara-Rules/rules.git \
            "${SCRIPT_DIR}/../../data/cortex/yara-rules/community-rules" || true
    fi
    
    # Download additional YARA rules for malware detection
    if [ ! -d "${SCRIPT_DIR}/../../data/cortex/yara-rules/reversinglabs" ]; then
        git clone https://github.com/reversinglabs/reversinglabs-yara-rules.git \
            "${SCRIPT_DIR}/../../data/cortex/yara-rules/reversinglabs" || true
    fi
    
    # Download Signature-Base YARA rules
    if [ ! -d "${SCRIPT_DIR}/../../data/cortex/yara-rules/signature-base" ]; then
        git clone https://github.com/Neo23x0/signature-base.git \
            "${SCRIPT_DIR}/../../data/cortex/yara-rules/signature-base" || true
    fi
    
    # Create a combined YARA rules file
    log_info "Creating combined YARA rules file..."
    find "${SCRIPT_DIR}/../../data/cortex/yara-rules" -name "*.yar" -o -name "*.yara" | \
        head -100 | xargs cat > "${SCRIPT_DIR}/../../data/cortex/yara-rules/combined.yara" 2>/dev/null || true
    
    # Download MaxMind GeoLite2 database (requires account)
    log_info "MaxMind GeoLite2 database requires manual download from https://dev.maxmind.com/geoip/geolite2-free-geolocation-data"
    log_info "Download GeoLite2-City.mmdb to ${SCRIPT_DIR}/../../data/cortex/maxmind/"
    
    # Create a placeholder file with instructions
    cat > "${SCRIPT_DIR}/../../data/cortex/maxmind/README.txt" <<EOF
MaxMind GeoLite2 Database Setup Instructions
==========================================

1. Create a free account at: https://dev.maxmind.com/geoip/geolite2-free-geolocation-data
2. Download GeoLite2-City.mmdb
3. Place the file in this directory: ${SCRIPT_DIR}/../../data/cortex/maxmind/GeoLite2-City.mmdb

This database is required for the MaxMind GeoIP analyzer to function properly.
EOF
}

# Configure Cortex post-deployment  
configure_cortex() {
    log_info "Configuring Cortex post-deployment settings..."
    
    # Wait for Cortex to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:9001/api/status" >/dev/null 2>&1; then
            log_info "Cortex is ready for configuration"
            break
        fi
        log_info "Waiting for Cortex... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Cortex failed to start within expected time"
        return 1
    fi
    
    # Create API key for TheHive integration
    log_info "Creating API key for TheHive integration..."
    
    # Generate integration script
    cat > "${SCRIPT_DIR}/../../data/cortex/setup-integration.sh" <<EOF
#!/bin/bash
# Cortex-TheHive Integration Setup

# Login to Cortex and get authentication token
AUTH_TOKEN=\$(curl -s -X POST "http://localhost:9001/api/login" \
    -H "Content-Type: application/json" \
    -d '{"user":"admin","password":"${CORTEX_ADMIN_PASSWORD}"}' | \
    jq -r '.token // empty')

if [ -z "\$AUTH_TOKEN" ]; then
    echo "Failed to authenticate with Cortex"
    exit 1
fi

# Create organization if it doesn't exist
curl -s -X POST "http://localhost:9001/api/organisation" \
    -H "Authorization: Bearer \$AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"btpi-react","description":"BTPI-REACT Organization"}'

# Create API key for TheHive
API_KEY_RESPONSE=\$(curl -s -X POST "http://localhost:9001/api/organisation/btpi-react/user/admin/key/renew" \
    -H "Authorization: Bearer \$AUTH_TOKEN")

echo "Cortex API Key: \$(echo \$API_KEY_RESPONSE | jq -r '.key')"
echo "Save this key for TheHive configuration"
EOF
    
    chmod +x "${SCRIPT_DIR}/../../data/cortex/setup-integration.sh"
    
    # Create analyzer configuration script
    cat > "${SCRIPT_DIR}/../../data/cortex/configure-analyzers.sh" <<EOF
#!/bin/bash
# Configure Cortex Analyzers

# This script helps configure analyzers with API keys
echo "Cortex Analyzer Configuration"
echo "============================"
echo ""
echo "To configure analyzers, you'll need API keys for:"
echo "- VirusTotal: https://www.virustotal.com/gui/join-us"
echo "- URLVoid: https://www.urlvoid.com/api/"
echo "- Shodan: https://www.shodan.io/"
echo ""
echo "After obtaining API keys, configure them in the Cortex web interface:"
echo "1. Access Cortex at http://${SERVER_IP}:9001"
echo "2. Login with admin / ${CORTEX_ADMIN_PASSWORD}"
echo "3. Go to Organization -> Analyzers"
echo "4. Configure each analyzer with the appropriate API keys"
echo ""
EOF
    
    chmod +x "${SCRIPT_DIR}/../../data/cortex/configure-analyzers.sh"
    
    log_info "Cortex configuration completed"
}

# Main deployment function
main() {
    log_info "Starting Cortex deployment..."
    
    # Create configuration
    create_cortex_config
    deploy_analyzers
    deploy_responders
    
    # Deploy Cortex
    deploy_cortex
    
    # Configure dependencies and post-deployment
    configure_dependencies
    configure_cortex
    
    log_info "Cortex deployment completed successfully"
    log_info "Access Cortex at: http://${SERVER_IP}:9001"
    log_info "Default credentials: admin / ${CORTEX_ADMIN_PASSWORD}"
    log_info "Run integration setup: ${SCRIPT_DIR}/../../data/cortex/setup-integration.sh"
    log_info "Configure analyzers: ${SCRIPT_DIR}/../../data/cortex/configure-analyzers.sh"
}

main "$@"
