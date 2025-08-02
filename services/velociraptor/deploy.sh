#!/bin/bash
# Velociraptor Deployment Script
# Purpose: Deploy Velociraptor DFIR platform for endpoint hunting and remediation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/.env"

log_info() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] [VELOCIRAPTOR]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] [VELOCIRAPTOR ERROR]\033[0m $1"
}

# Create Velociraptor configuration
create_config() {
    log_info "Creating Velociraptor configuration..."
    
    mkdir -p "${SCRIPT_DIR}/config"
    
    cat > "${SCRIPT_DIR}/config/server.config.yaml" <<EOF
version:
  name: velociraptor
  version: 0.74.1
  commit: unknown
  build_time: unknown

Client:
  server_urls:
    - https://velociraptor.${DOMAIN_NAME}:8000
  ca_certificate: |
$(cat "${SCRIPT_DIR}/../../config/certificates/btpi.crt" | sed 's/^/    /')
  nonce: ${DEPLOYMENT_ID}
  writeback_darwin: /usr/local/lib/velociraptor.writeback.yaml
  writeback_linux: /etc/velociraptor.writeback.yaml
  writeback_windows: \$ProgramFiles\\Velociraptor\\velociraptor.writeback.yaml
  max_poll: 60
  max_poll_std: 5

API:
  bind_address: 0.0.0.0
  bind_port: 8001
  bind_scheme: tcp
  pinned_gw_name: GRPC_GW

GUI:
  bind_address: 0.0.0.0
  bind_port: 8889
  gw_certificate: |
$(cat "${SCRIPT_DIR}/../../config/certificates/btpi.crt" | sed 's/^/    /')
  gw_private_key: |
$(cat "${SCRIPT_DIR}/../../config/certificates/btpi.key" | sed 's/^/    /')
  internal_cidr:
    - 127.0.0.1/12
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
  vpn_cidr: []
  reverse_proxy_auth_header: Remote-User
  reverse_proxy_auth_header_regex: (.+)

Frontend:
  hostname: velociraptor.${DOMAIN_NAME}
  bind_address: 0.0.0.0
  bind_port: 8000
  certificate: |
$(cat "${SCRIPT_DIR}/../../config/certificates/btpi.crt" | sed 's/^/    /')
  private_key: |
$(cat "${SCRIPT_DIR}/../../config/certificates/btpi.key" | sed 's/^/    /')
  dyn_dns: {}
  default_client_monitoring_artifacts:
    - Generic.Client.Stats
    - Windows.Events.ProcessCreation
    - Windows.Events.ServiceCreation
    - Linux.Events.SSHLogin
    - Generic.Detection.Yara.Process
  GRPC_pool_max_size: 100
  GRPC_pool_max_wait: 60
  expected_clients: 10000
  proxy_header: X-Forwarded-For
  do_not_compress_artifacts:
    - Windows.KapeFiles.Targets
    - Windows.Memory.Acquisition

Datastore:
  implementation: FileBaseDataStore
  location: /var/lib/velociraptor
  filestore_directory: /var/lib/velociraptor

Writeback:
  private_key: |
$(openssl genrsa 2048 | sed 's/^/    /')

Mail:
  from: velociraptor@${DOMAIN_NAME}
  server: localhost
  server_port: 587
  auth_username: ""
  auth_password: ""

Logging:
  output_directory: /var/log/velociraptor
  separate_logs_per_component: true
  rotation_time: 604800
  max_age: 31536000

Monitoring:
  bind_address: 127.0.0.1
  bind_port: 8003

api_config:
  hostname: velociraptor.${DOMAIN_NAME}
  bind_address: 0.0.0.0
  bind_port: 8001
  bind_scheme: tcp
  pinned_gw_name: GRPC_GW

autocert_domain: velociraptor.${DOMAIN_NAME}
autocert_cert_cache: /var/lib/velociraptor/acme_cache

defaults:
  hunt_expiry_hours: 168
  notebook_cell_timeout_min: 10

server_type: linux

obfuscation_nonce: $(openssl rand -hex 16)

users:
  - name: admin
    password_hash: $(echo -n "${VELOCIRAPTOR_PASSWORD}" | sha256sum | cut -d' ' -f1)
    password_salt: $(openssl rand -hex 16)
    orgs:
      - name: ${DEPLOYMENT_ID}
        id: O${DEPLOYMENT_ID:0:8}

acl_strings:
  - user: admin
    permissions: all
EOF

    # Create client configuration template
    cat > "${SCRIPT_DIR}/config/client.config.yaml" <<EOF
version:
  name: velociraptor
  version: 0.74.1

Client:
  server_urls:
    - https://velociraptor.${DOMAIN_NAME}:8000
  ca_certificate: |
$(cat "${SCRIPT_DIR}/../../config/certificates/btpi.crt" | sed 's/^/    /')
  nonce: ${DEPLOYMENT_ID}
  writeback_darwin: /usr/local/lib/velociraptor.writeback.yaml
  writeback_linux: /etc/velociraptor.writeback.yaml
  writeback_windows: \$ProgramFiles\\Velociraptor\\velociraptor.writeback.yaml
  max_poll: 60
  max_poll_std: 5
  use_self_signed_ssl: true

Writeback:
  private_key: |
$(openssl genrsa 2048 | sed 's/^/    /')

Logging:
  output_directory: /var/log/velociraptor
  separate_logs_per_component: true
  rotation_time: 604800
  max_age: 31536000

obfuscation_nonce: $(openssl rand -hex 16)
EOF
}

