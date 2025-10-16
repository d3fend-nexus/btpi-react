# ARM64 Deployment Guide for BTPI-REACT

This guide provides comprehensive instructions for deploying BTPI-REACT on ARM64/AArch64 systems with platform-specific optimizations and validated deployment methods.

## Quick Start

### Prerequisites Verification

```bash
# Verify ARM64 system
uname -m
# Expected output: aarch64

# Test deployment tools
sudo ./scripts/testing/test-arm64-deployment.sh

# Monitor services in real-time
./scripts/testing/monitor-arm64-services.sh -c -a -p
```

---

## Platform Requirements

### Hardware Requirements

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **CPU** | 8 ARM cores | 16+ ARM cores | ARMv8.2+ recommended |
| **RAM** | 16 GB | 32+ GB | 20-30% more than x86_64 |
| **Storage** | 200 GB SSD | 500+ GB NVMe | ARM64 I/O optimization important |
| **Network** | 1 Gbps | 10+ Gbps | Same as x86_64 requirements |

### Software Requirements

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y \
    curl wget git \
    docker.io docker-compose \
    qemu-user-static binfmt-support \
    build-essential

# Install Docker buildx for multi-arch support
sudo apt install -y docker-buildx-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Enable QEMU emulation for x86_64 fallback
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

---

## Service-Specific Deployment Methods

### 1. Velociraptor (DFIR Platform) ✅ **Full ARM64 Support**

**Recommended Method:** Native Binary Deployment

```bash
# Platform-aware deployment (auto-selects native for ARM64)
sudo ./services/velociraptor/deploy.sh

# Force native deployment method
export VELOCIRAPTOR_DEPLOYMENT_METHOD=native
sudo ./services/velociraptor/deploy.sh
```

**Deployment Details:**
- **Binary**: `velociraptor-v0.75.2-linux-arm64`
- **Method**: Native systemd service
- **Performance**: Optimal on ARM64
- **Ports**: 8889 (Web), 8000 (API), 8001 (Admin)

**Validation:**
```bash
# Check service status
systemctl status velociraptor

# Test web interface
curl -k https://localhost:8889/

# Verify binary architecture
file /opt/velociraptor/bin/velociraptor
# Expected: ELF 64-bit LSB executable, ARM aarch64
```

**Fallback Method:** Docker with emulation
```bash
export VELOCIRAPTOR_DEPLOYMENT_METHOD=docker
sudo ./services/velociraptor/deploy.sh
```

### 2. Elasticsearch ✅ **Multi-Arch Support**

**Recommended Method:** Docker Multi-Architecture Image

```bash
# Deploy with ARM64-optimized settings
sudo ./services/elasticsearch/deploy.sh
```

**ARM64 Optimizations:**
```bash
# Set ARM64-optimized JVM settings
export ES_JAVA_OPTS="-Xms512m -Xmx1g -XX:+UseG1GC"

# Custom deployment with platform specification
docker run -d \
    --name elasticsearch \
    --platform=linux/arm64 \
    --restart unless-stopped \
    --network btpi-core-network \
    -p 9200:9200 \
    -e "discovery.type=single-node" \
    -e "ES_JAVA_OPTS=${ES_JAVA_OPTS}" \
    docker.elastic.co/elasticsearch/elasticsearch:8.15.3
```

**Performance Tuning for ARM64:**
```yaml
# elasticsearch.yml optimizations
cluster.name: btpi-cluster
node.name: btpi-node-1
network.host: 0.0.0.0
http.port: 9200

# ARM64-specific settings
bootstrap.memory_lock: true
indices.memory.index_buffer_size: 20%
thread_pool.write.queue_size: 1000
thread_pool.search.queue_size: 1000

# Reduce resource usage for smaller ARM64 systems
cluster.routing.allocation.disk.watermark.low: 85%
cluster.routing.allocation.disk.watermark.high: 90%
```

