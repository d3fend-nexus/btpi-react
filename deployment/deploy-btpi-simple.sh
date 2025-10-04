#!/bin/bash

# BTPI-REACT Simple Deployment Script
# Generates necessary environment variables for deployment

# Generate random secrets for services
WAZUH_API_PASSWORD=$(openssl rand -base64 16)
WAZUH_CLUSTER_KEY=$(openssl rand -base64 32)
VELOCIRAPTOR_CLIENT_API_KEY=$(openssl rand -hex 32)
VELOCIRAPTOR_FRONTEND_PASSWORD=$(openssl rand -base64 16)
KASM_DEFAULT_PASSWORD=$(openssl rand -base64 16)
PORTAINER_ADMIN_PASSWORD=$(openssl rand -base64 16)

# Export variables for use in deployment
export WAZUH_API_PASSWORD
export WAZUH_CLUSTER_KEY
export VELOCIRAPTOR_CLIENT_API_KEY
export VELOCIRAPTOR_FRONTEND_PASSWORD
export KASM_DEFAULT_PASSWORD
export PORTAINER_ADMIN_PASSWORD

echo "Environment variables generated for BTPI-REACT deployment"
echo "Passwords and keys have been securely generated"