# Deploy Velociraptor container
deploy_container() {
    log_info "Deploying Velociraptor container..."
    
    docker run -d \
        --name velociraptor \
        --restart unless-stopped \
        --network ${BTPI_NETWORK} \
        -p 8000:8000 \
        -p 8889:8889 \
        -p 8001:8001 \
        -v "${SCRIPT_DIR}/config/server.config.yaml:/etc/velociraptor/server.config.yaml:ro" \
        -v "${SCRIPT_DIR}/../../data/velociraptor:/var/lib/velociraptor" \
        -v "${SCRIPT_DIR}/../../logs/velociraptor:/var/log/velociraptor" \
        -v "${SCRIPT_DIR}/../../config/certificates:/etc/velociraptor/certs:ro" \
        -e VELOCIRAPTOR_CONFIG=/etc/velociraptor/server.config.yaml \
        velocidex/velociraptor:latest \
        --config /etc/velociraptor/server.config.yaml frontend -v

    log_info "Velociraptor container deployed"
}

# Generate client packages
generate_clients() {
    log_info "Generating client packages..."
    
    # Wait for service to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -k "https://localhost:8889/" >/dev/null 2>&1; then
            log_info "Velociraptor is ready for client generation"
            break
        fi
        log_info "Waiting for Velociraptor... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Velociraptor failed to start within expected time"
        return 1
    fi
    
    # Create client packages directory
    mkdir -p "${SCRIPT_DIR}/../../data/velociraptor/clients"
    
    # Generate Windows MSI
    log_info "Generating Windows MSI client..."
    docker exec velociraptor ./velociraptor \
        --config /etc/velociraptor/server.config.yaml \
        config client \
        --output /var/lib/velociraptor/clients/velociraptor_client.config.yaml || true
    
    # Generate Linux DEB package
    log_info "Generating Linux DEB client..."
    docker exec velociraptor ./velociraptor \
        --config /etc/velociraptor/server.config.yaml \
        debian client \
        --output /var/lib/velociraptor/clients/velociraptor_client.deb || true
    
    # Generate RPM package
    log_info "Generating Linux RPM client..."
    docker exec velociraptor ./velociraptor \
        --config /etc/velociraptor/server.config.yaml \
        rpm client \
        --output /var/lib/velociraptor/clients/velociraptor_client.rpm || true
    
    # Generate Windows executable
    log_info "Generating Windows executable client..."
    docker exec velociraptor ./velociraptor \
        --config /etc/velociraptor/server.config.yaml \
        config client \
        --output /var/lib/velociraptor/clients/velociraptor_windows.exe || true
    
    # Copy client configuration for manual deployment
    docker cp velociraptor:/var/lib/velociraptor/clients/ "${SCRIPT_DIR}/../../data/velociraptor/" 2>/dev/null || true
    
    log_info "Client packages generated in ${SCRIPT_DIR}/../../data/velociraptor/clients/"
}

