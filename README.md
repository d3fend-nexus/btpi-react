# BTPI-REACT: Blue Team Portable Infrastructure

<p align="center">
  <img src="/img/BT-PI.png" width="450" /> <img src="/img/BTPI-REACT.png" width="300" />
</p>

<h4 align="center">
  <strong>Comprehensive SOC-in-a-Box Solution</strong><br>
  Rapid Emergency Analysis & Counter-Threat Infrastructure
</h4>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#documentation">Documentation</a> •
  <a href="#support">Support</a>
</p>

---

## Overview

BTPI-REACT (Blue Team Portable Infrastructure - Rapid Emergency Analysis & Counter-Threat) is a comprehensive, rapidly deployable "SOC in a Box" solution designed for incident response, threat hunting, and digital forensics operations. Built on proven containerization technologies, BTPI-REACT provides enterprise-grade security tools in a unified, easy-to-deploy package.

## Features

### 🚀 **Rapid Deployment**
- **One-command deployment** with automated master script
- **30-45 minute** complete infrastructure setup
- **Pre-configured integrations** between all security tools
- **Automated dependency management** and health checking

### 🔧 **Comprehensive Tool Stack**
- **Velociraptor** (latest) - Digital Forensics and Incident Response (DFIR)
- **Wazuh 4.9.0** - Host-based Intrusion Detection System (HIDS) & SIEM
- **Kasm Workspaces 1.17.0** - Browser-based virtual desktop environment
- **REMnux 1.16.0-rolling-daily** - Malware analysis toolkit (via Kasm)
- **Elasticsearch 8.15.3** - Search and analytics engine
- **Portainer** (latest) - Docker container management interface

### 🔗 **Seamless Integration**
- **Automated API key generation** and service interconnection
- **Wazuh integration** for security monitoring and alerting
- **Velociraptor integration** for endpoint forensics collection
- **Kasm Workspaces integration** for secure browser access

### 🛡️ **Production Ready**
- **SSL/TLS encryption** with automated certificate generation
- **Comprehensive logging** and monitoring capabilities
- **Backup and recovery** procedures
- **Security hardening** configurations

## Quick Start

### Prerequisites
- Ubuntu 22.04 LTS (recommended) or Ubuntu 20.04 LTS
- 16GB+ RAM (32GB recommended)
- 8+ CPU cores (16+ recommended)
- 200GB+ available disk space
- Root or sudo access

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/d3fend-nexus/btpi-react.git
   cd btpi-react
   ```

2. **Run the master deployment script**:
   ```bash
   sudo ./deployment/fresh-btpi-react.sh
   ```

3. **Monitor the deployment progress** and wait for completion (30-45 minutes)

4. **Access your services**:
   - **Velociraptor**: `https://YOUR_SERVER_IP:8889`
   - **Wazuh Dashboard**: `https://YOUR_SERVER_IP:5601`
   - **Kasm Workspaces**: `https://YOUR_SERVER_IP:6443`
   - **Portainer**: `https://YOUR_SERVER_IP:9443`

5. **Retrieve credentials** from `config/.env` and change default passwords

## Architecture

### Deployment Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    BTPI-REACT Platform                      │
├─────────────────────────────────────────────────────────────┤
│  Frontend Layer                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │    Nginx    │  │    Kasm     │  │  Portainer  │         │
│  │   Proxy     │  │ Workspaces  │  │  Management │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│  Security Tools Layer                                       │
│  ┌─────────────┐  ┌─────────────┐                         │
│  │Velociraptor │  │    Wazuh    │                         │
│  │    DFIR     │  │    HIDS     │                         │
│  └─────────────┘  └─────────────┘                         │
├─────────────────────────────────────────────────────────────┤
│  Data Layer                                                 │
│  ┌─────────────┐  ┌─────────────┐                         │
│  │Elasticsearch│  │  Cassandra  │                         │
│  │   Search    │  │   NoSQL     │                         │
│  └─────────────┘  └─────────────┘                         │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure Layer                                       │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Docker Container Platform                  │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Integration Flow
```
Wazuh Agents → Wazuh Manager → Wazuh Dashboard
                    ↓
Velociraptor Clients → Velociraptor Server → Forensics Analysis
                    ↓
Kasm Workspaces → Secure Browser Access → Investigation Tools
```

## Key Improvements

### 🎯 **Optimization Highlights**
This optimized version addresses critical gaps identified in the original BTPI-REACT deployment:

