#!/bin/bash
# Test script to verify Dockerfile fixes

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Testing Dockerfile Fix${NC}"
echo "================================"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test 1: Check if all installation scripts exist
echo -e "${YELLOW}Test 1: Checking installation scripts...${NC}"

scripts_to_check=(
    "scripts/install_portainer.sh"
    "scripts/install_kasm.sh"
    "scripts/install_grr.sh"
    "scripts/install_wazuh.sh"
)

all_exist=true
for script in "${scripts_to_check[@]}"; do
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
        echo -e "${GREEN}✓ $script exists${NC}"
    else
        echo -e "${RED}✗ $script not found${NC}"
        all_exist=false
    fi
done

if ! $all_exist; then
    echo -e "${RED}Missing required scripts!${NC}"
    exit 1
fi

# Test 2: Check if Dockerfile uses COPY commands instead of curl
echo ""
echo -e "${YELLOW}Test 2: Checking Dockerfile uses COPY commands...${NC}"

if grep -q "COPY scripts/install_portainer.sh" "$SCRIPT_DIR/Dockerfile"; then
    echo -e "${GREEN}✓ Portainer uses COPY command${NC}"
else
    echo -e "${RED}✗ Portainer still using curl${NC}"
    exit 1
fi

if grep -q "COPY scripts/install_kasm.sh" "$SCRIPT_DIR/Dockerfile"; then
    echo -e "${GREEN}✓ Kasm uses COPY command${NC}"
else
    echo -e "${RED}✗ Kasm still using curl${NC}"
    exit 1
fi

if grep -q "COPY scripts/install_grr.sh" "$SCRIPT_DIR/Dockerfile"; then
    echo -e "${GREEN}✓ GRR uses COPY command${NC}"
else
    echo -e "${RED}✗ GRR still using curl${NC}"
    exit 1
fi

if grep -q "COPY scripts/install_wazuh.sh" "$SCRIPT_DIR/Dockerfile"; then
    echo -e "${GREEN}✓ Wazuh uses COPY command${NC}"
else
    echo -e "${RED}✗ Wazuh still using curl${NC}"
    exit 1
fi

# Test 3: Check for bad URLs
echo ""
echo -e "${YELLOW}Test 3: Checking for problematic URLs...${NC}"

bad_urls=(
    "https://raw.githubusercontent.com/cmndcntrlcyber/btpi-react/refs/heads/main/grr/install_grr.sh"
    "https://raw.githubusercontent.com/cmndcntrlcyber/btpi-react/refs/heads/main/kasm/install_kasm.sh"
    "https://github.com/cmndcntrlcyber/btpi-nexus/grr/install_grr.sh"
    "https://raw.githubusercontent.com/cmndcntrlcyber/btpi-react/refs/heads/main/wazuh/install_wazuh.sh"
)

has_bad_urls=false
for url in "${bad_urls[@]}"; do
    if grep -q "$url" "$SCRIPT_DIR/Dockerfile"; then
        echo -e "${RED}✗ Found problematic URL: $url${NC}"
        has_bad_urls=true
    fi
done

if ! $has_bad_urls; then
    echo -e "${GREEN}✓ No problematic URLs found${NC}"
else
    echo -e "${RED}Problematic URLs still exist in Dockerfile${NC}"
    exit 1
fi

# Test 4: Check script permissions
echo ""
echo -e "${YELLOW}Test 4: Making scripts executable...${NC}"

for script in "${scripts_to_check[@]}"; do
    chmod +x "$SCRIPT_DIR/$script"
    echo -e "${GREEN}✓ Made $script executable${NC}"
done

# Summary
echo ""
echo "================================"
echo -e "${GREEN}Summary:${NC}"
echo -e "${GREEN}✓ All installation scripts created${NC}"
echo -e "${GREEN}✓ Dockerfile updated to use COPY commands${NC}"
echo -e "${GREEN}✓ No problematic URLs remain${NC}"
echo -e "${GREEN}✓ Scripts are executable${NC}"
echo ""
echo -e "${GREEN}The Dockerfile has been successfully fixed!${NC}"
echo ""
echo "You can now build the Docker image with:"
echo "  cd $SCRIPT_DIR"
echo "  docker build -t btpi-nexus ."
