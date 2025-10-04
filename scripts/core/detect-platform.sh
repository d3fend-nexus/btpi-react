#!/bin/bash
# BTPI-REACT Platform Detection Script
# Purpose: Detect system architecture and set appropriate variables for deployment
# Supports: x86_64/amd64 and ARM64/aarch64

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_info() {
    echo -e "${GREEN}[PLATFORM]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[PLATFORM]${NC} $1"
}

log_error() {
    echo -e "${RED}[PLATFORM]${NC} $1"
}

# Detect system architecture
detect_architecture() {
    local arch=$(uname -m)
    local platform=""
    local docker_platform=""
    
    log_info "Detecting system architecture..."
    
    case $arch in
        x86_64|amd64)
            platform="amd64"
            docker_platform="linux/amd64"
            log_info "Detected x86_64/AMD64 architecture"
            ;;
        aarch64|arm64)
            platform="arm64"
            docker_platform="linux/arm64"
            log_info "Detected ARM64/AArch64 architecture"
            ;;
        armv7l|armhf)
            platform="arm"
            docker_platform="linux/arm/v7"
            log_warn "Detected ARMv7 architecture - limited support"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    # Export platform variables
    export BTPI_ARCH="$arch"
    export BTPI_PLATFORM="$platform"
    export BTPI_DOCKER_PLATFORM="$docker_platform"
    
    log_info "Platform variables set:"
    log_info "  BTPI_ARCH: $BTPI_ARCH"
    log_info "  BTPI_PLATFORM: $BTPI_PLATFORM"
    log_info "  BTPI_DOCKER_PLATFORM: $BTPI_DOCKER_PLATFORM"
    
    return 0
}

# Get Wazuh package architecture suffix
get_wazuh_arch() {
    case "$BTPI_PLATFORM" in
        amd64)
            echo "amd64"
            ;;
        arm64)
            echo "arm64"
            ;;
        *)
            echo "amd64"  # fallback
            ;;
    esac
}

# Get Velociraptor binary name
get_velociraptor_binary() {
    case "$BTPI_PLATFORM" in
        amd64)
            echo "velociraptor-v0.75.2-linux-amd64"
            ;;
        arm64)
            echo "velociraptor-v0.75.2-linux-arm64"
            ;;
        *)
            echo "velociraptor-v0.75.2-linux-amd64"  # fallback
            ;;
    esac
}

# Get Docker image tags with architecture support
get_docker_image() {
    local service="$1"
    local version="$2"
    
    case "$service" in
        elasticsearch)
            if [[ "$BTPI_PLATFORM" == "arm64" ]]; then
                echo "docker.elastic.co/elasticsearch/elasticsearch:${version}"
            else
                echo "docker.elastic.co/elasticsearch/elasticsearch:${version}"
            fi
            ;;
        cassandra)
            echo "cassandra:${version}"
            ;;
        portainer)
            echo "portainer/portainer-ce:${version}"
            ;;
        nginx)
            echo "nginx:${version}"
            ;;
        *)
            echo "$service:$version"
            ;;
    esac
}

# Check if Docker supports buildx for multi-arch
check_docker_buildx() {
    log_info "Checking Docker buildx support..."
    
    if docker buildx version >/dev/null 2>&1; then
        log_info "Docker buildx is available for multi-architecture support"
        export BTPI_DOCKER_BUILDX=true
        
        # List available platforms
        local platforms=$(docker buildx ls 2>/dev/null | grep -o "linux/[a-z0-9/]*" | sort -u | tr '\n' ',' | sed 's/,$//')
        log_info "Available Docker platforms: $platforms"
        export BTPI_DOCKER_PLATFORMS="$platforms"
    else
        log_warn "Docker buildx not available - limited multi-architecture support"
        export BTPI_DOCKER_BUILDX=false
        export BTPI_DOCKER_PLATFORMS="$BTPI_DOCKER_PLATFORM"
    fi
}

# Validate platform requirements
validate_platform_support() {
    log_info "Validating platform support for BTPI-REACT components..."
    
    local warnings=0
    
    case "$BTPI_PLATFORM" in
        amd64)
            log_info "✓ Full support for all BTPI-REACT components"
            ;;
        arm64)
            log_info "ARM64 platform detected - checking component support:"
            log_info "✓ Wazuh: ARM64 packages available"
            log_info "✓ Velociraptor: ARM64 binary available"
            log_info "✓ Elasticsearch: ARM64 Docker image available"
            log_info "✓ Portainer: Multi-arch support"
            log_warn "⚠ Kasm Workspaces: May require special installation"
            log_warn "⚠ REMnux: May not be available for ARM64"
            warnings=2
            ;;
        arm)
            log_error "✗ ARMv7 has limited support - not recommended for production"
            return 1
            ;;
    esac
    
    if [ $warnings -gt 0 ]; then
        log_warn "Platform validation completed with $warnings warnings"
        return 2
    else
        log_info "Platform validation completed successfully"
        return 0
    fi
}

# Generate platform-specific configuration
generate_platform_config() {
    local config_file="${1:-platform.env}"
    
    log_info "Generating platform-specific configuration: $config_file"
    
    cat > "$config_file" <<EOF
# BTPI-REACT Platform Configuration
# Generated: $(date)
# Architecture: $BTPI_ARCH

# Platform variables
BTPI_ARCH=$BTPI_ARCH
BTPI_PLATFORM=$BTPI_PLATFORM
BTPI_DOCKER_PLATFORM=$BTPI_DOCKER_PLATFORM
BTPI_DOCKER_BUILDX=${BTPI_DOCKER_BUILDX:-false}
BTPI_DOCKER_PLATFORMS=${BTPI_DOCKER_PLATFORMS:-}

# Component-specific configurations
WAZUH_ARCH=$(get_wazuh_arch)
VELOCIRAPTOR_BINARY=$(get_velociraptor_binary)

# Docker images with architecture support
ELASTICSEARCH_IMAGE=$(get_docker_image elasticsearch 8.15.3)
CASSANDRA_IMAGE=$(get_docker_image cassandra 4.1)
PORTAINER_IMAGE=$(get_docker_image portainer latest)
NGINX_IMAGE=$(get_docker_image nginx alpine)
EOF
    
    log_info "Platform configuration saved to $config_file"
}

# Main execution
main() {
    log_info "BTPI-REACT Platform Detection Starting..."
    
    # Detect architecture
    if ! detect_architecture; then
        log_error "Platform detection failed"
        exit 1
    fi
    
    # Check Docker buildx support
    check_docker_buildx
    
    # Validate platform support
    local validation_result=0
    validate_platform_support || validation_result=$?
    
    # Generate configuration if requested
    if [[ "${1:-}" == "--generate-config" ]]; then
        generate_platform_config "${2:-platform.env}"
    fi
    
    # Export functions for use in other scripts
    if [[ "${1:-}" == "--source" ]]; then
        log_info "Platform detection completed - functions available for sourcing"
    fi
    
    log_info "Platform detection completed"
    return $validation_result
}

# Allow sourcing without execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# Export functions for sourcing
export -f detect_architecture
export -f get_wazuh_arch
export -f get_velociraptor_binary
export -f get_docker_image
export -f check_docker_buildx
export -f validate_platform_support
export -f generate_platform_config