**Validation:**
```bash
# Health check
curl http://localhost:9200/_cluster/health

# Verify architecture
docker image inspect elasticsearch | grep -i architecture
```

### 3. Cassandra ✅ **Multi-Arch Support**

**Recommended Method:** Docker Multi-Architecture Image

```bash
sudo ./services/cassandra/deploy.sh
```

**ARM64 Optimizations:**
```bash
# ARM64-optimized heap settings
export MAX_HEAP_SIZE="2G"
export HEAP_NEWSIZE="512M"

# Performance-tuned deployment
docker run -d \
    --name cassandra \
    --platform=linux/arm64 \
    --restart unless-stopped \
    --network btpi-core-network \
    -p 9042:9042 \
    -e "MAX_HEAP_SIZE=${MAX_HEAP_SIZE}" \
    -e "HEAP_NEWSIZE=${HEAP_NEWSIZE}" \
    -e "CASSANDRA_CLUSTER_NAME=btpi-cluster" \
    -e "JVM_OPTS=-XX:+UseG1GC -XX:+UseStringDeduplication" \
    cassandra:4.1
```

**Performance Monitoring:**
```bash
# Check cluster status
docker exec cassandra nodetool status

# Monitor performance
docker exec cassandra nodetool info

# Test connectivity
docker exec cassandra cqlsh -e "SELECT release_version FROM system.local;"
```

### 4. Portainer ✅ **Multi-Arch Support**

**Recommended Method:** Docker Multi-Architecture Image

```bash
sudo ./services/portainer/deploy.sh
```

**ARM64-Specific Deployment:**
```bash
docker run -d \
    --name portainer \
    --platform=linux/arm64 \
    --restart unless-stopped \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
```

**Validation:**
```bash
# Test web interface
curl -k https://localhost:9443/

# Verify container architecture
docker image inspect portainer/portainer-ce:latest | grep Architecture
```

### 5. Wazuh Indexer ⚠️ **Limited ARM64 Support**

**Primary Method:** Docker with Platform Emulation

```bash
# Check ARM64 native support first
docker manifest inspect wazuh/wazuh-indexer:4.9.0

# Deploy with emulation if needed
sudo ./services/wazuh-indexer/deploy.sh
```

**Alternative Method:** OpenSearch Alternative
```bash
# Use OpenSearch as ARM64-compatible alternative
docker run -d \
    --name wazuh-indexer \
    --platform=linux/arm64 \
    --restart unless-stopped \
    --network btpi-wazuh-network \
    -p 9400:9200 \
    -e "discovery.type=single-node" \
    -e "DISABLE_SECURITY_PLUGIN=true" \
    opensearchproject/opensearch:2.11.1
```

**Configuration Updates:**
```bash
# Update service script to use OpenSearch
sed -i 's/wazuh\/wazuh-indexer:4.9.0/opensearchproject\/opensearch:2.11.1/' \
    services/wazuh-indexer/deploy.sh

# Disable security for initial testing
echo 'DISABLE_SECURITY_PLUGIN=true' >> config/.env
```

### 6. Wazuh Manager ⚠️ **Limited ARM64 Support**

**Primary Method:** x86_64 with Emulation

```bash
# Check native ARM64 support
docker manifest inspect wazuh/wazuh-manager:4.9.0

# Deploy with x86_64 emulation
docker run -d \
    --name wazuh-manager \
    --platform=linux/amd64 \
    --restart unless-stopped \
    --network btpi-wazuh-network \
    -p 55000:55000 \
    -p 1514:1514/udp \
    -p 1515:1515 \
    wazuh/wazuh-manager:4.9.0
```

**Performance Considerations:**
- Emulation adds ~15-25% performance overhead
- Monitor CPU usage closely
- Consider native compilation for production

**Alternative:** Native Package Installation
```bash
# Install Wazuh repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
echo "deb https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
apt update

# Install Wazuh Manager (check ARM64 package availability)
apt install wazuh-manager
```

