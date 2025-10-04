# BTPI-REACT Port Assignments and Service Endpoints

## Overview

This document outlines the complete port configuration for the BTPI-REACT infrastructure-first deployment approach, including all port conflict resolutions and service endpoints.

## Port Conflict Resolutions

### Original Port Conflicts
1. **Port 8000**: Both Portainer (edge agent) and Velociraptor were configured to use port 8000

### Resolution Strategy
- **Portainer**: Moved HTTP from 9000 → 9100, kept HTTPS 9443, moved edge from 8000 → 8100
- **Velociraptor**: Kept on port 8000 (standard port after Portainer edge moved)
- **Kasm**: No changes needed (6443/6080 had no conflicts)
- **Port 9000**: Available for future use
- **Port 9001**: Available for future use

## Final Port Assignments

| Service | Ports | Protocol | Purpose |
|---------|-------|----------|---------|
| **Portainer** | 9100 | HTTP | Web Interface |
| | 9443 | HTTPS | Secure Web Interface |
| | 8100 | TCP | Edge Agent Communication |
| **Kasm Workspaces** | 6443 | HTTPS | Secure Web Interface |
| | 6080 | HTTP | Web Interface |
| **Velociraptor** | 8889 | HTTPS | Web GUI |
| | 8001 | HTTPS | API Endpoint |
| | 8000 | HTTPS | Client Communication |

## Service Endpoints

### Management Services

#### Portainer (Container Management)
- **HTTP Interface**: `http://${SERVER_IP}:9100`
- **HTTPS Interface**: `https://${SERVER_IP}:9443`
- **Purpose**: Docker container management and monitoring
- **Credentials**: See `data/portainer/credentials.env`
- **Default User**: admin

#### Kasm Workspaces (Browser-based Access)
- **HTTPS Interface**: `https://${SERVER_IP}:6443`
- **HTTP Interface**: `http://${SERVER_IP}:6080`
- **Purpose**: Secure browser-based workspace access
- **Credentials**: See `data/kasm/credentials.env`
- **Default Admin**: admin@kasm.local

### Security Analysis Services


#### Velociraptor (Endpoint Monitoring)
- **Web GUI**: `https://${SERVER_IP}:8889`
- **API Endpoint**: `https://${SERVER_IP}:8001`
- **Client Endpoint**: `https://${SERVER_IP}:8000`
- **Purpose**: Endpoint detection and response, digital forensics
- **Credentials**: See `data/velociraptor/credentials.env`
- **Default User**: admin

## Deployment Architecture

### Phase 1: Infrastructure Management
```
┌─────────────┐    ┌──────────────────┐
│  Portainer  │    │ Kasm Workspaces  │
│   :9100     │    │    :6443         │
│   :9443     │    │    :6080         │
│   :8100     │    │                  │
└─────────────┘    └──────────────────┘
       │                     │
       └─────────────────────┘
              │
       ┌─────────────────┐
       │  Docker Engine  │
       │  btpi-network   │
       └─────────────────┘
```

### Phase 2: Security Services
```
┌────────────────┐
│ Velociraptor   │
│   :8889 (GUI)  │
│   :8001 (API)  │
│   :8000 (CLI)  │
└────────────────┘
       │
    ┌─────────────────────┐
    │   Infrastructure    │
    │ Elasticsearch Only  │
    └─────────────────────┘
```

## Network Configuration

### Docker Network
- **Network Name**: `btpi-network`
- **Type**: Bridge network
- **Purpose**: Inter-service communication

### Service Dependencies
```
Velociraptor Dependencies:
├── File-based datastore
└── Internal SSL certificates

Portainer Dependencies:
├── Docker socket access
└── Data volume: portainer_data

Kasm Dependencies:
├── PostgreSQL database
├── Redis cache
└── Multiple containers (api, manager, agent, proxy)

Wazuh Dependencies:
├── Wazuh-indexer (OpenSearch)
└── Elasticsearch compatibility
```

## Security Considerations

### SSL/TLS Configuration
- **Portainer**: Built-in SSL support on port 9443
- **Kasm**: Self-signed certificates generated during deployment
- **Velociraptor**: Self-signed certificates for all HTTPS endpoints

### Authentication Methods
- **Portainer**: Local admin account with generated password
- **Kasm**: Local admin with LDAP/SAML integration available
- **Velociraptor**: Built-in user management with role-based access

### Network Isolation
- All services run on isolated `btpi-network`
- Services can communicate internally via container names
- External access controlled by port exposure

## Management and Monitoring

### Health Checks
All services include Docker health checks:
```bash
# Check all service health status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Individual service health
docker inspect <service_name> | grep -A 10 "Health"
```

### Log Access
```bash
# Service logs
docker logs portainer
docker logs velociraptor

# Kasm service logs (multiple containers)
docker logs kasm-proxy
docker logs kasm-api
docker logs kasm-manager
```

### Management Scripts
Located in `data/management/`:
- `check-all-services.sh`: Status overview
- `restart-all-services.sh`: Restart all services
- `stop-all-services.sh`: Stop all services

## Troubleshooting

### Common Port Issues
```bash
# Check port availability
netstat -tulpn | grep -E "(9100|9443|8100|6443|6080|9000|8889|8001|8000)"

# Check container port mappings
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

### Service Connectivity
```bash
# Test web interfaces
curl -k https://localhost:9443  # Portainer HTTPS
curl -k https://localhost:6443  # Kasm HTTPS
curl -k https://localhost:8889  # Velociraptor GUI
```

### Container Network Issues
```bash
# Inspect network
docker network inspect btpi-network

# Check service resolution
docker exec portainer nslookup velociraptor
docker exec velociraptor nslookup kasm-api
```

## Backup and Recovery

### Data Persistence
- **Portainer**: Docker volume `portainer_data`
- **Kasm**: Multiple data directories in `data/kasm/`
- **Velociraptor**: File-based datastore in `data/velociraptor/`
- **Wazuh**: OpenSearch indices and configuration files

### Backup Locations
```
data/
├── portainer/
│   ├── credentials.env
│   └── scripts/backup-portainer.sh
├── kasm/
│   ├── credentials.env
│   └── scripts/backup-kasm.sh
├── velociraptor/
│   ├── credentials.env
│   ├── datastore/
│   └── filestore/
└── management/
    ├── check-all-services.sh
    ├── restart-all-services.sh
    └── stop-all-services.sh
```

## Future Considerations

### Scaling Options
- **Portainer**: Add edge agents for multi-host management
- **Kasm**: Scale with additional agent containers
- **Velociraptor**: Distributed deployment with multiple frontends
- **Wazuh**: Cluster mode with multiple indexers and managers

### Integration Opportunities
- **Portainer ↔ Kasm**: Container management via browser workspace
- **All Services**: Centralized logging and monitoring via additional stack

### Security Enhancements
- Replace self-signed certificates with proper CA-signed certificates
- Implement reverse proxy with proper SSL termination
- Add authentication integration (LDAP/SAML/OAuth)
- Network segmentation with additional Docker networks
