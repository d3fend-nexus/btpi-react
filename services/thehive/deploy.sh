#!/bin/bash
# TheHive Deployment Script
# Purpose: Deploy TheHive case management platform with Cassandra backend

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/.env"

log_info() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] [THEHIVE]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] [THEHIVE ERROR]\033[0m $1"
}

# Deploy Cassandra database
deploy_cassandra() {
    log_info "Deploying Cassandra database for TheHive..."
    
    # Create Cassandra initialization script
    mkdir -p "${SCRIPT_DIR}/cassandra-init"
    cat > "${SCRIPT_DIR}/cassandra-init/init.cql" <<EOF
CREATE KEYSPACE IF NOT EXISTS thehive 
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

USE thehive;

CREATE TABLE IF NOT EXISTS user (
    login text PRIMARY KEY,
    password text,
    name text,
    roles set<text>
);

CREATE TABLE IF NOT EXISTS organisation (
    id text PRIMARY KEY,
    name text,
    description text
);
EOF

    # Deploy Cassandra container
    docker run -d \
        --name cassandra \
        --restart unless-stopped \
        --network ${BTPI_NETWORK} \
        -p 9042:9042 \
        -e CASSANDRA_CLUSTER_NAME=thehive-cluster \
        -e CASSANDRA_DC=datacenter1 \
        -e CASSANDRA_RACK=rack1 \
        -e CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch \
        -e MAX_HEAP_SIZE=2G \
        -e HEAP_NEWSIZE=400M \
        -v "${SCRIPT_DIR}/../../data/cassandra:/var/lib/cassandra" \
        -v "${SCRIPT_DIR}/cassandra-init:/docker-entrypoint-initdb.d:ro" \
        cassandra:4.1

    log_info "Cassandra deployed, waiting for initialization..."
    
    # Wait for Cassandra to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec cassandra cqlsh -e "DESC KEYSPACES" >/dev/null 2>&1; then
            log_info "Cassandra is ready"
            break
        fi
        log_info "Waiting for Cassandra... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Cassandra failed to start within expected time"
        return 1
    fi
}

# Deploy Elasticsearch for TheHive
deploy_elasticsearch() {
    log_info "Deploying Elasticsearch for TheHive..."
    
    # Create Elasticsearch configuration
    mkdir -p "${SCRIPT_DIR}/elasticsearch-config"
    cat > "${SCRIPT_DIR}/elasticsearch-config/elasticsearch.yml" <<EOF
cluster.name: thehive-cluster
node.name: thehive-node-1
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
cluster.initial_master_nodes: ["thehive-node-1"]
EOF

    # Deploy Elasticsearch container
    docker run -d \
        --name elasticsearch \
        --restart unless-stopped \
        --network ${BTPI_NETWORK} \
        -p 9200:9200 \
        -p 9300:9300 \
        -e "discovery.type=single-node" \
        -e "cluster.name=thehive-cluster" \
        -e "node.name=thehive-node-1" \
        -e "bootstrap.memory_lock=true" \
        -e "ES_JAVA_OPTS=-Xms2g -Xmx2g" \
        -e "xpack.security.enabled=false" \
        --ulimit memlock=-1:-1 \
        -v "${SCRIPT_DIR}/../../data/elasticsearch:/usr/share/elasticsearch/data" \
        -v "${SCRIPT_DIR}/elasticsearch-config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro" \
        docker.elastic.co/elasticsearch/elasticsearch:8.11.0

    log_info "Elasticsearch deployed, waiting for initialization..."
    
    # Wait for Elasticsearch to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:9200/_cluster/health" >/dev/null 2>&1; then
            log_info "Elasticsearch is ready"
            break
        fi
        log_info "Waiting for Elasticsearch... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Elasticsearch failed to start within expected time"
        return 1
    fi
}

# Create TheHive configuration
create_thehive_config() {
    log_info "Creating TheHive configuration..."
    
    mkdir -p "${SCRIPT_DIR}/config"
    
    cat > "${SCRIPT_DIR}/config/application.conf" <<EOF
# TheHive Configuration for BTPI-REACT
include file("/etc/thehive/application.conf")

## Database Configuration
db.janusgraph {
  storage.backend: cql
  storage.hostname: ["cassandra"]
  storage.port: 9042
  storage.cql.keyspace: thehive
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
  index.search.index-name: thehive
}

## Authentication Configuration
auth {
  providers: [
    {name: session}
    {name: basic, realm: thehive}
    {name: local}
    {name: key}
  ]
  
  # Multi-factor authentication
  multifactor: [
    {name: totp, issuer: TheHive, label: "TheHive-BTPI"}
  ]
}

## HTTP Configuration
http {
  address: 0.0.0.0
  port: 9000
}

## Application Secret
play.http.secret.key: "${THEHIVE_SECRET}"

## File Storage Configuration
storage {
  provider: localfs
  localfs {
    location: /opt/thehive/files
  }
}

## Cortex Integration
play.modules.enabled += org.thp.thehive.connector.cortex.CortexModule
cortex {
  servers: [
    {
      name: local-cortex
      url: "http://cortex:9001"
      auth {
        type: "bearer"
        key: "${CORTEX_API_KEY}"
      }
    }
  ]
}

## Service Configuration
services {
  LocalUserSrv {
    method: init
    params {
      organisation: btpi-react
      login: admin
      name: "BTPI Administrator"
      password: ${THEHIVE_ADMIN_PASSWORD}
      profile: admin
    }
  }
  
  LocalOrganisationSrv {
    method: init
    params {
      organisation: btpi-react
      name: "BTPI-REACT Organization"
      description: "Blue Team Portable Infrastructure"
    }
  }
}

## Notification Configuration
notification.webhook.endpoints = [
  {
    name: local-webhook
    url: "http://nginx:80/api/webhooks/thehive"
    version: 0
    wsConfig: {}
    includedTheHiveObjects: ["case", "case_task", "alert"]
    excludedTheHiveObjects: []
  }
]

## Analyzer Configuration
analyzer {
  url: "http://cortex:9001"
  key: "${CORTEX_API_KEY}"
}

## MISP Integration
misp {
  interval: 1 hour
  max: 1000
  servers: []
}
EOF
}