---

## Deployment Strategies by Use Case

### Strategy 1: Full ARM64 Deployment (Recommended)

**For systems with sufficient resources (32GB+ RAM, 16+ cores)**

```bash
# 1. Deploy core services natively
sudo ./services/elasticsearch/deploy.sh    # ARM64 Docker
sudo ./services/cassandra/deploy.sh        # ARM64 Docker
sudo ./services/velociraptor/deploy.sh     # ARM64 Native

# 2. Deploy management tools
sudo ./services/portainer/deploy.sh        # ARM64 Docker

# 3. Deploy Wazuh stack with alternatives
# Use OpenSearch instead of Wazuh Indexer
# Use Wazuh Manager with emulation if needed

# 4. Monitor deployment
./scripts/testing/monitor-arm64-services.sh -c -a -p
```

### Strategy 2: Hybrid Deployment (Balanced)

**For systems with moderate resources (16-32GB RAM)**

```bash
# 1. Core services with reduced memory
export ES_JAVA_OPTS="-Xms256m -Xmx512m"
export MAX_HEAP_SIZE="1G"
sudo ./services/elasticsearch/deploy.sh
sudo ./services/cassandra/deploy.sh

# 2. Essential security tools only
sudo ./services/velociraptor/deploy.sh

# 3. Skip resource-intensive services initially
# Add Wazuh stack later if needed

# 4. Monitor resource usage
./scripts/testing/monitor-arm64-services.sh -p
```

### Strategy 3: Minimal Deployment (Resource-Constrained)

**For systems with limited resources (<16GB RAM)**

```bash
# 1. Deploy only essential services
sudo ./services/velociraptor/deploy.sh     # DFIR platform
sudo ./services/portainer/deploy.sh        # Container management

# 2. Use external Elasticsearch/storage
# Configure services to use remote storage

# 3. Monitor closely
./scripts/testing/monitor-arm64-services.sh -i 10 -c
```

---

## Performance Optimization

### JVM Tuning for ARM64

```bash
# Elasticsearch ARM64 optimization
export ES_JAVA_OPTS="-Xms512m -Xmx2g \
    -XX:+UseG1GC \
    -XX:+UseStringDeduplication \
    -XX:G1HeapRegionSize=16m \
    -XX:+DisableExplicitGC"

# Cassandra ARM64 optimization  
export JVM_OPTS="-server \
    -XX:+UseG1GC \
    -XX:+UseStringDeduplication \
    -XX:MaxGCPauseMillis=200 \
    -XX:+ParallelRefProcEnabled"
```

### Container Resource Limits

```bash
# Conservative limits for ARM64
docker update --memory=1g --cpus=2.0 elasticsearch
docker update --memory=2g --cpus=2.0 cassandra
docker update --memory=512m --cpus=1.0 portainer
```

### System-Level Optimizations

```bash
# Optimize kernel parameters for ARM64
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
echo 'vm.swappiness=10' >> /etc/sysctl.conf
echo 'net.core.somaxconn=32768' >> /etc/sysctl.conf
sysctl -p

# Enable cgroup v2 for better resource management
echo 'GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"' >> /etc/default/grub
update-grub
```

---

## Testing and Validation

### Automated Testing

```bash
# Run comprehensive ARM64 deployment test
sudo ./scripts/testing/test-arm64-deployment.sh > deployment-report.log 2>&1

# View results
cat deployment-report.log | grep -E "(SUCCESS|FAILED|✅|❌)"
```

### Manual Validation Checklist

#### ✅ Platform Detection
```bash
# Verify platform detection works
./scripts/core/detect-platform.sh
export | grep BTPI_

# Expected output:
# BTPI_ARCH=aarch64
# BTPI_PLATFORM=arm64
# BTPI_DOCKER_PLATFORM=linux/arm64
```

