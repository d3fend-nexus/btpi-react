# ARM64 Troubleshooting Guide for BTPI-REACT

This guide provides comprehensive troubleshooting steps for common ARM64 deployment issues in BTPI-REACT.

## Quick Reference

### ⚡ Quick Commands

```bash
# Test ARM64 deployment
sudo ./scripts/testing/test-arm64-deployment.sh

# Monitor ARM64 services
./scripts/testing/monitor-arm64-services.sh -c -a -p

# Check platform detection
./scripts/core/detect-platform.sh

# Generate platform config
./scripts/core/detect-platform.sh --generate-config platform.env
```

---

## Platform Detection Issues

### Issue: Platform Detection Fails
**Symptoms:**
- Error: "Platform detection failed"
- Incorrect BTPI_PLATFORM variable
- Scripts defaulting to x86_64

**Solutions:**
```bash
# Manual platform detection
export BTPI_ARCH=$(uname -m)
export BTPI_PLATFORM=$(echo $BTPI_ARCH | sed 's/aarch64/arm64/; s/x86_64/amd64/')

# Verify architecture
uname -m
# Should show: aarch64 (ARM64) or x86_64 (Intel/AMD)

# Check platform detection script
bash -x ./scripts/core/detect-platform.sh
```

### Issue: Docker Platform Mismatch
**Symptoms:**
- Containers fail to start
- "no matching manifest for linux/arm64" errors
- Platform warnings in logs

**Solutions:**
```bash
# Check Docker buildx support
docker buildx version

# Install QEMU emulation (if needed)
sudo apt-get update
sudo apt-get install -y qemu-user-static binfmt-support

# Test multi-arch support
docker run --rm --platform=linux/arm64 hello-world

# Force platform for specific containers
docker run --platform=linux/arm64 <image>
```

---

## Service-Specific Issues

### Velociraptor

#### Issue: ARM64 Binary Download Fails
**Symptoms:**
- "Binary not functional" errors
- Download timeout or 404 errors
- Velociraptor won't start

**Solutions:**
```bash
# Manual binary download
curl -L -o /opt/velociraptor/bin/velociraptor \
  https://github.com/Velocidex/velociraptor/releases/download/v0.75/velociraptor-v0.75.2-linux-arm64

# Verify binary architecture
file /opt/velociraptor/bin/velociraptor
# Should show: ELF 64-bit LSB executable, ARM aarch64

# Test binary directly
/opt/velociraptor/bin/velociraptor version

# Fallback to Docker deployment
export VELOCIRAPTOR_DEPLOYMENT_METHOD=docker
./services/velociraptor/deploy.sh
```

#### Issue: Systemd Service Won't Start
**Symptoms:**
- Service fails to start
- "Permission denied" errors
- Configuration file issues

**Solutions:**
```bash
# Check service status
systemctl status velociraptor

# Check service logs
journalctl -u velociraptor -f

# Fix permissions
chmod +x /opt/velociraptor/bin/velociraptor
chown root:root /opt/velociraptor/bin/velociraptor

# Test configuration
/opt/velociraptor/bin/velociraptor --config /path/to/config --help

# Restart service
systemctl restart velociraptor
```

### Elasticsearch

#### Issue: Container Won't Start on ARM64
**Symptoms:**
- Container exits immediately
- "no matching manifest" errors
- Java heap issues

**Solutions:**
```bash
# Use explicit platform tag
docker run --platform=linux/arm64 \
  docker.elastic.co/elasticsearch/elasticsearch:8.15.3

# Check available image architectures
docker manifest inspect docker.elastic.co/elasticsearch/elasticsearch:8.15.3

# Adjust JVM heap for ARM64
export ES_JAVA_OPTS="-Xms256m -Xmx512m"

# Try older version with confirmed ARM64 support
docker run --platform=linux/arm64 \
  docker.elastic.co/elasticsearch/elasticsearch:8.10.4
```

#### Issue: Memory Issues on ARM64
**Symptoms:**
- OutOfMemoryError
- Container killed by OOM killer
- Slow performance

**Solutions:**
```bash
# Reduce memory allocation
export ES_JAVA_OPTS="-Xms256m -Xmx512m"

# Check system memory
free -h

# Monitor memory usage
docker stats elasticsearch

# Use memory-efficient settings
echo "cluster.routing.allocation.disk.watermark.low: 90%
cluster.routing.allocation.disk.watermark.high: 95%
indices.memory.index_buffer_size: 5%" >> elasticsearch.yml
```

### Wazuh Stack

#### Issue: Wazuh Indexer ARM64 Compatibility
**Symptoms:**
- "unsupported architecture" errors
- Container fails to pull
- OpenSearch conflicts

