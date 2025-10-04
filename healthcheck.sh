#!/bin/bash
# Cassandra health check script

# Exit on error
set -e

# Basic connectivity check - specify host and port explicitly
cqlsh -h localhost -p 9042 -e "SELECT release_version FROM system.local;"