#### ✅ Docker Multi-Arch Support
```bash
# Test Docker buildx
docker buildx version

# Test ARM64 container support
docker run --rm --platform=linux/arm64 hello-world

# Test x86_64 emulation fallback
docker run --rm --platform=linux/amd64 hello-world
```

#### ✅ Service Health Checks
```bash
# Elasticsearch
curl -f http://localhost:9200/_cluster/health
curl -f http://localhost:9200/_cat/nodes

# Cassandra
docker exec cassandra cqlsh -e "SELECT release_version FROM system.local;"
docker exec cassandra nodetool status

# Velociraptor
curl -k https://localhost:8889/
systemctl status velociraptor

# Portainer
curl -k https://localhost:9443/

# Wazuh Indexer (if deployed)
curl -f http://localhost:9400/_cluster/health
```

#### ✅ Service Integration Tests
```bash
# Test service communication
docker exec elasticsearch curl -f http://cassandra:9042
docker exec wazuh-manager curl -f http://wazuh-indexer:9200/_cluster/health

# Test data operations
curl -X PUT "localhost:9200/test-index" -H 'Content-Type: application/json' -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  }
}'

# Cleanup test data
curl -X DELETE "localhost:9200/test-index"
```

### Performance Benchmarking

```bash
# Run performance monitoring
./scripts/testing/monitor-arm64-services.sh -p > performance-baseline.log &

# Load testing (basic)
for i in {1..100}; do
    curl -s http://localhost:9200/_cluster/health > /dev/null
done

# Stop monitoring
pkill -f monitor-arm64-services.sh

# Analyze performance data
grep -E "(CPU Usage|Memory Usage|Response Time)" performance-baseline.log
```

---

## Troubleshooting

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Platform Detection Failed** | Wrong architecture detected | Manual export: `export BTPI_PLATFORM=arm64` |
| **Docker Image Not Found** | "no matching manifest" error | Use `--platform=linux/amd64` for fallback |
| **High Memory Usage** | OOM kills, slow performance | Reduce JVM heap sizes, add swap |
| **Service Won't Start** | Container exits immediately | Check logs: `docker logs <service>` |
| **Port Conflicts** | "address already in use" | Check: `sudo netstat -tlpn | grep <port>` |

### Detailed Troubleshooting

For comprehensive troubleshooting guide, see: [ARM64_TROUBLESHOOTING_GUIDE.md](ARM64_TROUBLESHOOTING_GUIDE.md)

### Debug Information Collection

```bash
# System information
uname -a > debug-info.txt
cat /proc/cpuinfo | head -20 >> debug-info.txt
free -h >> debug-info.txt
df -h >> debug-info.txt

# Docker information
docker version >> debug-info.txt
docker system info >> debug-info.txt
docker images >> debug-info.txt
docker ps -a >> debug-info.txt

# Service status
systemctl status velociraptor >> debug-info.txt
docker logs elasticsearch --tail=50 >> debug-info.txt
docker logs cassandra --tail=50 >> debug-info.txt

# Network information
docker network ls >> debug-info.txt
netstat -tlpn >> debug-info.txt
```

---

## Production Deployment

### Pre-Production Checklist

#### ✅ Infrastructure Readiness
- [ ] ARM64 system meets minimum requirements
- [ ] Docker with multi-arch support installed
- [ ] QEMU emulation configured for fallbacks
- [ ] Network ports available and configured
- [ ] SSL certificates generated and valid

#### ✅ Security Configuration
- [ ] Change default passwords
- [ ] Configure authentication properly
- [ ] Enable TLS/SSL for all services
- [ ] Configure firewall rules
- [ ] Set up log aggregation

#### ✅ Performance Optimization
- [ ] JVM parameters tuned for ARM64
- [ ] Container resource limits set
- [ ] System kernel parameters optimized
- [ ] Monitoring and alerting configured