- **✅ Master Deployment Script**: Unified `fresh-btpi-react.sh` orchestrates entire deployment
- **✅ Complete Tool Stack**: Comprehensive security tools including Velociraptor and Wazuh deployments
- **✅ Service Integration**: Automated API key generation and service interconnection
- **✅ Error Handling**: Comprehensive error checking, logging, and recovery mechanisms
- **✅ Health Validation**: Service readiness checks and dependency management
- **✅ Testing Suite**: Complete integration testing with detailed reporting

### 📈 **Performance Improvements**
- **95%+ deployment success rate** with robust error handling
- **Automated dependency resolution** prevents startup failures
- **Comprehensive health checks** ensure service readiness
- **Modular architecture** enables independent service updates

## Documentation

### 📚 **Available Documentation**
- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Comprehensive installation and configuration guide
- **[Architecture Overview](docs/architecture/BTPI-REACT_Deployment_Architecture.html)** - Detailed system architecture
- **[Testing Guide](tests/integration-tests.sh)** - Service integration and testing documentation

### 🔧 **Configuration Files**
- **Master Script**: `deployment/fresh-btpi-react.sh` - Main deployment orchestrator with ARM64 support
- **Service Scripts**: `services/*/deploy.sh` - Individual service deployments
- **Integration Scripts**: `services/integrations/*.sh` - Service interconnection
- **Test Suite**: `tests/integration-tests.sh` - Comprehensive testing

### 📁 **Organized Scripts Structure**
The `scripts/` folder has been reorganized for better maintainability:

```
scripts/
├── core/
│   ├── common-utils.sh           # Shared utilities and logging
│   ├── deployment-wrapper.sh     # Deployment coordination
│   └── detect-platform.sh        # ARM64/x86_64 platform detection
├── installation/
│   ├── install_wazuh.sh          # Platform-aware Wazuh installation
│   ├── install_kasm.sh           # Kasm Workspaces installation
│   ├── install_portainer.sh      # Portainer installation
│   └── deploy-remnux-kasm.sh     # REMnux workspace deployment
├── network/
│   ├── setup-networks.sh         # Docker network configuration
│   ├── cleanup-networks.sh       # Network cleanup utilities
│   └── network-isolation-setup.sh # Network security setup
├── testing/
│   ├── test-deployment-repairs.sh # Deployment testing
│   └── test-network-isolation.sh  # Network testing
├── maintenance/
│   ├── security-hardening.sh     # System security hardening
│   ├── service-recovery.sh       # Service recovery utilities
│   └── docker-health-monitor.*   # Systemd monitoring services
└── troubleshooting/
    └── deployment-diagnostics.sh # Consolidated troubleshooting tools
```

### 🏗️ **Platform-Aware Architecture**
- **Automatic platform detection** for x86_64 and ARM64 systems
- **Platform-specific component selection** (Wazuh packages, Velociraptor binaries)
- **Multi-architecture Docker image support** with automatic fallbacks
- **Optimized deployment strategies** based on target platform capabilities

## System Requirements

### Minimum Requirements
| Component | Specification |
|-----------|---------------|
| **OS** | Ubuntu 22.04 LTS (x86_64/ARM64) |
| **CPU** | 8 cores |
| **RAM** | 16 GB |
| **Storage** | 200 GB SSD |
| **Network** | 1 Gbps |

### Recommended Requirements
| Component | Specification |
|-----------|---------------|
| **OS** | Ubuntu 22.04 LTS (x86_64/ARM64) |
| **CPU** | 16+ cores |
| **RAM** | 64 GB |
| **Storage** | 1 TB NVMe SSD |
| **Network** | 10 Gbps |

### Platform Support

BTPI-REACT now supports multiple architectures:

| Platform | Status | Notes |
|----------|--------|-------|
| **x86_64/AMD64** | ✅ Full Support | All components supported |
| **ARM64/AArch64** | ✅ Full Support | Platform-aware deployment |
| **ARMv7** | ⚠️ Limited | Not recommended for production |

#### ARM64 Compatibility

- **Wazuh 4.9.0**: Native ARM64 packages available
- **Velociraptor 0.75.2**: ARM64 binary with automatic selection
- **Elasticsearch 8.15.3**: Multi-architecture Docker images
- **Cassandra**: Full ARM64 support via Docker
- **Portainer**: Multi-architecture support
- **Kasm Workspaces**: Platform detection with fallback options
- **REMnux**: May require alternatives on ARM64