**Solutions:**
```bash
# Check Wazuh 4.9.0 ARM64 availability
docker manifest inspect wazuh/wazuh-indexer:4.9.0

# Use alternative OpenSearch image
docker run --platform=linux/arm64 \
  opensearchproject/opensearch:2.11.1

# Update deployment script
sed -i 's/wazuh\/wazuh-indexer:4.9.0/opensearchproject\/opensearch:2.11.1/' \
  services/wazuh-indexer/deploy.sh

# Disable security plugin for testing
export DISABLE_SECURITY_PLUGIN=true
```

#### Issue: Wazuh Manager ARM64 Support
**Symptoms:**
- Manager container won't start
- Agent communication failures
- API accessibility issues

**Solutions:**
```bash
# Check Wazuh Manager ARM64 support
docker manifest inspect wazuh/wazuh-manager:4.9.0

# Use x86_64 with emulation if no ARM64 support
docker run --platform=linux/amd64 wazuh/wazuh-manager:4.9.0

# Alternative: Build from source
git clone https://github.com/wazuh/wazuh.git
cd wazuh
# Follow ARM64 build instructions

# Test API accessibility
curl -k -u wazuh:wazuh https://localhost:55000/
```

### Cassandra

#### Issue: Performance Issues on ARM64
**Symptoms:**
- Slow startup times
- High CPU usage
- Connection timeouts

**Solutions:**
```bash
# Optimize heap settings for ARM64
export MAX_HEAP_SIZE="1G"
export HEAP_NEWSIZE="256M"

# Use ARM64-optimized GC settings
export JVM_OPTS="-XX:+UseG1GC -XX:+UseStringDeduplication"

# Monitor performance
docker exec cassandra nodetool info

# Check cluster status
docker exec cassandra nodetool status
```

### Portainer

#### Issue: Multi-arch Image Issues
**Symptoms:**
- Web interface inaccessible
- ARM64 platform warnings
- Container restart loops

**Solutions:**
```bash
# Use explicit multi-arch image
docker run --platform=linux/arm64 portainer/portainer-ce:latest

# Check image architecture
docker image inspect portainer/portainer-ce:latest | grep -i arch

# Alternative: Use Portainer Agent + Server model
docker run -d portainer/agent:latest
docker run -d portainer/portainer-ce:latest
```

---

## Docker Issues

### Issue: Multi-architecture Support Missing
**Symptoms:**
- "no matching manifest" errors
- Platform warnings
- Containers won't start

**Solutions:**
```bash
# Enable Docker experimental features
echo '{"experimental": true}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker

# Install buildx plugin
sudo apt-get update
sudo apt-get install -y docker-buildx-plugin

# Set up QEMU emulation
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Test emulation
docker run --rm --platform=linux/arm64 arm64v8/alpine uname -m
```

### Issue: Docker Daemon Issues on ARM64
**Symptoms:**
- Docker daemon won't start
- Permission errors
- Socket access issues

**Solutions:**
```bash
# Check Docker service status
systemctl status docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Reset Docker daemon
sudo systemctl restart docker

# Check daemon logs
journalctl -u docker.service -f

# Test Docker functionality
docker run --rm hello-world
```

---

## Network Issues

### Issue: Service Communication Failures
**Symptoms:**
- Services can't reach each other
- Network timeouts
- DNS resolution failures

**Solutions:**
```bash
# Check Docker networks
docker network ls
docker network inspect btpi-core-network

# Recreate networks
./scripts/network/cleanup-networks.sh
./scripts/network/setup-networks.sh

# Test connectivity
docker exec elasticsearch curl -f http://cassandra:9042
docker exec wazuh-manager curl -f http://wazuh-indexer:9200

# Check iptables/firewall
sudo iptables -L
sudo ufw status
```

### Issue: Port Conflicts
**Symptoms:**
- "port already in use" errors
- Services can't bind to ports
- Accessibility issues

**Solutions:**
```bash
# Check port usage
sudo netstat -tlpn | grep :9200
sudo ss -tlpn | grep :9200

# Kill processes using ports
sudo fuser -k 9200/tcp

# Use alternative ports
export ELASTICSEARCH_PORT=9201
export WAZUH_INDEXER_PORT=9401

# Update service configurations
sed -i 's/9200:9200/9201:9200/' services/elasticsearch/deploy.sh
```

---

## Performance Issues

### Issue: Slow Performance on ARM64
**Symptoms:**
- High response times
- CPU bottlenecks
- Memory pressure

**Solutions:**
```bash
# Monitor system performance
htop
iostat -x 1
vmstat 1

# Optimize JVM settings for ARM64
export JAVA_OPTS="-server -XX:+UseG1GC -XX:+UseStringDeduplication"

# Reduce service resource limits
docker update --memory=512m --cpus=1.0 elasticsearch

# Scale down non-critical services
docker-compose scale cassandra=1
```

### Issue: Memory Exhaustion
**Symptoms:**
- OOM killer activated
- Services crashing
- System becomes unresponsive