# Configure custom artifacts
configure_artifacts() {
    log_info "Configuring custom artifacts..."
    
    mkdir -p "${SCRIPT_DIR}/../../data/velociraptor/artifacts"
    
    # Create custom BTPI artifact for system information
    cat > "${SCRIPT_DIR}/../../data/velociraptor/artifacts/BTPI.System.Info.yaml" <<EOF
name: BTPI.System.Info
description: |
  Collect comprehensive system information for BTPI-REACT analysis.
  
  This artifact collects:
  - System information
  - Network configuration
  - Running processes
  - Installed software
  - User accounts
  - System logs

type: CLIENT

parameters:
  - name: CollectProcesses
    description: Collect running processes
    type: bool
    default: true
  - name: CollectNetwork
    description: Collect network configuration
    type: bool
    default: true
  - name: CollectUsers
    description: Collect user accounts
    type: bool
    default: true

sources:
  - precondition:
      SELECT OS From info() where OS = 'windows'
    query: |
      -- Windows system information
      SELECT * FROM Artifact.Windows.System.Info()
      
  - precondition:
      SELECT OS From info() where OS = 'linux'
    query: |
      -- Linux system information
      SELECT * FROM Artifact.Linux.System.Info()
      
  - precondition:
      SELECT OS From info() where OS = 'darwin'
    query: |
      -- macOS system information
      SELECT * FROM Artifact.MacOS.System.Info()

reports:
  - type: CLIENT
    template: |
      # BTPI System Information Report
      
      ## System Overview
      {{ .Description }}
      
      ## Collection Results
      {{ range .Query }}
      - {{ . }}
      {{ end }}
EOF

    # Create custom artifact for threat hunting
    cat > "${SCRIPT_DIR}/../../data/velociraptor/artifacts/BTPI.Hunt.Indicators.yaml" <<EOF
name: BTPI.Hunt.Indicators
description: |
  Hunt for common indicators of compromise across endpoints.
  
  This artifact searches for:
  - Suspicious processes
  - Unusual network connections
  - File system anomalies
  - Registry modifications (Windows)
  - Persistence mechanisms

type: CLIENT

parameters:
  - name: ProcessRegex
    description: Regex pattern for suspicious process names
    type: string
    default: "(?i)(powershell|cmd|wscript|cscript|rundll32|regsvr32|mshta|bitsadmin|certutil)"
  - name: NetworkPorts
    description: Suspicious network ports to check
    type: string
    default: "4444,5555,6666,7777,8888,9999"

sources:
  - query: |
      -- Hunt for suspicious processes
      SELECT Name, Pid, Ppid, CommandLine, CreateTime
      FROM pslist()
      WHERE Name =~ ProcessRegex
      
  - query: |
      -- Hunt for suspicious network connections
      SELECT Pid, Name, LocalAddr, RemoteAddr, State
      FROM netstat()
      WHERE RemoteAddr.Port IN split(string=NetworkPorts, sep=",")
      
  - precondition:
      SELECT OS From info() where OS = 'windows'
    query: |
      -- Windows-specific hunting
      SELECT Key, ValueName, ValueData
      FROM glob(globs="HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run*")
      WHERE ValueData =~ "(?i)(temp|appdata|programdata)"

reports:
  - type: CLIENT
    template: |
      # BTPI Threat Hunting Report
      
      ## Indicators Found
      {{ range .Query }}
      ### {{ .Description }}
      {{ . }}
      {{ end }}
EOF

    # Create incident response artifact
    cat > "${SCRIPT_DIR}/../../data/velociraptor/artifacts/BTPI.IR.Collection.yaml" <<EOF
name: BTPI.IR.Collection
description: |
  Comprehensive incident response data collection for BTPI-REACT.
  
  Collects forensic artifacts including:
  - Memory dumps
  - System logs
  - Network artifacts
  - File system timeline
  - Registry hives (Windows)
  - Browser artifacts

type: CLIENT

parameters:
  - name: CollectMemory
    description: Collect memory dump
    type: bool
    default: false
  - name: CollectLogs
    description: Collect system logs
    type: bool
    default: true
  - name: CollectBrowser
    description: Collect browser artifacts
    type: bool
    default: true

sources:
  - precondition:
      SELECT CollectMemory FROM scope()
    query: |
      -- Memory collection (if enabled)
      SELECT * FROM Artifact.Windows.Memory.Acquisition()
      
  - precondition:
      SELECT CollectLogs FROM scope()
    query: |
      -- System logs collection
      SELECT * FROM Artifact.Windows.EventLogs.Evtx()
      
  - precondition:
      SELECT CollectBrowser FROM scope()
    query: |
      -- Browser artifacts
      SELECT * FROM Artifact.Windows.Applications.Chrome.History()

reports:
  - type: CLIENT
    template: |
      # BTPI Incident Response Collection Report
      
      ## Collection Summary
      - Memory: {{ if .CollectMemory }}Collected{{ else }}Skipped{{ end }}
      - Logs: {{ if .CollectLogs }}Collected{{ else }}Skipped{{ end }}
      - Browser: {{ if .CollectBrowser }}Collected{{ else }}Skipped{{ end }}
EOF

    log_info "Custom artifacts configured"
}

