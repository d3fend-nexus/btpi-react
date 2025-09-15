#!/bin/bash
# TheHive-Cortex Integration Configuration
# Purpose: Configure seamless integration between TheHive and Cortex

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/.env"

log_info() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] [INTEGRATION]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] [INTEGRATION ERROR]\033[0m $1"
}

# Wait for services to be ready
wait_for_services() {
    log_info "Waiting for TheHive and Cortex to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    # Wait for TheHive
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:9000/api/status" >/dev/null 2>&1; then
            log_info "TheHive is ready"
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
    
    # Reset attempt counter for Cortex
    attempt=1
    
    # Wait for Cortex
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:9001/api/status" >/dev/null 2>&1; then
            log_info "Cortex is ready"
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
}

# Configure Cortex API key
configure_cortex_api() {
    log_info "Configuring Cortex API key..."
    
    # Login to Cortex and get authentication token
    local auth_response
    auth_response=$(curl -s -X POST "http://localhost:9001/api/login" \
        -H "Content-Type: application/json" \
        -d "{\"user\":\"admin\",\"password\":\"${CORTEX_ADMIN_PASSWORD}\"}")
    
    local auth_token
    auth_token=$(echo "$auth_response" | jq -r '.token // empty')
    
    if [ -z "$auth_token" ] || [ "$auth_token" = "null" ]; then
        log_error "Failed to authenticate with Cortex"
        log_error "Response: $auth_response"
        return 1
    fi
    
    log_info "Successfully authenticated with Cortex"
    
    # Create organization if it doesn't exist
    curl -s -X POST "http://localhost:9001/api/organisation" \
        -H "Authorization: Bearer $auth_token" \
        -H "Content-Type: application/json" \
        -d '{"name":"btpi-react","description":"BTPI-REACT Organization"}' >/dev/null 2>&1 || true
    
    # Get or create API key for TheHive
    local api_key_response
    api_key_response=$(curl -s -X POST "http://localhost:9001/api/organisation/btpi-react/user/admin/key/renew" \
        -H "Authorization: Bearer $auth_token")
    
    local cortex_api_key
    cortex_api_key=$(echo "$api_key_response" | jq -r '.key // empty')
    
    if [ -z "$cortex_api_key" ] || [ "$cortex_api_key" = "null" ]; then
        log_error "Failed to generate Cortex API key"
        log_error "Response: $api_key_response"
        return 1
    fi
    
    log_info "Generated Cortex API key: ${cortex_api_key:0:8}..."
    
    # Update environment file with the new API key
    sed -i "s/CORTEX_API_KEY=.*/CORTEX_API_KEY=$cortex_api_key/" "${SCRIPT_DIR}/../../config/.env"
    
    # Export for current session
    export CORTEX_API_KEY="$cortex_api_key"
    
    log_info "Cortex API key configured successfully"
}

# Configure TheHive to use Cortex
configure_thehive_cortex() {
    log_info "Configuring TheHive-Cortex integration..."
    
    # Update TheHive configuration with Cortex settings
    local thehive_config="${SCRIPT_DIR}/../thehive/config/application.conf"
    
    if [ ! -f "$thehive_config" ]; then
        log_error "TheHive configuration file not found: $thehive_config"
        return 1
    fi
    
    # Create updated configuration with Cortex integration
    cat > "${thehive_config}.tmp" <<EOF
# TheHive Configuration for BTPI-REACT with Cortex Integration
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

## Cortex Integration - UPDATED
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
      
      # SSL Configuration
      wsConfig {
        ssl {
          loose {
            acceptAnyCertificate: true
            allowWeakProtocols: true
            allowWeakCiphers: true
            disableHostnameVerification: true
          }
        }
      }
      
      # Connection settings
      includedTheHiveOrganisations: ["btpi-react"]
      excludedTheHiveOrganisations: []
    }
  ]
  
  # Refresh interval for analyzer list
  refreshDelay: 1 minute
  
  # Cache settings
  cache {
    job: 10 minutes
    user: 5 minutes
  }
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