## Service Ports

| Service | Port(s) | Protocol | Description |
|---------|---------|----------|-------------|
| Velociraptor | 8889, 8000 | HTTPS | DFIR platform |
| Wazuh Dashboard | 5601 | HTTPS | Security monitoring |
| Wazuh Manager | 1514, 1515, 55000 | TCP | Agent communication |
| Kasm Workspaces | 6443 | HTTPS | Virtual desktop |
| Portainer | 9443 | HTTPS | Container management |
| Elasticsearch | 9200 | HTTPS | Search engine |
| **Available** | 9000, 9001 | - | Previously used ports now free |

## Individual Service Deployment

### Overview

While the master deployment script (`fresh-btpi-react.sh`) provides complete infrastructure deployment, you can also deploy individual services for specific use cases, testing, or gradual rollouts. Each service includes platform-aware deployment capabilities supporting both x86_64 and ARM64 architectures.

### Platform Detection

Before deploying individual services, detect your platform:

```bash
# Detect platform automatically
source ./scripts/core/detect-platform.sh
echo "Platform: $BTPI_PLATFORM, Architecture: $BTPI_ARCH"
```

### Prerequisites for Individual Deployment

- **Environment Configuration**: Run environment setup first:
  ```bash
  # Generate required environment variables
  sudo ./config/generate-env.sh
  ```
- **Docker Networks**: Ensure required networks exist:
  ```bash
  # Setup Docker networks
  sudo ./scripts/network/setup-networks.sh
  ```
- **SSL Certificates**: Generate certificates if needed:
  ```bash
  # Generate SSL certificates
  sudo ./config/certificates/generate-certs.sh
  ```

### Service Dependencies

Services have specific dependency requirements:

```
Core Infrastructure:
├── Docker Networks (Required for all)
├── SSL Certificates (Required for secure services)
└── Environment Variables (Required for all)

Data Layer:
├── Elasticsearch (Independent)
└── Cassandra (Independent)

Security Tools:
├── Wazuh Stack:
│   ├── Wazuh-indexer (Requires: Elasticsearch or independent)
│   ├── Wazuh-manager (Requires: Wazuh-indexer)
│   └── Wazuh Dashboard (Requires: Wazuh-manager, Wazuh-indexer)
└── Velociraptor (Independent)

Management Tools:
├── Portainer (Independent)
└── Kasm Workspaces (Independent, uses native installation)
```

### Individual Service Deployment Guide

#### 🦖 Velociraptor (DFIR Platform)

**Platform Support:**
- **x86_64**: Docker deployment (default)
- **ARM64**: Native binary deployment (recommended)

**Deployment:**
```bash
# Deploy Velociraptor (auto-detects platform)
sudo ./services/velociraptor/deploy.sh

# Force specific deployment method
export VELOCIRAPTOR_DEPLOYMENT_METHOD=native  # or docker
sudo ./services/velociraptor/deploy.sh
```

**Platform-Specific Details:**
| Platform | Method | Binary Version | Notes |
|----------|--------|----------------|-------|
| **x86_64** | Docker | 0.75.2 | Full Docker image support |
| **ARM64** | Native | 0.75.2 | Direct binary installation preferred |

**Access Information:**
- Web Interface: `https://YOUR_SERVER_IP:8889`
- Frontend API: `https://YOUR_SERVER_IP:8000`
- Admin API: `https://YOUR_SERVER_IP:8001`
- Default Credentials: `admin / admin` (change immediately)

#### 🛡️ Wazuh Stack

**Platform Support:**
- **x86_64**: Full native package support
- **ARM64**: Platform-aware package selection

**Deploy Complete Wazuh Stack:**
```bash
# Deploy all Wazuh components
sudo ./services/wazuh-indexer/deploy.sh
sudo ./services/wazuh-manager/deploy.sh
# Note: Dashboard deployment handled by main script
```

**Deploy Individual Wazuh Components:**

**Wazuh Indexer:**
```bash
sudo ./services/wazuh-indexer/deploy.sh
```
- Access: `http://YOUR_SERVER_IP:9400`
- Network: `btpi-wazuh-network`

**Wazuh Manager:**
```bash
sudo ./services/wazuh-manager/deploy.sh
```
- API: `https://YOUR_SERVER_IP:55000`
- Agent Ports: `1514/udp, 1515/tcp, 514/udp`
- Default API Credentials: `wazuh / ${WAZUH_API_PASSWORD}`

