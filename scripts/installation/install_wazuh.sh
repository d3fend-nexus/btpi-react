#!/bin/bash
# BTPI-REACT Wazuh Installation Script with ARM64 Support
# Purpose: Install Wazuh components with platform-aware package selection
# Supports: x86_64/amd64 and ARM64/aarch64 architectures

set -euo pipefail

# Script directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source platform detection and common utilities
source "${SCRIPT_DIR}/scripts/core/detect-platform.sh" --source
source "${SCRIPT_DIR}/scripts/core/common-utils.sh"

# Wazuh version configuration
WAZUH_VERSION="${WAZUH_VERSION:-4.9.0}"
INSTALLATION_METHOD="${1:-docker}"  # docker or native

# Wazuh package URLs based on architecture
declare -A WAZUH_MANAGER_URLS=(
    ["amd64"]="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-manager/wazuh-manager_${WAZUH_VERSION}-1_amd64.deb"
    ["arm64"]="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-manager/wazuh-manager_${WAZUH_VERSION}-1_arm64.deb"
)

declare -A WAZUH_INDEXER_URLS=(
    ["amd64"]="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-indexer/wazuh-indexer_${WAZUH_VERSION}-1_amd64.deb"
    ["arm64"]="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-indexer/wazuh-indexer_${WAZUH_VERSION}-1_arm64.deb"
)

declare -A WAZUH_DASHBOARD_URLS=(
    ["amd64"]="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-dashboard/wazuh-dashboard_${WAZUH_VERSION}-1_amd64.deb"
    ["arm64"]="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-dashboard/wazuh-dashboard_${WAZUH_VERSION}-1_arm64.deb"
)

# Initialize platform detection
init_platform() {
    log_info "Initializing Wazuh installation with platform detection..." "WAZUH"
    
    # Detect platform
    detect_architecture
    
    # Validate platform support
    validate_platform_support
    local validation_result=$?
    
    if [ $validation_result -eq 1 ]; then
        log_error "Platform not supported for Wazuh installation" "WAZUH"
        exit 1
    elif [ $validation_result -eq 2 ]; then
        log_warn "Platform has warnings - proceeding with caution" "WAZUH"
    fi
    
    log_info "Platform: $BTPI_PLATFORM, Architecture: $BTPI_ARCH" "WAZUH"
    log_info "Wazuh version: $WAZUH_VERSION" "WAZUH"
}

# Docker-based installation (multi-arch)
install_wazuh_docker() {
    log_info "Installing Wazuh using Docker method..." "WAZUH"
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not available" "WAZUH"
        return 1
    fi
    
    # Set working directory
    local work_dir="/opt/wazuh"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # Install git if not available (for Ubuntu/Debian)
    if ! command -v git &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            log_info "Installing git..." "WAZUH"
            apt-get update -qq
            apt-get install -y git
        elif command -v apk &> /dev/null; then
            apk add --no-cache git
        fi
    fi
    
    # Clone Wazuh Docker repository
    log_info "Cloning Wazuh Docker repository..." "WAZUH"
    if [ -d "wazuh-docker" ]; then
        rm -rf wazuh-docker
    fi
    
    git clone https://github.com/wazuh/wazuh-docker.git -b "v${WAZUH_VERSION}" wazuh-docker
    cd wazuh-docker
    
    # Configure for platform if needed
    if [ "$BTPI_PLATFORM" = "arm64" ]; then
        log_info "Configuring Docker images for ARM64..." "WAZUH"
        # Update docker-compose files to specify platform if needed
        find . -name "*.yml" -exec sed -i 's/image: wazuh/image: --platform=linux\/arm64 wazuh/g' {} \; 2>/dev/null || true
    fi
    
    # Generate indexer certificates
    log_info "Generating indexer certificates..." "WAZUH"
    if [ -f "generate-indexer-certs.yml" ]; then
        docker-compose -f generate-indexer-certs.yml run --rm generator || {
            log_warn "Certificate generation failed, continuing..." "WAZUH"
        }
    fi
    
    # Start Wazuh services
    log_info "Starting Wazuh services..." "WAZUH"
    docker compose up -d || docker-compose up -d
    
    log_success "Wazuh Docker installation completed" "WAZUH"
    log_info "Access Wazuh Dashboard at https://localhost:443" "WAZUH"
    log_info "Default credentials: admin/SecretPassword (change after first login)" "WAZUH"
}