## Analyzer Configuration - UPDATED
analyzer {
  url: "http://cortex:9001"
  key: "${CORTEX_API_KEY}"
  
  # Auto-run analyzers on observables
  auto-extract: true
  
  # Default analyzers to run
  default-analyzers: [
    "File_Info_3_0",
    "Yara_2_0",
    "MaxMind_GeoIP_2_0"
  ]
}

## MISP Integration
misp {
  interval: 1 hour
  max: 1000
  servers: []
}

## Custom Fields
customFields {
  case {
    malware-family {
      name: "malware-family"
      reference: "malware-family"
      description: "Malware family classification"
      type: "string"
      mandatory: false
      options: ["APT", "Ransomware", "Banking Trojan", "RAT", "Backdoor", "Other"]
    }
    
    severity-score {
      name: "severity-score"
      reference: "severity-score"
      description: "Numerical severity score (1-10)"
      type: "integer"
      mandatory: false
    }
    
    attack-vector {
      name: "attack-vector"
      reference: "attack-vector"
      description: "Primary attack vector"
      type: "string"
      mandatory: false
      options: ["Email", "Web", "Network", "Physical", "Supply Chain", "Unknown"]
    }
  }
  
  alert {
    confidence-level {
      name: "confidence-level"
      reference: "confidence-level"
      description: "Confidence level of the alert"
      type: "string"
      mandatory: false
      options: ["High", "Medium", "Low"]
    }
  }
}
EOF
    
    # Replace the original configuration
    mv "${thehive_config}.tmp" "$thehive_config"
    
    log_info "TheHive configuration updated with Cortex integration"
}

# Restart TheHive to apply configuration changes
restart_thehive() {
    log_info "Restarting TheHive to apply configuration changes..."
    
    docker restart thehive
    
    # Wait for TheHive to be ready again
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:9000/api/status" >/dev/null 2>&1; then
            log_info "TheHive restarted successfully"
            break
        fi
        log_info "Waiting for TheHive to restart... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "TheHive failed to restart within expected time"
        return 1
    fi
}

# Test the integration
test_integration() {
    log_info "Testing TheHive-Cortex integration..."
    
    # Test Cortex connectivity from TheHive perspective
    local cortex_test
    cortex_test=$(curl -s -H "Authorization: Bearer ${CORTEX_API_KEY}" \
        "http://localhost:9001/api/organization" 2>/dev/null || echo "failed")
    
    if echo "$cortex_test" | grep -q '"name"'; then
        log_info "✓ Cortex API connectivity test passed"
    else
        log_error "✗ Cortex API connectivity test failed"
        return 1
    fi
    
    # Test analyzer availability
    local analyzers_test
    analyzers_test=$(curl -s -H "Authorization: Bearer ${CORTEX_API_KEY}" \
        "http://localhost:9001/api/analyzer" 2>/dev/null || echo "failed")
    
    if echo "$analyzers_test" | grep -q '\['; then
        local analyzer_count
        analyzer_count=$(echo "$analyzers_test" | jq '. | length' 2>/dev/null || echo "0")
        log_info "✓ Found $analyzer_count analyzers available"
    else
        log_error "✗ Failed to retrieve analyzer list"
        return 1
    fi
    
    # Test responder availability
    local responders_test
    responders_test=$(curl -s -H "Authorization: Bearer ${CORTEX_API_KEY}" \
        "http://localhost:9001/api/responder" 2>/dev/null || echo "failed")
    
    if echo "$responders_test" | grep -q '\['; then
        local responder_count
        responder_count=$(echo "$responders_test" | jq '. | length' 2>/dev/null || echo "0")
        log_info "✓ Found $responder_count responders available"
    else
        log_error "✗ Failed to retrieve responder list"
        return 1
    fi
    
    log_info "Integration testing completed successfully"
}