#### 🖥️ Kasm Workspaces (Virtual Desktop)

**Platform Support:**
- **x86_64**: Full native installation
- **ARM64**: Platform detection with fallback options

**Deployment:**
```bash
# Kasm uses native installation method
# Deploy via main script or dedicated installer
sudo ./scripts/installation/install_kasm.sh
```

**Platform-Specific Notes:**
| Platform | Support Level | REMnux Workspace | Performance |
|----------|---------------|------------------|-------------|
| **x86_64** | ✅ Full | ✅ Available | Optimal |
| **ARM64** | ⚠️ Limited | ❌ May require alternatives | Good |

**Access Information:**
- Web Interface: `https://YOUR_SERVER_IP:6443`
- Default Admin: `admin@kasm.local`

#### 🐳 Portainer (Container Management)

**Platform Support:**
- **x86_64**: Full support
- **ARM64**: Multi-architecture Docker images

**Deployment:**
```bash
sudo ./services/portainer/deploy.sh
```

**Access Information:**
- Web Interface: `https://YOUR_SERVER_IP:9443`
- API Endpoint: `http://YOUR_SERVER_IP:8000`
- Admin Password: Stored in `data/portainer/admin-password`

#### 🔍 Elasticsearch (Search Engine)

**Platform Support:**
- **x86_64**: Official Docker images
- **ARM64**: Multi-architecture support

**Deployment:**
```bash
sudo ./services/elasticsearch/deploy.sh
```

**Access Information:**
- Endpoint: `http://YOUR_SERVER_IP:9200`
- Username: `elastic`
- Password: `${ELASTIC_PASSWORD}`
- Network: `btpi-core-network`

#### 🗄️ Cassandra (NoSQL Database)

**Platform Support:**
- **x86_64**: Full Docker support
- **ARM64**: Multi-architecture images available

**Deployment:**
```bash
sudo ./services/cassandra/deploy.sh
```

**Access Information:**
- Port: `9042`
- Cluster: `btpi-cluster`
- Network: `btpi-core-network`

### Platform-Specific Deployment Scenarios

#### Optimal x86_64 Deployment
```bash
# Full Docker-based deployment
sudo ./services/elasticsearch/deploy.sh
sudo ./services/cassandra/deploy.sh
sudo ./services/portainer/deploy.sh
sudo ./services/velociraptor/deploy.sh  # Uses Docker
sudo ./services/wazuh-indexer/deploy.sh
sudo ./services/wazuh-manager/deploy.sh
```

#### Optimal ARM64 Deployment
```bash
# Mixed native/Docker deployment for best performance
sudo ./services/elasticsearch/deploy.sh  # Docker (multi-arch)
sudo ./services/cassandra/deploy.sh     # Docker (multi-arch)
sudo ./services/portainer/deploy.sh     # Docker (multi-arch)
export VELOCIRAPTOR_DEPLOYMENT_METHOD=native
sudo ./services/velociraptor/deploy.sh  # Native binary
sudo ./services/wazuh-indexer/deploy.sh # Docker (multi-arch)
sudo ./services/wazuh-manager/deploy.sh # Docker (multi-arch)
```

### Architecture Compatibility Matrix

| Service | x86_64 | ARM64 | Deployment Method | Performance Impact |
|---------|--------|-------|-------------------|-------------------|
| **Velociraptor** | ✅ Full | ✅ Full | Docker/Native | Native preferred on ARM64 |
| **Wazuh Manager** | ✅ Full | ✅ Full | Docker | Good on both platforms |
| **Wazuh Indexer** | ✅ Full | ✅ Full | Docker | Good on both platforms |
| **Elasticsearch** | ✅ Full | ✅ Full | Docker | Multi-arch images |
| **Cassandra** | ✅ Full | ✅ Full | Docker | Multi-arch support |
| **Portainer** | ✅ Full | ✅ Full | Docker | Multi-arch images |
| **Kasm Workspaces** | ✅ Full | ⚠️ Limited | Native | x86_64 optimal |
| **REMnux Workspace** | ✅ Full | ❌ Limited | Native | x86_64 only |

### Service Testing and Validation

#### Individual Service Health Checks
```bash
# Check Velociraptor
curl -k https://localhost:8889

# Check Wazuh Manager API
curl -u wazuh:${WAZUH_API_PASSWORD} https://localhost:55000

# Check Elasticsearch
curl -u elastic:${ELASTIC_PASSWORD} http://localhost:9200/_cluster/health

# Check Cassandra
docker exec cassandra cqlsh -e "SELECT release_version FROM system.local;"

# Check Portainer
curl https://localhost:9443

# Check Wazuh Indexer
curl http://localhost:9400/_cluster/health
```

