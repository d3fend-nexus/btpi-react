#!/bin/bash
# Cassandra health check script

# Exit on error but don't require keyspaces yet
set -e

# Basic connectivity check only - specify host and port explicitly
# This is what we need for basic health validation
cqlsh -h localhost -p 9042 -e "SELECT release_version FROM system.local;" > /dev/null 2>&1

# NOTE: Keyspace validation is now a separate step and should not be part of
# the basic healthcheck since keyspaces are created after container is healthy
# The commented line below would be used during application validation, not container health