# Native package installation (platform-aware)
install_wazuh_native() {
    log_info "Installing Wazuh using native packages for $BTPI_PLATFORM..." "WAZUH"
    
    # Get architecture-specific URLs
    local wazuh_arch=$(get_wazuh_arch)
    local manager_url="${WAZUH_MANAGER_URLS[$BTPI_PLATFORM]}"
    local indexer_url="${WAZUH_INDEXER_URLS[$BTPI_PLATFORM]}"
    local dashboard_url="${WAZUH_DASHBOARD_URLS[$BTPI_PLATFORM]}"
    
    log_info "Using $wazuh_arch packages" "WAZUH"
    log_info "Manager URL: $manager_url" "WAZUH"
    log_info "Indexer URL: $indexer_url" "WAZUH"
    log_info "Dashboard URL: $dashboard_url" "WAZUH"
    
    # Create temp directory for downloads
    local temp_dir="/tmp/wazuh_install_$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Install prerequisites
    log_info "Installing prerequisites..." "WAZUH"
    apt-get update -qq
    apt-get install -y curl apt-transport-https lsb-release gnupg
    
    # Add Wazuh repository key
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor > /usr/share/keyrings/wazuh-archive-keyring.gpg
    
    # Add repository
    echo "deb [signed-by=/usr/share/keyrings/wazuh-archive-keyring.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list
    apt-get update -qq
    
    # Download and install Wazuh Indexer
    log_info "Installing Wazuh Indexer..." "WAZUH"
    curl -L -o wazuh-indexer.deb "$indexer_url"
    dpkg -i wazuh-indexer.deb || {
        apt-get -f install -y
        dpkg -i wazuh-indexer.deb
    }
    
    # Download and install Wazuh Manager
    log_info "Installing Wazuh Manager..." "WAZUH"
    curl -L -o wazuh-manager.deb "$manager_url"
    dpkg -i wazuh-manager.deb || {
        apt-get -f install -y
        dpkg -i wazuh-manager.deb
    }
    
    # Download and install Wazuh Dashboard
    log_info "Installing Wazuh Dashboard..." "WAZUH"
    curl -L -o wazuh-dashboard.deb "$dashboard_url"
    dpkg -i wazuh-dashboard.deb || {
        apt-get -f install -y
        dpkg -i wazuh-dashboard.deb
    }
    
    # Enable and start services
    log_info "Starting Wazuh services..." "WAZUH"
    systemctl enable wazuh-indexer wazuh-manager wazuh-dashboard
    systemctl start wazuh-indexer
    sleep 10
    systemctl start wazuh-manager
    sleep 10
    systemctl start wazuh-dashboard
    
    # Cleanup
    cd /
    rm -rf "$temp_dir"
    
    log_success "Wazuh native installation completed" "WAZUH"
    log_info "Access Wazuh Dashboard at https://localhost:443" "WAZUH"
}

# Offline installation for air-gapped environments
install_wazuh_offline() {
    log_info "Installing Wazuh for offline/air-gapped environment..." "WAZUH"
    
    local offline_dir="${SCRIPT_DIR}/offline_packages/wazuh"
    mkdir -p "$offline_dir"
    
    # Download packages if not present
    if [ ! -f "$offline_dir/wazuh-manager_${WAZUH_VERSION}-1_${BTPI_PLATFORM}.deb" ]; then
        log_info "Downloading Wazuh packages for offline installation..." "WAZUH"
        cd "$offline_dir"
        
        wget "${WAZUH_MANAGER_URLS[$BTPI_PLATFORM]}" -O "wazuh-manager_${WAZUH_VERSION}-1_${BTPI_PLATFORM}.deb"
        wget "${WAZUH_INDEXER_URLS[$BTPI_PLATFORM]}" -O "wazuh-indexer_${WAZUH_VERSION}-1_${BTPI_PLATFORM}.deb"
        wget "${WAZUH_DASHBOARD_URLS[$BTPI_PLATFORM]}" -O "wazuh-dashboard_${WAZUH_VERSION}-1_${BTPI_PLATFORM}.deb"
    fi
    
    # Install from local packages
    log_info "Installing from offline packages..." "WAZUH"
    cd "$offline_dir"
    
    dpkg -i "wazuh-indexer_${WAZUH_VERSION}-1_${BTPI_PLATFORM}.deb" || apt-get -f install -y
    dpkg -i "wazuh-manager_${WAZUH_VERSION}-1_${BTPI_PLATFORM}.deb" || apt-get -f install -y
    dpkg -i "wazuh-dashboard_${WAZUH_VERSION}-1_${BTPI_PLATFORM}.deb" || apt-get -f install -y
    
    # Start services
    systemctl enable wazuh-indexer wazuh-manager wazuh-dashboard
    systemctl start wazuh-indexer
    sleep 10
    systemctl start wazuh-manager
    sleep 10
    systemctl start wazuh-dashboard
    
    log_success "Wazuh offline installation completed" "WAZUH"
}

# Main installation function
main() {
    show_banner "WAZUH INSTALLATION" "Platform-aware Wazuh deployment for BTPI-REACT"
    
    # Initialize platform detection
    init_platform
    
    # Determine installation method
    case "$INSTALLATION_METHOD" in
        docker|container)
            install_wazuh_docker
            ;;
        native|package)
            install_wazuh_native
            ;;
        offline)
            install_wazuh_offline
            ;;
        *)
            log_warn "Unknown installation method: $INSTALLATION_METHOD, using Docker" "WAZUH"
            install_wazuh_docker
            ;;
    esac
    
    log_success "Wazuh installation process completed!" "WAZUH"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