# Create integration verification script
create_verification_script() {
    log_info "Creating integration verification script..."
    
    cat > "${SCRIPT_DIR}/../../data/verify-thehive-cortex.sh" <<EOF
#!/bin/bash
# TheHive-Cortex Integration Verification Script

echo "TheHive-Cortex Integration Verification"
echo "======================================="
echo ""

# Source environment
source "${SCRIPT_DIR}/../../config/.env"

# Test TheHive connectivity
echo "Testing TheHive connectivity..."
if curl -s "http://localhost:9000/api/status" >/dev/null 2>&1; then
    echo "✓ TheHive is accessible"
else
    echo "✗ TheHive is not accessible"
    exit 1
fi

# Test Cortex connectivity
echo "Testing Cortex connectivity..."
if curl -s "http://localhost:9001/api/status" >/dev/null 2>&1; then
    echo "✓ Cortex is accessible"
else
    echo "✗ Cortex is not accessible"
    exit 1
fi

# Test Cortex API key
echo "Testing Cortex API key..."
if curl -s -H "Authorization: Bearer \${CORTEX_API_KEY}" \
    "http://localhost:9001/api/organization" | grep -q '"name"'; then
    echo "✓ Cortex API key is valid"
else
    echo "✗ Cortex API key is invalid"
    exit 1
fi

# Test analyzer availability
echo "Testing analyzer availability..."
ANALYZER_COUNT=\$(curl -s -H "Authorization: Bearer \${CORTEX_API_KEY}" \
    "http://localhost:9001/api/analyzer" | jq '. | length' 2>/dev/null || echo "0")
echo "✓ Found \$ANALYZER_COUNT analyzers available"

# Test responder availability
echo "Testing responder availability..."
RESPONDER_COUNT=\$(curl -s -H "Authorization: Bearer \${CORTEX_API_KEY}" \
    "http://localhost:9001/api/responder" | jq '. | length' 2>/dev/null || echo "0")
echo "✓ Found \$RESPONDER_COUNT responders available"

echo ""
echo "Integration Status: ✓ HEALTHY"
echo ""
echo "Access Information:"
echo "- TheHive: http://${SERVER_IP}:9000"
echo "- Cortex: http://${SERVER_IP}:9001"
echo ""
echo "Next Steps:"
echo "1. Login to TheHive with admin / \${THEHIVE_ADMIN_PASSWORD}"
echo "2. Create a case and add observables"
echo "3. Run analyzers on observables to test integration"
echo "4. Configure additional analyzers in Cortex as needed"
EOF
    
    chmod +x "${SCRIPT_DIR}/../../data/verify-thehive-cortex.sh"
    
    log_info "Verification script created: ${SCRIPT_DIR}/../../data/verify-thehive-cortex.sh"
}

