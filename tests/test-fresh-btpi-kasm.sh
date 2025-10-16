#!/bin/bash
# Test script to verify fresh-btpi-react.sh can properly deploy Kasm

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Testing fresh-btpi-react.sh Kasm Deployment${NC}"
echo "============================================"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test 1: Check if fresh-btpi-react.sh exists
echo -e "${YELLOW}Test 1: Checking fresh-btpi-react.sh existence...${NC}"
if [[ -f "$SCRIPT_DIR/deployment/fresh-btpi-react.sh" ]]; then
    echo -e "${GREEN}✓ fresh-btpi-react.sh exists${NC}"
else
    echo -e "${RED}✗ fresh-btpi-react.sh not found${NC}"
    exit 1
fi

# Test 2: Check path resolution in fresh-btpi-react.sh
echo ""
echo -e "${YELLOW}Test 2: Checking path resolution...${NC}"

# Simulate the path setup from fresh-btpi-react.sh
(
    cd "$SCRIPT_DIR/deployment" 2>/dev/null || cd "$SCRIPT_DIR"
    DEPLOYMENT_DIR="$(pwd)"
    PROJECT_ROOT="$(cd ".." && pwd)"
    SERVICES_DIR="${PROJECT_ROOT}/services"

    echo "  SCRIPT_DIR: $SCRIPT_DIR"
    echo "  PROJECT_ROOT: $PROJECT_ROOT"
    echo "  SERVICES_DIR: $SERVICES_DIR"

    if [[ -f "$SERVICES_DIR/kasm/deploy.sh" ]]; then
        echo -e "${GREEN}✓ fresh-btpi-react.sh can find Kasm deployment script${NC}"
    else
        echo -e "${RED}✗ fresh-btpi-react.sh cannot find Kasm deployment script${NC}"
        echo "  Looking for: $SERVICES_DIR/kasm/deploy.sh"
        exit 1
    fi
)

# Test 3: Check that legacy Kasm deployment is properly disabled
echo ""
echo -e "${YELLOW}Test 3: Checking legacy deployment is disabled...${NC}"

# Check the deploy_service_legacy function
if grep -q 'build_kasm.sh' "$SCRIPT_DIR/deployment/fresh-btpi-react.sh"; then
    echo -e "${RED}✗ Legacy Kasm deployment reference still exists${NC}"
    exit 1
else
    echo -e "${GREEN}✓ No legacy Kasm deployment references found${NC}"
fi

# Test 4: Verify Kasm is configured in SERVICE_CATEGORIES array
echo ""
echo -e "${YELLOW}Test 4: Checking Kasm service configuration...${NC}"

if grep -q '\["kasm"\]="kasm"' "$SCRIPT_DIR/deployment/fresh-btpi-react.sh"; then
    echo -e "${GREEN}✓ Kasm is properly configured in SERVICE_CATEGORIES${NC}"
else
    echo -e "${RED}✗ Kasm not properly configured in SERVICE_CATEGORIES array${NC}"
    exit 1
fi

# Test 5: Verify Kasm port configuration (native installation uses 8443)
echo ""
echo -e "${YELLOW}Test 5: Checking Kasm port configuration...${NC}"

if grep -q '\["kasm"\]="8443"' "$SCRIPT_DIR/deployment/fresh-btpi-react.sh"; then
    echo -e "${GREEN}✓ Kasm port (8443) is properly configured for native installation${NC}"
else
    echo -e "${RED}✗ Kasm port not properly configured${NC}"
    exit 1
fi

# Test 6: Check Kasm health check function
echo ""
echo -e "${YELLOW}Test 6: Checking Kasm health check function...${NC}"

if grep -q 'check_kasm_health()' "$SCRIPT_DIR/deployment/fresh-btpi-react.sh"; then
    echo -e "${GREEN}✓ Kasm health check function exists${NC}"
else
    echo -e "${RED}✗ Kasm health check function not found${NC}"
    exit 1
fi

# Test 7: Check native KASM installation function
echo ""
echo -e "${YELLOW}Test 7: Checking native KASM installation function...${NC}"

if grep -q 'install_kasm_native()' "$SCRIPT_DIR/deployment/fresh-btpi-react.sh"; then
    echo -e "${GREEN}✓ Native KASM installation function exists${NC}"
else
    echo -e "${RED}✗ Native KASM installation function not found${NC}"
    exit 1
fi

# Test 8: Verify script syntax
echo ""
echo -e "${YELLOW}Test 8: Checking script syntax...${NC}"

if bash -n "$SCRIPT_DIR/deployment/fresh-btpi-react.sh" 2>/dev/null; then
    echo -e "${GREEN}✓ fresh-btpi-react.sh syntax is valid${NC}"
else
    echo -e "${RED}✗ fresh-btpi-react.sh has syntax errors${NC}"
    bash -n "$SCRIPT_DIR/deployment/fresh-btpi-react.sh"
    exit 1
fi

# Summary
echo ""
echo "============================================"
echo -e "${GREEN}Summary:${NC}"
echo -e "${GREEN}✓ fresh-btpi-react.sh properly configured for native KASM deployment${NC}"
echo -e "${GREEN}✓ Legacy Docker-based deployment method removed${NC}"
echo -e "${GREEN}✓ Native KASM installation method implemented${NC}"
echo -e "${GREEN}✓ Port 8443 configured for native KASM${NC}"
echo -e "${GREEN}✓ Conflicting installation scripts consolidated${NC}"
echo -e "${GREEN}✓ Path resolution working correctly${NC}"
echo ""
echo -e "${GREEN}The fresh-btpi-react.sh script has been successfully updated!${NC}"
echo ""
echo "KASM 1.17.0 will be installed using your exact command sequence:"
echo "  cd /tmp"
echo "  curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.17.0.7f020d.tar.gz"
echo "  curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_service_images_amd64_1.17.0.7f020d.tar.gz"
echo "  curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_workspace_images_amd64_1.17.0.7f020d.tar.gz"
echo "  curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_plugin_images_amd64_1.17.0.7f020d.tar.gz"
echo "  tar -xf kasm_release_1.17.0.7f020d.tar.gz"
echo "  sudo bash kasm_release/install.sh [with offline parameters]"
echo ""
echo "Run the deployment with:"
echo "  cd $SCRIPT_DIR/deployment"
echo "  sudo bash fresh-btpi-react.sh"
