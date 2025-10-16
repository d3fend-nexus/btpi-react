# BTPI-REACT Deployment Guide

## Overview

BTPI-REACT (Blue Team Portable Infrastructure - Rapid Emergency Analysis & Counter-Threat) is a comprehensive "SOC in a Box" solution that provides rapid deployment of essential security tools for incident response, threat hunting, and digital forensics operations.

## Architecture

The BTPI-REACT platform consists of the following integrated components:

### Core Security Tools
- **Velociraptor** - Digital Forensics and Incident Response (DFIR) platform
- **Wazuh 4.12+** - Host-based Intrusion Detection System (HIDS)

### Infrastructure Components
- **Elasticsearch** - Search and analytics engine
- **Cassandra** - NoSQL database
- **Kasm Workspaces** - Browser-based virtual desktop environment
- **Portainer** - Docker container management interface
- **Nginx** - Reverse proxy and load balancer

## System Requirements

### Minimum Requirements
- **Operating System**: Ubuntu 22.04 LTS (recommended) or Ubuntu 20.04 LTS
- **CPU**: 8 cores (Intel Xeon or AMD EPYC recommended)
- **RAM**: 16 GB (32 GB recommended for production)
- **Storage**: 200 GB SSD (500 GB recommended)
- **Network**: Stable internet connection for initial setup

### Recommended Requirements
- **CPU**: 16+ cores
- **RAM**: 64 GB
- **Storage**: 1 TB NVMe SSD
- **Network**: 10 Gbps network interface

## Pre-Deployment Preparation

### 1. System Updates
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### 2. Install Required Packages
```bash
sudo apt install -y \
    curl \
    wget \
    git \
    jq \
    openssl \
    ca-certificates \
    gnupg \
    lsb-release \
    net-tools \
    lsof
```

### 3. Configure System Limits
```bash
# Edit /etc/security/limits.conf
sudo tee -a /etc/security/limits.conf <<EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# Edit /etc/sysctl.conf
sudo tee -a /etc/sysctl.conf <<EOF
vm.max_map_count=262144
net.ipv4.ip_forward=1
fs.file-max=65536
EOF

sudo sysctl -p
```

### 4. Configure Firewall (if enabled)
```bash
# Allow required ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 1514/tcp  # Wazuh agents
sudo ufw allow 1515/tcp  # Wazuh enrollment
sudo ufw allow 6443/tcp  # Kasm
sudo ufw allow 8889/tcp  # Velociraptor
sudo ufw allow 9443/tcp  # Portainer
sudo ufw allow 55000/tcp # Wazuh API
```

## Deployment Process

### 1. Download BTPI-REACT
```bash
git clone https://github.com/d3fend-nexus/btpi-react.git
cd btpi-react
```

### 2. Run Master Deployment Script
```bash
# Make the script executable (if not already)
chmod +x deployment/fresh-btpi-react.sh

# Full deployment (recommended)
sudo ./deployment/fresh-btpi-react.sh

# Simple deployment (no system optimizations)
sudo ./deployment/fresh-btpi-react.sh --mode simple

# Custom deployment (specific services)
sudo ./deployment/fresh-btpi-react.sh --mode custom --services velociraptor,wazuh-manager

# Available options:
# --mode full|simple|custom
# --services LIST (comma-separated for custom mode)
# --skip-checks (skip system requirements checks)
# --skip-optimization (skip system optimizations)
# --debug (enable debug logging)
# --help (show help message)
```

### 3. Monitor Deployment Progress
The script provides real-time progress updates with color-coded status messages:
- **GREEN**: Successful operations
- **YELLOW**: Warnings (non-critical issues)
- **RED**: Errors (critical issues)
- **BLUE**: Informational messages

### 4. Deployment Phases
The deployment process consists of several phases:

1. **Pre-deployment Checks** - System validation and requirements verification
2. **System Preparation** - Package installation and system optimization
3. **Infrastructure Deployment** - Database and core services
4. **Security Services Deployment** - Velociraptor, Wazuh
5. **Integration Configuration** - Service interconnection and API setup
6. **Testing and Validation** - Comprehensive integration testing

## Post-Deployment Configuration

### 1. Access Services
After successful deployment, access your services at:

- **Kasm Workspaces**: `https://YOUR_SERVER_IP:6443`
- **Portainer**: `https://YOUR_SERVER_IP:9443`
- **Velociraptor**: `https://YOUR_SERVER_IP:8889`
- **Wazuh Dashboard**: `https://YOUR_SERVER_IP:5601`

### 2. Initial Credentials
Default credentials are automatically generated and stored in:
```
config/.env
```

**IMPORTANT**: Change all default passwords immediately after first login.

### 3. Service Configuration

