#!/bin/bash
# Fix deployment scripts to show live output in terminal
# This script removes output suppression and adds verbose flags

set -euo pipefail

echo "Fixing deployment scripts to show live output..."

# Function to fix a deployment script
fix_deployment_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")

    if [ ! -f "$script_path" ]; then
        echo "Warning: $script_path not found"
        return
    fi

    echo "Fixing $script_name..."

    # Create a backup
    cp "$script_path" "${script_path}.bak"

    # Fix the script using sed
    # 1. Remove all output suppressions (>/dev/null 2>&1)
    sed -i 's/>[[:space:]]*\/dev\/null[[:space:]]*2>&1//g' "$script_path"
    sed -i 's/2>[[:space:]]*\/dev\/null//g' "$script_path"
    sed -i 's/>[[:space:]]*\/dev\/null//g' "$script_path"

    # 2. Make curl commands verbose (add -v flag)
    sed -i 's/curl -s/curl -v/g' "$script_path"
    sed -i 's/curl -k -s/curl -k -v/g' "$script_path"

    # 3. Fix docker run commands to show progress
    # Add --progress=plain to show build/pull progress
    sed -i '/docker run -d/s/docker run -d/docker run --progress=plain -d/g' "$script_path"

    # 4. Make docker exec commands show output
    sed -i 's/docker exec \([^ ]*\) cqlsh/docker exec -t \1 cqlsh/g' "$script_path"

    # 5. Add echo statements before silent operations
    # Add visibility to wait operations
    sed -i 's/sleep \([0-9]*\)/echo "Waiting \1 seconds..." \&\& sleep \1/g' "$script_path"

    echo "Fixed $script_name"
}

# Fix all database service deployment scripts
echo "=== Fixing Database Service Scripts ==="
fix_deployment_script "services/elasticsearch/deploy.sh"
fix_deployment_script "services/cassandra/deploy.sh"
fix_deployment_script "services/wazuh-indexer/deploy.sh"

# Fix infrastructure service scripts
echo "=== Fixing Infrastructure Service Scripts ==="
fix_deployment_script "services/kasm/deploy.sh"
fix_deployment_script "services/portainer/deploy.sh"

# Fix security service scripts
echo "=== Fixing Security Service Scripts ==="
# TheHive and Cortex deployment scripts removed
fix_deployment_script "services/velociraptor/deploy.sh"
fix_deployment_script "services/wazuh-manager/deploy.sh"

# Also fix the main deployment script to show more output
echo "=== Fixing Main Deployment Script ==="
if [ -f "deployment/fresh-btpi-react.sh" ]; then
    cp "deployment/fresh-btpi-react.sh" "deployment/fresh-btpi-react.sh.bak"

    # Add verbose docker commands
    sed -i 's/docker ps/docker ps -a/g' "deployment/fresh-btpi-react.sh"
    sed -i 's/docker network create/docker network create --verbose/g' "deployment/fresh-btpi-react.sh"

    # Make the deploy_service function more verbose
    sed -i '/^deploy_service() {/a\    echo "[DEPLOY] Starting deployment of service: $1"' "deployment/fresh-btpi-react.sh"
    sed -i '/bash.*deploy.sh/i\    echo "[DEPLOY] Executing deployment script: $SERVICES_DIR/$service/deploy.sh"' "deployment/fresh-btpi-react.sh"

    echo "Fixed fresh-btpi-react.sh"
fi

# Fix common-utils.sh to show more debug output by default
echo "=== Fixing Common Utils Script ==="
if [ -f "scripts/common-utils.sh" ]; then
    cp "scripts/common-utils.sh" "scripts/common-utils.sh.bak"

    # Enable debug mode by default during deployment
    sed -i 's/DEBUG:-false/DEBUG:-true/g' "scripts/common-utils.sh"

    # Make wait_for_service more verbose
    sed -i '/^wait_for_service() {/a\    echo "[WAIT] Waiting for service: $1 (max ${2:-120}s)"' "scripts/common-utils.sh"

    echo "Fixed common-utils.sh"
fi

echo ""
echo "=== All scripts fixed! ==="
echo ""
echo "The following changes were made:"
echo "1. Removed all output suppression (>/dev/null 2>&1)"
echo "2. Made curl commands verbose (-v flag)"
echo "3. Added progress indicators to Docker commands"
echo "4. Added echo statements for wait operations"
echo "5. Enabled debug mode in common-utils.sh"
echo ""
echo "Backup files created with .bak extension"
echo ""
echo "You can now run the deployment and see all live output:"
echo "  sudo bash deployment/fresh-btpi-react.sh"
echo ""