# Create integration documentation
create_documentation() {
    log_info "Creating integration documentation..."
    
    cat > "${SCRIPT_DIR}/../../data/THEHIVE_CORTEX_INTEGRATION.md" <<EOF
# TheHive-Cortex Integration Guide

## Overview

This document describes the integration between TheHive (case management) and Cortex (analysis engine) in the BTPI-REACT deployment.

## Integration Features

### Automatic Analysis
- Observables added to TheHive cases are automatically analyzed by Cortex
- Analysis results are displayed directly in TheHive interface
- Multiple analyzers can be run simultaneously on the same observable

### Supported Analyzers
- **File_Info**: Extract metadata from files
- **Yara**: Scan files with YARA rules
- **VirusTotal**: Check files/hashes/URLs against VirusTotal
- **MaxMind_GeoIP**: Geolocate IP addresses
- **URLVoid**: Check URLs for malicious content
- **Shodan**: Gather information about IP addresses

### Responder Actions
- **TheHive_CreateCase**: Create new cases from analysis results
- **Mailer**: Send email notifications
- **Wazuh**: Add IOCs to Wazuh active response

## Usage Instructions

### Running Analysis on Observables

1. **Access TheHive**: http://${SERVER_IP}:9000
2. **Login**: admin / \${THEHIVE_ADMIN_PASSWORD}
3. **Create or open a case**
4. **Add observables** (IP addresses, domains, file hashes, etc.)
5. **Run analyzers**:
   - Click on an observable
   - Select "Run analyzers"
   - Choose which analyzers to run
   - Wait for results

### Viewing Analysis Results

1. **In the observable view**, analysis results appear as reports
2. **Each analyzer** provides different types of information:
   - File_Info: File type, metadata, embedded content
   - VirusTotal: Malware detection results
   - GeoIP: Geographic location of IP addresses
   - URLVoid: URL reputation and safety

### Using Responders

1. **After analysis**, responders can be triggered
2. **Available actions**:
   - Create new cases for significant findings
   - Send notifications to security team
   - Add IOCs to blocking lists

## Configuration

### API Key Management
- Cortex API key is automatically generated during deployment
- Key is stored in: \`${SCRIPT_DIR}/../../config/.env\`
- TheHive is pre-configured to use this key

### Adding External API Keys
To use external services (VirusTotal, Shodan, etc.):

1. **Access Cortex**: http://${SERVER_IP}:9001
2. **Login**: admin / \${CORTEX_ADMIN_PASSWORD}
3. **Go to Organization → Analyzers**
4. **Configure each analyzer** with appropriate API keys

### Custom Analyzers
To add custom analyzers:

1. **Create analyzer definition** in JSON format
2. **Place in**: \`${SCRIPT_DIR}/../cortex/analyzers-config/\`
3. **Restart Cortex**: \`docker restart cortex\`

## Troubleshooting

### Common Issues

#### Analyzers Not Appearing in TheHive
- Check Cortex connectivity: \`curl http://localhost:9001/api/status\`
- Verify API key: Run verification script
- Check TheHive logs: \`docker logs thehive\`

#### Analysis Jobs Failing
- Check analyzer configuration in Cortex
- Verify external API keys are valid
- Check Cortex logs: \`docker logs cortex\`

#### Slow Analysis Performance
- Monitor system resources (CPU, memory)
- Limit concurrent analysis jobs
- Consider adding more system resources

### Log Locations
- TheHive logs: \`${SCRIPT_DIR}/../../logs/thehive/\`
- Cortex logs: \`${SCRIPT_DIR}/../../logs/cortex/\`

### Verification Script
Run the integration verification script:
\`\`\`bash
${SCRIPT_DIR}/../../data/verify-thehive-cortex.sh
\`\`\`

## Advanced Configuration

### Custom Fields
TheHive is configured with custom fields for:
- Malware family classification
- Severity scoring
- Attack vector identification
- Confidence levels

### Webhook Integration
- TheHive sends webhooks to nginx for external integrations
- Webhook endpoint: \`http://nginx:80/api/webhooks/thehive\`

### Auto-Analysis Rules
Configure automatic analysis rules in TheHive:
1. Go to Admin → Observable types
2. Set default analyzers for each type
3. Enable auto-analysis for new observables

## Security Considerations

- API keys are stored securely in environment files
- All communication uses internal Docker network
- External API calls are made through Cortex only
- Consider using HTTPS in production environments

## Support

For issues with the integration:
1. Check logs in both services
2. Run the verification script
3. Review this documentation
4. Check the BTPI-REACT deployment logs
EOF
    
    log_info "Integration documentation created: ${SCRIPT_DIR}/../../data/THEHIVE_CORTEX_INTEGRATION.md"
}

# Main integration function
main() {
    log_info "Starting TheHive-Cortex integration configuration..."
    
    # Wait for services to be ready
    wait_for_services
    
    # Configure Cortex API key
    configure_cortex_api
    
    # Configure TheHive to use Cortex
    configure_thehive_cortex
    
    # Restart TheHive to apply changes
    restart_thehive
    
    # Test the integration
    test_integration
    
    # Create verification script and documentation
    create_verification_script
    create_documentation
    
    log_info "TheHive-Cortex integration completed successfully"
    log_info "Verification script: ${SCRIPT_DIR}/../../data/verify-thehive-cortex.sh"
    log_info "Documentation: ${SCRIPT_DIR}/../../data/THEHIVE_CORTEX_INTEGRATION.md"
}

main "$@"