#### ✅ Backup and Recovery
- [ ] Data backup strategy defined
- [ ] Configuration backup automated
- [ ] Recovery procedures tested
- [ ] Documentation updated

### Monitoring Setup

```bash
# Set up continuous monitoring
./scripts/testing/monitor-arm64-services.sh -c -a -p > /dev/null 2>&1 &

# Configure log rotation
cat > /etc/logrotate.d/btpi-react <<EOF
/home/demo/code/btpi-react/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
}
EOF

# Set up health check cron job
echo "*/5 * * * * /home/demo/code/btpi-react/scripts/testing/test-arm64-deployment.sh > /dev/null" | crontab -
```

### Scaling Considerations

#### Horizontal Scaling
- **Elasticsearch**: Deploy multi-node cluster with ARM64 nodes
- **Cassandra**: Add ARM64 nodes to existing cluster
- **Velociraptor**: Deploy multiple collectors with load balancer

#### Vertical Scaling
- **Memory**: ARM64 systems may benefit from higher RAM allocation
- **CPU**: Monitor CPU usage patterns and scale cores accordingly
- **Storage**: Use NVMe storage for optimal I/O performance

---

## ARM64 vs x86_64 Comparison

### Performance Characteristics

| Metric | ARM64 | x86_64 | Notes |
|--------|-------|---------|-------|
| **CPU Performance** | ~85-95% | 100% (baseline) | Workload dependent |
| **Memory Usage** | +10-20% | Baseline | JVM overhead |
| **Power Efficiency** | +30-50% | Baseline | Significant advantage |
| **Container Startup** | +20-30% time | Baseline | Multi-arch overhead |
| **Network Performance** | ~95-100% | Baseline | Minimal difference |

### Deployment Considerations

| Factor | ARM64 Impact | Mitigation |
|--------|-------------|-------------|
| **Image Availability** | Some images lack ARM64 support | Use emulation or alternatives |
| **Performance Overhead** | Emulation adds 15-25% overhead | Native compilation preferred |
| **Resource Requirements** | Higher memory usage | Adjust heap sizes accordingly |
| **Compatibility** | Some tools x86_64 only | Maintain fallback options |

---

## Future Improvements

### Planned Enhancements

1. **Native ARM64 Images**
   - Build custom ARM64 images for Wazuh components
   - Optimize Java applications for ARM64 architecture
   - Develop ARM64-specific performance profiles

2. **Automated Optimization**
   - Dynamic resource allocation based on ARM64 characteristics
   - Automatic fallback mechanisms for unsupported components
   - Performance monitoring with ARM64-specific metrics

3. **Enhanced Testing**
   - Comprehensive ARM64 integration test suite
   - Performance regression testing
   - Multi-architecture compatibility validation

### Community Contributions

We welcome contributions to improve ARM64 support:
- **Testing**: Validate deployments on different ARM64 systems
- **Optimization**: Share ARM64-specific performance tunings
- **Documentation**: Improve deployment guides and troubleshooting
- **Code**: Submit ARM64-compatible improvements

---

## Support and Resources

### Documentation
- [Main README](../README.md) - General BTPI-REACT documentation
- [ARM64 Troubleshooting Guide](ARM64_TROUBLESHOOTING_GUIDE.md) - Detailed problem solving
- [Architecture Overview](architecture/) - System architecture documentation

### Tools and Scripts
- `scripts/testing/test-arm64-deployment.sh` - Automated deployment testing
- `scripts/testing/monitor-arm64-services.sh` - Real-time service monitoring
- `scripts/core/detect-platform.sh` - Platform detection and configuration

### Getting Help
- **GitHub Issues**: Report ARM64-specific bugs or feature requests
- **Discussions**: Share ARM64 deployment experiences and tips
- **Professional Support**: Contact for enterprise ARM64 deployment assistance

---

*This guide is maintained as part of the BTPI-REACT project. For the latest updates and ARM64 compatibility information, check the project repository.*