**Solutions:**
```bash
# Check memory usage
free -h
docker stats --no-stream

# Reduce heap sizes
export ES_JAVA_OPTS="-Xms256m -Xmx512m"
export CASSANDRA_MAX_HEAP_SIZE="512M"

# Enable swap (temporary fix)
sudo swapon --show
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Monitor memory usage
./scripts/testing/monitor-arm64-services.sh -c -p
```

---

## Common Error Messages

### `exec user process caused: exec format error`
**Cause:** Trying to run x86_64 binary on ARM64 system without emulation.
**Solution:**
```bash
# Install QEMU emulation
sudo apt-get install -y qemu-user-static binfmt-support

# Or use ARM64-compatible alternative
# Check image architecture before pulling
docker manifest inspect <image:tag>
```

### `no matching manifest for linux/arm64 in the manifest list`
**Cause:** Docker image doesn't support ARM64 architecture.
**Solution:**
```bash
# Use x86_64 image with emulation
docker run --platform=linux/amd64 <image>

# Find ARM64-compatible alternative
docker search <service>-arm64

# Build custom image
docker buildx build --platform=linux/arm64 .
```

### `velociraptor: cannot execute binary file: Exec format error`
**Cause:** Wrong architecture binary downloaded.
**Solution:**
```bash
# Download correct ARM64 binary
curl -L -o velociraptor \
  https://github.com/Velocidex/velociraptor/releases/download/v0.75/velociraptor-v0.75.2-linux-arm64

# Verify binary architecture
file velociraptor
```

---

## Testing and Validation

### Comprehensive Testing Script
```bash
# Run full ARM64 deployment test
sudo ./scripts/testing/test-arm64-deployment.sh

# Monitor services in real-time
./scripts/testing/monitor-arm64-services.sh -c -a -p

# Generate deployment report
./scripts/testing/test-arm64-deployment.sh > deployment-results.log 2>&1
```

### Manual Validation Steps
```bash
# 1. Check platform detection
./scripts/core/detect-platform.sh

# 2. Verify Docker multi-arch support
docker buildx ls
docker run --rm --platform=linux/arm64 hello-world

# 3. Test individual services
curl -f http://localhost:9200/_cluster/health  # Elasticsearch
curl -f http://localhost:9400/_cluster/health  # Wazuh Indexer
curl -k -f https://localhost:8889/             # Velociraptor
curl -k -f https://localhost:9443/             # Portainer

# 4. Check service logs
docker logs elasticsearch --tail=20
docker logs wazuh-indexer --tail=20
systemctl status velociraptor

# 5. Verify service integration
docker exec wazuh-manager curl -f http://wazuh-indexer:9200
```

---

## Getting Help

### Debug Information Collection
```bash
# Collect system information
uname -a > debug-info.txt
cat /proc/cpuinfo | grep -E "(Architecture|model name)" >> debug-info.txt
free -h >> debug-info.txt
docker version >> debug-info.txt
docker info >> debug-info.txt

# Collect service status
docker ps -a >> debug-info.txt
systemctl status velociraptor >> debug-info.txt

# Collect logs
sudo ./scripts/testing/test-arm64-deployment.sh > test-results.log 2>&1
```

### Performance Benchmarking
```bash
# Run performance tests
./scripts/testing/monitor-arm64-services.sh -p > performance.log

# Benchmark individual services
curl -w "@curl-format.txt" -o /dev/null http://localhost:9200/_cluster/health

# System resource monitoring
sar -u -r -d 1 60 > system-performance.log
```

### Support Resources
- **GitHub Issues**: Report ARM64-specific problems
- **Documentation**: Check latest ARM64 compatibility matrix
- **Community**: Share ARM64 deployment experiences
- **Professional Support**: Contact for enterprise ARM64 deployments

---

## Best Practices for ARM64

### 1. Resource Planning
- **Memory**: Allocate 20-30% more RAM than x86_64 equivalents
- **CPU**: ARM64 may require more CPU cores for equivalent performance
- **Storage**: SSD recommended for optimal I/O performance

### 2. Service Optimization
- **JVM Tuning**: Use ARM64-specific JVM parameters
- **Container Limits**: Set appropriate resource limits per service
- **Monitoring**: Implement continuous performance monitoring

### 3. Deployment Strategy
- **Staged Deployment**: Deploy and test services individually
- **Fallback Plan**: Keep x86_64 deployment option available
- **Regular Testing**: Use automated testing for ARM64 compatibility

### 4. Monitoring and Maintenance
- **Health Checks**: Implement comprehensive health monitoring
- **Log Aggregation**: Centralize logging for troubleshooting
- **Performance Metrics**: Track ARM64-specific performance indicators
- **Regular Updates**: Keep services updated for ARM64 improvements

---

*This guide is part of the BTPI-REACT ARM64 deployment toolkit. For the latest updates and additional troubleshooting resources, check the project documentation.*
