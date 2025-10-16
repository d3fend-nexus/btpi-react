#!/bin/bash
# Wazuh Deployment Script
# Purpose: Deploy Wazuh using shared infrastructure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../scripts/common-utils.sh"

deploy_wazuh() {
    log_info "Starting Wazuh deployment..." "WAZUH"

    # Check if legacy build script exists
    if [[ -f "$SCRIPT_DIR/../../wazuh/build_wazuh.sh" ]]; then
        log_info "Using legacy build script for Wazuh..." "WAZUH"
        cd "$SCRIPT_DIR/../../wazuh"
        bash "build_wazuh.sh"
        cd "$SCRIPT_DIR"
    else
        log_error "No deployment method available for Wazuh" "WAZUH"
        return 1
    fi

    log_success "Wazuh deployment completed" "WAZUH"
}

# Main deployment function
main() {
    deploy_wazuh
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
