#!/bin/bash
# Cassandra Deployment Script - Enhanced with robust health checking
# Version: 2.1.1 - Fixed connectivity and health check issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load environment with fallback
if [ -f "$PROJECT_ROOT/config/.env" ]; then
    source "$PROJECT_ROOT/config/.env"
else
    echo "Environment file not found. Run the main deployment script first."
    exit 1
fi

echo "🗄️ Deploying Cassandra with enhanced health checking..."

# Create data directories with proper permissions
mkdir -p "$PROJECT_ROOT/data/cassandra/data"
mkdir -p "$PROJECT_ROOT/data/cassandra/logs"
mkdir -p "$PROJECT_ROOT/data/cassandra/commitlog"
mkdir -p "$PROJECT_ROOT/data/cassandra/saved_caches"
mkdir -p "$PROJECT_ROOT/data/cassandra/hints"

# Set proper ownership (cassandra user in container has UID 999)
sudo chown -R 999:999 "$PROJECT_ROOT/data/cassandra" 2>/dev/null || chmod -R 777 "$PROJECT_ROOT/data/cassandra"

# Check if Cassandra container already exists and is healthy
if docker ps --format "{{.Names}}" | grep -q "^cassandra$"; then
    echo "📋 Cassandra container already exists, checking health..."

    # Check if it's responding properly
    if docker exec cassandra bash -c "netstat -ln | grep -q :9042" 2>/dev/null && \
       docker exec cassandra cqlsh -e "SELECT release_version FROM system.local;" >/dev/null 2>&1; then
        echo "✅ Cassandra is already healthy and responding"
        echo "🔗 Cassandra available at: ${SERVER_IP:-localhost}:9042"
        echo "🔧 Cluster: btpi-cluster"
        exit 0
    else
        echo "⚠️ Cassandra container exists but is not healthy, restarting..."
        docker restart cassandra
        sleep 30

        # Check again after restart
        if docker exec cassandra cqlsh -e "SELECT release_version FROM system.local;" >/dev/null 2>&1; then
            echo "✅ Cassandra restarted successfully"
            exit 0
        else
            echo "❌ Cassandra restart failed, will redeploy"
            docker stop cassandra 2>/dev/null || true
            docker rm cassandra 2>/dev/null || true
        fi
    fi
elif docker ps -a --format "{{.Names}}" | grep -q "^cassandra$"; then
    echo "🔄 Cassandra container exists but is not running, starting..."
    docker start cassandra
    sleep 30

    # Check if it's working after start
    if docker exec cassandra cqlsh -e "SELECT release_version FROM system.local;" >/dev/null 2>&1; then
        echo "✅ Cassandra started successfully"
        exit 0
    else
        echo "❌ Cassandra failed to start properly, will redeploy"
        docker stop cassandra 2>/dev/null || true
        docker rm cassandra 2>/dev/null || true
    fi
else
    echo "📦 No existing Cassandra container found, deploying new instance..."
fi

# Deploy Cassandra with enhanced configuration
docker run -d \
    --name cassandra \
    --restart unless-stopped \
    --network "${BTPI_CORE_NETWORK:-btpi-core-network}" \
    -p 9042:9042 \
    -p 7000:7000 \
    -e "CASSANDRA_CLUSTER_NAME=btpi-cluster" \
    -e "CASSANDRA_DC=datacenter1" \
    -e "CASSANDRA_RACK=rack1" \
    -e "CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch" \
    -e "CASSANDRA_NUM_TOKENS=128" \
    -e "CASSANDRA_SEEDS=cassandra" \
    -e "CASSANDRA_START_RPC=true" \
    -e "MAX_HEAP_SIZE=2G" \
    -e "HEAP_NEWSIZE=512M" \
    -v "$PROJECT_ROOT/data/cassandra/data:/var/lib/cassandra" \
    -v "$PROJECT_ROOT/data/cassandra/logs:/var/log/cassandra" \
    -v "$PROJECT_ROOT/data/cassandra/commitlog:/var/lib/cassandra/commitlog" \
    -v "$PROJECT_ROOT/data/cassandra/saved_caches:/var/lib/cassandra/saved_caches" \
    -v "$PROJECT_ROOT/data/cassandra/hints:/var/lib/cassandra/hints" \
    --health-cmd="cqlsh -e 'SELECT release_version FROM system.local;'" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=10 \
    --health-start-period=120s \
    cassandra:4.1

echo "✅ Cassandra container deployed"
echo "⏳ Waiting for Cassandra to be ready (this may take up to 3 minutes)..."

# Enhanced health checking with retry logic
wait_for_cassandra() {
    local max_attempts=30
    local attempt=1
    local wait_time=10

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Checking Cassandra readiness..."

        # Check if container is running
        if ! docker ps --format "{{.Names}}" | grep -q "^cassandra$"; then
            echo "❌ Cassandra container is not running"
            return 1
        fi

        # Check if port is listening
        if ! docker exec cassandra bash -c "netstat -ln | grep -q :9042" 2>/dev/null; then
            echo "⏳ Cassandra port not ready yet, waiting ${wait_time}s..."
            sleep $wait_time
            ((attempt++))
            continue
        fi

        # Try basic CQL connection
        if docker exec cassandra cqlsh -e "SELECT release_version FROM system.local;" >/dev/null 2>&1; then
            echo "✅ Cassandra is ready and accepting connections"
            return 0
        fi

        echo "⏳ Cassandra starting up, waiting ${wait_time}s..."
        sleep $wait_time
        ((attempt++))
    done

    echo "❌ Cassandra failed to become ready within $((max_attempts * wait_time)) seconds"
    return 1
}

# Wait for Cassandra with enhanced checking
if wait_for_cassandra; then
    echo "🗄️ Testing Cassandra read/write functionality..."

    # Test keyspace creation and basic operations
    if docker exec cassandra cqlsh -e "
        CREATE KEYSPACE IF NOT EXISTS test_keyspace
        WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

        USE test_keyspace;

        CREATE TABLE IF NOT EXISTS test_table (
            id UUID PRIMARY KEY,
            name TEXT,
            created_at TIMESTAMP
        );

        INSERT INTO test_table (id, name, created_at)
        VALUES (uuid(), 'test_connection', toTimestamp(now()));

        SELECT COUNT(*) FROM test_table;

        DROP TABLE test_table;
        DROP KEYSPACE test_keyspace;
    " >/dev/null 2>&1; then
        echo "✅ Cassandra read/write test passed"
        echo "🔗 Cassandra available at: ${SERVER_IP:-localhost}:9042"
        echo "🔧 Cluster: btpi-cluster"
        exit 0
    else
        echo "❌ Cassandra read/write test failed"
        echo "🔍 Container logs:"
        docker logs --tail=20 cassandra
        exit 1
    fi
else
    echo "❌ Cassandra deployment failed"
    echo "🔍 Container status:"
    docker ps -a | grep cassandra || echo "No cassandra container found"
    echo "🔍 Container logs:"
    docker logs --tail=20 cassandra 2>/dev/null || echo "Could not retrieve logs"
    exit 1
fi
