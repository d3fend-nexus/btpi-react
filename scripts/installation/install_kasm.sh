#!/bin/bash
# Kasm Workspaces Installation Script - REDIRECT NOTICE
# This script has been consolidated to prevent installation conflicts.
# KASM 1.17.0 installation is now handled by fresh-btpi-react.sh

set -euo pipefail

# Logging functions
log_info() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] [KASM INSTALL]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] [KASM ERROR]\033[0m $1"
}

log_warning() {
    echo -e "\033[0;33m[$(date +'%Y-%m-%d %H:%M:%S')] [KASM WARNING]\033[0m $1"
}

# Redirect to unified installation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Main installation function - REDIRECTED
main() {
    log_info "=== KASM Installation Script - CONSOLIDATED ==="
    log_info ""
    log_warning "This standalone KASM installation script has been consolidated"
    log_warning "to prevent conflicts between multiple installation methods."
    log_info ""
    log_info "KASM 1.17.0 installation is now handled by:"
    log_info "  → deployment/fresh-btpi-react.sh"
    log_info ""
    log_info "To install KASM, please run:"
    log_info "  sudo bash deployment/fresh-btpi-react.sh"
    log_info ""
    log_info "This ensures:"
    log_info "  ✓ Single installation method (no conflicts)"
    log_info "  ✓ Proper integration with other BTPI services"
    log_info "  ✓ Consistent port configuration (8443)"
    log_info "  ✓ Native KASM installation (recommended)"
    log_info ""
    log_info "=== End of Redirect Notice ==="

    return 0
}

# All KASM installation functions have been moved to fresh-btpi-react.sh
# to provide a single, consistent installation method and prevent conflicts.
#
# The installation command sequence you provided:
# cd /tmp
# curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.17.0.7f020d.tar.gz
# curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_service_images_amd64_1.17.0.7f020d.tar.gz
# curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_workspace_images_amd64_1.17.0.7f020d.tar.gz
# curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_plugin_images_amd64_1.17.0.7f020d.tar.gz
# tar -xf kasm_release_1.17.0.7f020d.tar.gz
# sudo bash kasm_release/install.sh --offline-workspaces /tmp/kasm_release_workspace_images_amd64_1.17.0.7f020d.tar.gz --offline-service /tmp/kasm_release_service_images_amd64_1.17.0.7f020d.tar.gz --offline-network-plugin /tmp/kasm_release_plugin_images_amd64_1.17.0.7f020d.tar.gz
#
# Is now properly implemented in the install_kasm_native() function in fresh-btpi-react.sh

# Start main function
main "$@"
