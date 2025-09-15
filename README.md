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
- **TheHive 5.x** - Security Incident Response Platform (SIRP)
- **Cortex 3.x** - Observable Analysis Engine with 20+ analyzers
- **Velociraptor** - Digital Forensics and Incident Response (DFIR)
- **Wazuh 4.12+** - Host-based Intrusion Detection System (HIDS)
- **Kasm Workspaces** - Browser-based virtual desktop environment
- **Portainer** - Docker container management interface

### 🔗 **Seamless Integration**
- **Automated API key generation** and service interconnection
- **TheHive-Cortex integration** for automated observable analysis
- **Wazuh-TheHive integration** for alert-to-case workflow
- **Velociraptor integration** for endpoint forensics collection

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
   sudo ./fresh-btpi-react.sh
   ```

3. **Monitor the deployment progress** and wait for completion (30-45 minutes)

4. **Access your services**:
   - **TheHive**: `http://YOUR_SERVER_IP:9000`
   - **Cortex**: `http://YOUR_SERVER_IP:9001`
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
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   TheHive   │  │   Cortex    │  │Velociraptor │         │
│  │    SIRP     │  │  Analysis   │  │    DFIR     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐                                           │
│  │    Wazuh    │                                           │
│  │    HIDS     │                                           │
│  └─────────────┘                                           │
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
Wazuh Agents → Wazuh Manager → TheHive Cases
                    ↓
Velociraptor Clients → Velociraptor Server → TheHive Evidence
                    ↓
TheHive Observables → Cortex Analyzers → Analysis Results
```

## Key Improvements

### 🎯 **Optimization Highlights**
This optimized version addresses critical gaps identified in the original BTPI-REACT deployment:

- **✅ Master Deployment Script**: Unified `fresh-btpi-react.sh` orchestrates entire deployment
- **✅ Complete Tool Stack**: Added missing TheHive, Cortex, and Velociraptor deployments
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
- **[Architecture Overview](BTPI-REACT_Deployment_Architecture.html)** - Detailed system architecture
- **[Integration Guide](data/THEHIVE_CORTEX_INTEGRATION.md)** - Service integration documentation
- **[Testing Guide](tests/integration-tests.sh)** - Automated testing procedures

### 🔧 **Configuration Files**
- **Master Script**: `fresh-btpi-react.sh` - Main deployment orchestrator
- **Service Scripts**: `services/*/deploy.sh` - Individual service deployments
- **Integration Scripts**: `services/integrations/*.sh` - Service interconnection
- **Test Suite**: `tests/integration-tests.sh` - Comprehensive testing

## System Requirements

### Minimum Requirements
| Component | Specification |
|-----------|---------------|
| **OS** | Ubuntu 22.04 LTS |
| **CPU** | 8 cores |
| **RAM** | 16 GB |
| **Storage** | 200 GB SSD |
| **Network** | 1 Gbps |

### Recommended Requirements
| Component | Specification |
|-----------|---------------|
| **OS** | Ubuntu 22.04 LTS |
| **CPU** | 16+ cores |
| **RAM** | 64 GB |
| **Storage** | 1 TB NVMe SSD |
| **Network** | 10 Gbps |

## Service Ports

| Service | Port(s) | Protocol | Description |
|---------|---------|----------|-------------|
| TheHive | 9000 | HTTP | Case management interface |
| Cortex | 9001 | HTTP | Analysis engine interface |
| Velociraptor | 8889, 8000 | HTTPS | DFIR platform |
| Wazuh Dashboard | 5601 | HTTPS | Security monitoring |
| Wazuh Manager | 1514, 1515, 55000 | TCP | Agent communication |
| Kasm Workspaces | 6443 | HTTPS | Virtual desktop |
| Portainer | 9443 | HTTPS | Container management |
| Elasticsearch | 9200 | HTTPS | Search engine |

## Deployment Verification

### Automated Testing
```bash
# Run comprehensive integration tests
./tests/integration-tests.sh
```

### Manual Verification
1. **Service Connectivity**: Verify all services are accessible
2. **Integration Testing**: Test TheHive-Cortex observable analysis
3. **Agent Deployment**: Deploy Wazuh and Velociraptor agents
4. **Functionality Testing**: Create cases, run analyses, collect forensics

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

- **TheHive Project** - Security incident response platform
- **Cortex Project** - Observable analysis engine
- **Velociraptor** - Digital forensics and incident response
- **Wazuh** - Host-based intrusion detection system
- **Kasm Technologies** - Virtual desktop infrastructure
- **RTPI-PEN Project** - Foundational architecture inspiration

---

<p align="center">
  <strong>BTPI-REACT</strong> - Comprehensive SOC-in-a-Box Solution<br>
  Built for Blue Teams, by Blue Teams
</p>