# Configure server settings
configure_server() {
    log_info "Configuring Velociraptor server settings..."
    
    # Create server configuration script
    cat > "${SCRIPT_DIR}/../../data/velociraptor/configure-server.sh" <<EOF
#!/bin/bash
# Velociraptor Server Configuration

echo "Velociraptor Server Configuration"
echo "================================="
echo ""
echo "Server Access Information:"
echo "- Web Interface: https://${SERVER_IP}:8889"
echo "- API Endpoint: https://${SERVER_IP}:8001"
echo "- Client Endpoint: https://${SERVER_IP}:8000"
echo ""
echo "Default Credentials:"
echo "- Username: admin"
echo "- Password: ${VELOCIRAPTOR_PASSWORD}"
echo ""
echo "Client Packages Location:"
echo "- ${SCRIPT_DIR}/../../data/velociraptor/clients/"
echo ""
echo "Custom Artifacts Location:"
echo "- ${SCRIPT_DIR}/../../data/velociraptor/artifacts/"
echo ""
echo "To deploy clients:"
echo "1. Download appropriate client package from the clients directory"
echo "2. Install on target systems"
echo "3. Clients will automatically connect to the server"
echo ""
echo "To import custom artifacts:"
echo "1. Access the web interface"
echo "2. Go to Server Artifacts"
echo "3. Upload artifacts from the artifacts directory"
echo ""
EOF
    
    chmod +x "${SCRIPT_DIR}/../../data/velociraptor/configure-server.sh"
    
    # Create client deployment guide
    cat > "${SCRIPT_DIR}/../../data/velociraptor/CLIENT_DEPLOYMENT.md" <<EOF
# Velociraptor Client Deployment Guide

## Windows Deployment

### MSI Package (Recommended)
1. Download \`velociraptor_client.msi\` from the clients directory
2. Deploy via Group Policy or SCCM:
   \`\`\`
   msiexec /i velociraptor_client.msi /quiet
   \`\`\`

### PowerShell Script
\`\`\`powershell
# Download and install Velociraptor client
\$url = "https://velociraptor.${DOMAIN_NAME}:8000/downloads/velociraptor_client.msi"
\$output = "\$env:TEMP\\velociraptor_client.msi"
Invoke-WebRequest -Uri \$url -OutFile \$output
Start-Process msiexec.exe -ArgumentList "/i \$output /quiet" -Wait
\`\`\`

## Linux Deployment

### DEB Package (Ubuntu/Debian)
\`\`\`bash
# Install DEB package
sudo dpkg -i velociraptor_client.deb
sudo systemctl enable velociraptor_client
sudo systemctl start velociraptor_client
\`\`\`

### RPM Package (RHEL/CentOS)
\`\`\`bash
# Install RPM package
sudo rpm -i velociraptor_client.rpm
sudo systemctl enable velociraptor_client
sudo systemctl start velociraptor_client
\`\`\`

### Manual Installation
\`\`\`bash
# Download client configuration
wget https://velociraptor.${DOMAIN_NAME}:8000/downloads/velociraptor_client.config.yaml

# Install Velociraptor binary
sudo wget -O /usr/local/bin/velociraptor https://github.com/Velocidx/velociraptor/releases/latest/download/velociraptor-linux-amd64
sudo chmod +x /usr/local/bin/velociraptor

# Create service
sudo /usr/local/bin/velociraptor --config velociraptor_client.config.yaml service install
sudo systemctl start velociraptor_client
\`\`\`

## macOS Deployment

### Manual Installation
\`\`\`bash
# Download client configuration
curl -O https://velociraptor.${DOMAIN_NAME}:8000/downloads/velociraptor_client.config.yaml

# Install Velociraptor binary
sudo curl -L -o /usr/local/bin/velociraptor https://github.com/Velocidx/velociraptor/releases/latest/download/velociraptor-darwin-amd64
sudo chmod +x /usr/local/bin/velociraptor

# Create service
sudo /usr/local/bin/velociraptor --config velociraptor_client.config.yaml service install
sudo launchctl load /Library/LaunchDaemons/velociraptor.plist
\`\`\`

## Verification

After installation, verify client connectivity:

1. Check the Velociraptor web interface at https://${SERVER_IP}:8889
2. Navigate to "Clients" to see connected endpoints
3. Run a test artifact like "Generic.Client.Info" to verify functionality

## Troubleshooting

### Client Not Connecting
- Verify network connectivity to port 8000
- Check firewall rules
- Verify SSL certificate trust
- Check client logs for errors

### Performance Issues
- Monitor server resources
- Adjust client polling intervals
- Limit concurrent hunts
- Use targeted client groups
EOF

    log_info "Server configuration completed"
}

# Main deployment function
main() {
    log_info "Starting Velociraptor deployment..."
    
    # Create configuration
    create_config
    
    # Deploy container
    deploy_container
    
    # Wait and generate clients
    sleep 30
    generate_clients
    
    # Configure artifacts and server
    configure_artifacts
    configure_server
    
    log_info "Velociraptor deployment completed successfully"
    log_info "Access Velociraptor at: https://${SERVER_IP}:8889"
    log_info "Default credentials: admin / ${VELOCIRAPTOR_PASSWORD}"
    log_info "Client packages: ${SCRIPT_DIR}/../../data/velociraptor/clients/"
    log_info "Configuration guide: ${SCRIPT_DIR}/../../data/velociraptor/configure-server.sh"
}

main "$@"
