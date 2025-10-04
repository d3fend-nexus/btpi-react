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
bash -x deployment/fresh-btpi-react.sh 2>&1 | tee "deployment/logs/debug-deployment-$(date +%Y%m%d_%H%M%S).log"

echo ""
echo "Deployment completed. Check the log file for details."
