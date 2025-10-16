#!/bin/bash
# Fix deployment disruption by adding comprehensive error handling and debugging
# This script ensures the deployment continues even with failures and shows all errors

echo "Fixing deployment disruption issues..."

# Create a wrapper script for better error handling
cat > scripts/deployment-wrapper.sh << 'EOF'
#!/bin/bash
# Wrapper functions for deployment with verbose error handling

# Override the default error handler to show more information
verbose_error_handler() {
    local exit_code=$1
    local line_number=$2
    local bash_lineno=$3
    local last_command=$4

    echo "=============== ERROR DETECTED ==============="
    echo "Exit Code: $exit_code"
    echo "Line Number: $line_number"
    echo "Command: $last_command"
    echo "Script: ${BASH_SOURCE[1]}"
    echo "Function Stack: ${FUNCNAME[@]}"
    echo "=============================================="

    # Don't exit, just log the error
    return 0
}

# Function to safely execute commands with full debugging
safe_execute() {
    local cmd="$@"
    echo "[EXECUTE] Running: $cmd"

    # Execute with full output
    set +e  # Temporarily disable exit on error
    eval "$cmd"
    local result=$?
    set -e  # Re-enable exit on error

    if [ $result -ne 0 ]; then
        echo "[ERROR] Command failed with exit code $result: $cmd"
        return $result
    else
        echo "[SUCCESS] Command completed successfully"
        return 0
    fi
}

export -f verbose_error_handler
export -f safe_execute
EOF

chmod +x scripts/deployment-wrapper.sh

# Fix the deployment script to use better error handling
echo "=== Fixing deployment/fresh-btpi-react.sh ==="

# Create a patch for the deployment script
cat > /tmp/deployment-patch.sh << 'PATCH'
# Replace strict error handling with verbose error handling
sed -i '1,10s/set -euo pipefail/set -uo pipefail/' deployment/fresh-btpi-react.sh

# Add command tracing right after the shebang
sed -i '2a\
# Enable command tracing for debugging\
if [[ "${DEBUG_TRACE:-false}" == "true" ]]; then\
    set -x\
fi' deployment/fresh-btpi-react.sh

# Fix the deploy_service function to show what's happening
sed -i '/^deploy_service() {/,/^}$/{
    s/local service=$1/local service=$1\
    echo "[DEBUG] deploy_service called with: $service"\
    echo "[DEBUG] Current directory: $(pwd)"\
    echo "[DEBUG] SERVICES_DIR: ${SERVICES_DIR}"\
    echo "[DEBUG] Looking for: ${SERVICES_DIR}\/$service\/deploy.sh"/
}' deployment/fresh-btpi-react.sh

# Add debugging to the deploy script check
sed -i 's/if \[ -f "$SERVICES_DIR\/$service\/deploy.sh" \]; then/echo "[DEBUG] Checking for deployment script: $SERVICES_DIR\/$service\/deploy.sh"\
    ls -la "$SERVICES_DIR\/$service\/" 2>\&1 || echo "[ERROR] Cannot list directory: $SERVICES_DIR\/$service\/"\
    if [ -f "$SERVICES_DIR\/$service\/deploy.sh" ]; then\
        echo "[DEBUG] Found deployment script, executing..."/g' deployment/fresh-btpi-react.sh

# Add error handling around the bash execution
sed -i 's/bash "$SERVICES_DIR\/$service\/deploy.sh"/echo "[DEBUG] Executing: bash $SERVICES_DIR\/$service\/deploy.sh"\
        bash -x "$SERVICES_DIR\/$service\/deploy.sh" 2>\&1 || {\
            echo "[ERROR] Failed to execute $service deployment script: $?"\
            echo "[ERROR] Continuing with next service..."\
            return 1\
        }/g' deployment/fresh-btpi-react.sh

# Fix the deploy_infrastructure function to continue on errors
sed -i '/deploy_service "$service" || log_warn/c\
        if ! deploy_service "$service"; then\
            echo "[ERROR] Service $service failed to deploy"\
            echo "[ERROR] Stack trace:"\
            for i in ${!BASH_SOURCE[@]}; do\
                echo "  [$i] ${BASH_SOURCE[$i]}:${BASH_LINENO[$i-1]} in ${FUNCNAME[$i]}"\
            done\
            echo "[WARN] Continuing with other services..."\
        fi' deployment/fresh-btpi-react.sh

PATCH

# Apply the patch
bash /tmp/deployment-patch.sh

# Fix the elasticsearch deployment script to be more verbose
echo "=== Fixing services/elasticsearch/deploy.sh ==="

# Add debugging to elasticsearch deploy script
sed -i '1a\
echo "[ELASTICSEARCH] Starting Elasticsearch deployment script..."\
echo "[ELASTICSEARCH] Script location: ${BASH_SOURCE[0]}"\
echo "[ELASTICSEARCH] Current directory: $(pwd)"' services/elasticsearch/deploy.sh

# Make the script show what it's doing
sed -i 's/^main() {/main() {\
    echo "[ELASTICSEARCH] Entering main function..."/g' services/elasticsearch/deploy.sh

# Add debugging before docker commands
sed -i 's/docker run -d/echo "[ELASTICSEARCH] Running docker container..."\
    docker run -d/g' services/elasticsearch/deploy.sh

# Fix similar issues in other database services
for service in cassandra wazuh-indexer; do
    if [ -f "services/$service/deploy.sh" ]; then
        echo "=== Fixing services/$service/deploy.sh ==="

        # Add initial debugging
        sed -i "1a\\
echo \"[${service^^}] Starting $service deployment script...\"\\
echo \"[${service^^}] Script location: \${BASH_SOURCE[0]}\"\\
echo \"[${service^^}] Current directory: \$(pwd)\"" "services/$service/deploy.sh"

        # Add main function debugging
        sed -i "s/^main() {/main() {\\
    echo \"[${service^^}] Entering main function...\"/g" "services/$service/deploy.sh"
    fi
done

echo ""
echo "=== Creating debug mode launcher ==="

# Create a debug launcher script
cat > run-deployment-debug.sh << 'LAUNCHER'
#!/bin/bash
# Run deployment with full debugging enabled

echo "Starting deployment in DEBUG mode..."
echo "This will show all commands being executed and their output"
echo ""

# Export debug flags
export DEBUG=true
export DEBUG_TRACE=true

# Source the wrapper functions
source scripts/deployment-wrapper.sh

# Run the deployment with verbose output
echo "Launching deployment..."
bash -x deployment/fresh-btpi-react.sh 2>&1 | tee deployment/logs/debug-deployment-$(date +%Y%m%d_%H%M%S).log

echo ""
echo "Deployment completed. Check the log file for details."
LAUNCHER

chmod +x run-deployment-debug.sh

echo ""
echo "=== Deployment disruption fixes applied! ==="
echo ""
echo "Changes made:"
echo "1. Replaced strict 'set -e' with verbose error handling"
echo "2. Added comprehensive debugging output"
echo "3. Added command tracing capabilities"
echo "4. Services will continue deploying even if one fails"
echo "5. All errors are now visible with stack traces"
echo ""
echo "To run deployment with full debugging:"
echo "  sudo ./run-deployment-debug.sh"
echo ""
echo "Or run normally with error handling:"
echo "  sudo bash deployment/fresh-btpi-react.sh"
echo ""
