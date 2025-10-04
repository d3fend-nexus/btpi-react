#!/bin/bash
# Kasm Workspaces Deployment Script
# Purpose: Redirect to native KASM installation to prevent conflicts
# NOTE: This script redirects to the native installation method in fresh-btpi-react.sh
# to avoid conflicts between Docker-based and native KASM installations.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../scripts/common-utils.sh"

# Validate environment variables
validate_environment "kasm"

log_info "KASM deployment redirected to native installation method..." "KASM"
log_info "This prevents conflicts between Docker and native KASM installations." "KASM"
log_info "Native KASM installation will be handled by fresh-btpi-react.sh" "KASM"

# Redirect to native KASM installation
log_success "KASM service deployment delegated to native installation method" "KASM"
log_info "Access KASM at: https://localhost:8443 (after native installation)" "KASM"
exit 0

# Note: All Docker-based KASM deployment functions have been disabled
# to prevent conflicts with the native installation method.
# The native installation method in fresh-btpi-react.sh provides
# a more reliable and official KASM deployment approach.