# Deploy TheHive container
deploy_thehive() {
    log_info "Deploying TheHive container..."
    
    docker run -d \
        --name thehive \
        --restart unless-stopped \
        --network ${BTPI_NETWORK} \
        -p 9000:9000 \
        -e JVM_OPTS="-Xms2g -Xmx4g" \
        -v "${SCRIPT_DIR}/config/application.conf:/etc/thehive/application.conf:ro" \
        -v "${SCRIPT_DIR}/../../config/certificates:/etc/thehive/certs:ro" \
        -v "${SCRIPT_DIR}/../../data/thehive/files:/opt/thehive/files" \
        -v "${SCRIPT_DIR}/../../data/thehive/index:/opt/thehive/index" \
        -v "${SCRIPT_DIR}/../../logs/thehive:/var/log/thehive" \
        --depends-on cassandra \
        --depends-on elasticsearch \
        strangebee/thehive:5.4

    log_info "TheHive container deployed"
}

# Configure TheHive post-deployment
configure_thehive() {
    log_info "Configuring TheHive post-deployment settings..."
    
    # Wait for TheHive to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:9000/api/status" >/dev/null 2>&1; then
            log_info "TheHive is ready for configuration"
            break
        fi
        log_info "Waiting for TheHive... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "TheHive failed to start within expected time"
        return 1
    fi
    
    # Create initial case templates
    mkdir -p "${SCRIPT_DIR}/../../data/thehive/templates"
    cat > "${SCRIPT_DIR}/../../data/thehive/templates/case-templates.json" <<EOF
[
  {
    "name": "Malware Analysis",
    "displayName": "Malware Analysis Case",
    "description": "Template for malware analysis incidents",
    "severity": 2,
    "tlp": 2,
    "pap": 2,
    "tags": ["malware", "analysis"],
    "customFields": {
      "sample-hash": {"type": "string", "mandatory": true},
      "family": {"type": "string", "mandatory": false}
    },
    "tasks": [
      {
        "title": "Initial Triage",
        "description": "Perform initial analysis of the malware sample"
      },
      {
        "title": "Static Analysis",
        "description": "Conduct static analysis using available tools"
      },
      {
        "title": "Dynamic Analysis",
        "description": "Execute sample in sandbox environment"
      },
      {
        "title": "Report Generation",
        "description": "Generate comprehensive analysis report"
      }
    ]
  },
  {
    "name": "Phishing Investigation",
    "displayName": "Phishing Email Investigation",
    "description": "Template for phishing email investigations",
    "severity": 2,
    "tlp": 2,
    "pap": 2,
    "tags": ["phishing", "email"],
    "customFields": {
      "sender-email": {"type": "string", "mandatory": true},
      "email-subject": {"type": "string", "mandatory": true}
    },
    "tasks": [
      {
        "title": "Email Header Analysis",
        "description": "Analyze email headers for indicators"
      },
      {
        "title": "URL Analysis",
        "description": "Analyze any URLs found in the email"
      },
      {
        "title": "Attachment Analysis",
        "description": "Analyze any attachments for malicious content"
      }
    ]
  },
  {
    "name": "Network Intrusion",
    "displayName": "Network Intrusion Investigation",
    "description": "Template for network intrusion incidents",
    "severity": 3,
    "tlp": 2,
    "pap": 2,
    "tags": ["network", "intrusion", "compromise"],
    "customFields": {
      "source-ip": {"type": "string", "mandatory": true},
      "target-system": {"type": "string", "mandatory": true}
    },
    "tasks": [
      {
        "title": "Network Traffic Analysis",
        "description": "Analyze network traffic patterns and anomalies"
      },
      {
        "title": "Log Analysis",
        "description": "Review system and security logs"
      },
      {
        "title": "Forensic Imaging",
        "description": "Create forensic images of affected systems"
      },
      {
        "title": "Containment",
        "description": "Implement containment measures"
      }
    ]
  }
]
EOF

    # Create custom observables
    cat > "${SCRIPT_DIR}/../../data/thehive/templates/observable-types.json" <<EOF
[
  {
    "name": "btc-address",
    "displayName": "Bitcoin Address",
    "isAttachment": false
  },
  {
    "name": "eth-address", 
    "displayName": "Ethereum Address",
    "isAttachment": false
  },
  {
    "name": "tor-hidden-service",
    "displayName": "Tor Hidden Service",
    "isAttachment": false
  },
  {
    "name": "yara-rule",
    "displayName": "YARA Rule",
    "isAttachment": false
  },
  {
    "name": "sigma-rule",
    "displayName": "Sigma Rule",
    "isAttachment": false
  }
]
EOF

    log_info "TheHive configuration completed"
}

# Main deployment function
main() {
    log_info "Starting TheHive deployment..."
    
    # Deploy dependencies
    deploy_cassandra
    deploy_elasticsearch
    
    # Create configuration
    create_thehive_config
    
    # Deploy TheHive
    deploy_thehive
    
    # Configure post-deployment
    configure_thehive
    
    log_info "TheHive deployment completed successfully"
    log_info "Access TheHive at: http://${SERVER_IP}:9000"
    log_info "Default credentials: admin / ${THEHIVE_ADMIN_PASSWORD}"
}

main "$@"