#### Velociraptor Configuration
1. Access Velociraptor at `https://YOUR_SERVER_IP:8889`
2. Login with generated credentials
3. Download client packages from `data/velociraptor/clients/`
4. Deploy clients to endpoints
5. Import custom artifacts from `data/velociraptor/artifacts/`

#### Wazuh Configuration
1. Access Wazuh Dashboard at `https://YOUR_SERVER_IP:5601`
2. Login with generated credentials
3. Configure agent deployment
4. Set up log collection rules
5. Configure alerting and notifications

## Integration Verification

### Run Integration Tests
```bash
# Execute comprehensive integration tests
./tests/integration-tests.sh
```

### Manual Verification
1. **Wazuh Integration**:
   - Deploy Wazuh agents to endpoints
   - Verify log collection and alerting
   - Check dashboard functionality

2. **Velociraptor Integration**:
   - Deploy clients to endpoints
   - Run artifact collection
   - Verify data collection and analysis

## Maintenance and Operations

### Regular Maintenance Tasks

#### Daily
- Monitor system resources (CPU, memory, disk)
- Check service status and logs
- Review security alerts and incidents

#### Weekly
- Update threat intelligence feeds
- Review and tune detection rules
- Backup configuration and data
- Update system packages

#### Monthly
- Review user access and permissions
- Update security tools and analyzers
- Conduct security assessments
- Review and update documentation

### Backup Procedures

#### Configuration Backup
```bash
# Backup configuration files
tar -czf btpi-config-backup-$(date +%Y%m%d).tar.gz config/

# Backup service configurations
tar -czf btpi-services-backup-$(date +%Y%m%d).tar.gz services/
```

#### Data Backup
```bash
# Backup application data
tar -czf btpi-data-backup-$(date +%Y%m%d).tar.gz data/

# Backup logs
tar -czf btpi-logs-backup-$(date +%Y%m%d).tar.gz logs/
```

### Log Management

#### Log Locations
- **Deployment logs**: `logs/deployment.log`
- **Velociraptor logs**: `logs/velociraptor/`
- **Wazuh logs**: `logs/wazuh/`

#### Log Rotation
Configure log rotation to prevent disk space issues:
```bash
sudo tee /etc/logrotate.d/btpi-react <<EOF
/path/to/btpi-react/logs/*/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
```

## Troubleshooting

### Common Issues

#### Services Not Starting
1. Check system resources (memory, disk space)
2. Verify port availability
3. Check Docker daemon status
4. Review service logs for errors

#### Integration Issues
1. Verify API keys and credentials
2. Check network connectivity between services
3. Review integration configuration files
4. Run integration tests for specific diagnosis

#### Performance Issues
1. Monitor system resources
2. Adjust service memory limits
3. Optimize database configurations
4. Consider hardware upgrades

### Diagnostic Commands

#### System Status
```bash
# Check system resources
free -h
df -h
top

# Check Docker status
docker ps
docker stats

# Check network connectivity
netstat -tlnp
```

#### Service Status
```bash
# Check individual services
docker logs velociraptor
docker logs wazuh-manager

# Check service health
curl -s -k https://localhost:8889/
```

### Getting Help

#### Documentation
- Service-specific documentation in `docs/` directory
- Integration guides in `data/` directory
- Configuration examples in `services/` directories

#### Log Analysis
- Check deployment logs for installation issues
- Review service logs for runtime errors
- Use integration tests for systematic diagnosis

#### Community Support
- GitHub Issues: Report bugs and request features
- Documentation: Contribute improvements and corrections

## Security Considerations

### Network Security
- Use firewalls to restrict access to management interfaces
- Implement VPN access for remote administration
- Enable SSL/TLS for all web interfaces
- Regular security updates and patches

### Access Control
- Change all default passwords immediately
- Implement strong password policies
- Use multi-factor authentication where available
- Regular access reviews and user management

### Data Protection
- Encrypt sensitive data at rest and in transit
- Implement proper backup and recovery procedures
- Regular security assessments and penetration testing
- Compliance with relevant regulations and standards

## Advanced Configuration

### High Availability Setup
For production environments, consider:
- Load balancing with multiple instances
- Database clustering and replication
- Shared storage for data persistence
- Automated failover mechanisms

### Performance Tuning
- Adjust JVM heap sizes for Java applications
- Optimize database configurations
- Configure caching mechanisms
- Monitor and tune system parameters

### Custom Integrations
- Create custom artifacts for Velociraptor
- Implement webhook integrations
- Extend functionality with custom scripts

## Conclusion

BTPI-REACT provides a comprehensive, rapidly deployable security operations platform. Following this deployment guide ensures a successful installation and configuration of all components. Regular maintenance and monitoring are essential for optimal performance and security.

For additional support and updates, refer to the project documentation and community resources.