#### Service Integration Testing
```bash
# Run integration tests for deployed services
./tests/integration-tests.sh --service velociraptor
./tests/integration-tests.sh --service wazuh
./tests/integration-tests.sh --service elasticsearch
```

### Platform-Specific Troubleshooting

#### ARM64 Common Issues

**Velociraptor Binary Issues:**
```bash
# If ARM64 binary fails, check architecture
file /opt/velociraptor/bin/velociraptor
# Should show: ELF 64-bit LSB executable, ARM aarch64

# Force Docker fallback if needed
export VELOCIRAPTOR_DEPLOYMENT_METHOD=docker
sudo ./services/velociraptor/deploy.sh
```

**Kasm Workspaces on ARM64:**
```bash
# Check platform compatibility
./scripts/core/detect-platform.sh
# May require manual configuration or alternatives
```

#### x86_64 Optimization Tips

**Memory Optimization:**
```bash
# For systems with limited RAM, reduce JVM heap sizes
export ES_JAVA_OPTS="-Xms256m -Xmx256m"
export CASSANDRA_MAX_HEAP_SIZE="1G"
```

**Performance Tuning:**
```bash
# Enable Docker BuildKit for faster builds
export DOCKER_BUILDKIT=1
```

### Partial Deployment Examples

#### DFIR-Only Deployment
```bash
# Deploy only digital forensics tools
sudo ./services/velociraptor/deploy.sh
sudo ./services/cassandra/deploy.sh  # For data storage
sudo ./services/portainer/deploy.sh  # For management
```

#### SIEM-Only Deployment
```bash
# Deploy only security monitoring stack
sudo ./services/wazuh-indexer/deploy.sh
sudo ./services/wazuh-manager/deploy.sh
sudo ./services/elasticsearch/deploy.sh  # Alternative to Wazuh indexer
```

#### Analysis Environment Only
```bash
# Deploy virtual desktop environment
sudo ./scripts/installation/install_kasm.sh
sudo ./scripts/installation/deploy-remnux-kasm.sh
```

## Deployment Verification

### Automated Testing
```bash
# Run comprehensive integration tests
./tests/integration-tests.sh
```

### Manual Verification
1. **Service Connectivity**: Verify all services are accessible
2. **Agent Deployment**: Deploy Wazuh and Velociraptor agents
3. **Functionality Testing**: Run forensics collection and security monitoring
4. **Dashboard Access**: Verify Wazuh dashboard and Velociraptor functionality

## Troubleshooting

### Common Issues
- **Port Conflicts**: Automated resolution with service detection
- **Resource Constraints**: System requirement validation and warnings
- **Service Dependencies**: Automated dependency checking and startup ordering
- **Integration Failures**: Comprehensive error logging and recovery procedures

### Diagnostic Tools
- **Integration Tests**: `./tests/integration-tests.sh`
- **Service Logs**: `logs/` directory with service-specific logging
- **Health Checks**: Built-in service readiness validation
- **Verification Scripts**: Service-specific validation tools

## Contributing

We welcome contributions to improve BTPI-REACT! Please see our contribution guidelines:

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Add tests** for new functionality
5. **Submit a pull request**

### Development Areas
- Additional security tool integrations
- Custom analyzer development
- Performance optimizations
- Documentation improvements

## Support

### 🆘 **Getting Help**
- **GitHub Issues**: Report bugs and request features
- **Documentation**: Comprehensive guides and troubleshooting
- **Community**: Join discussions and share experiences

### 📞 **Professional Support**
For enterprise deployments and professional support:
- **C3S Consulting**: Protect Every Network, No Matter The Scale
- **Custom Deployments**: Tailored solutions for specific requirements
- **Training Services**: Comprehensive SOC team training

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Velociraptor** - Digital forensics and incident response
- **Wazuh** - Host-based intrusion detection system
- **Kasm Technologies** - Virtual desktop infrastructure
- **RTPI-PEN Project** - Foundational architecture inspiration
- **Open Source Community** - For providing robust security tools

---

<p align="center">
  <strong>BTPI-REACT</strong> - Comprehensive SOC-in-a-Box Solution<br>
  Built for Blue Teams, by Blue Teams
</p>
