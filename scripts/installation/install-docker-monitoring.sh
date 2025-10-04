#!/bin/bash

# Docker Health Monitoring Installation Script
# Sets up automated Docker health monitoring and configuration validation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVICE_NAME="docker-health-monitor"
TIMER_NAME="docker-health-monitor"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

print_info() { print_status "$BLUE" "[INFO] $1"; }
print_success() { print_status "$GREEN" "[SUCCESS] $1"; }
print_warning() { print_status "$YELLOW" "[WARNING] $1"; }
print_error() { print_status "$RED" "[ERROR] $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if required files exist
check_files() {
    local files=(
        "$SCRIPT_DIR/docker-health-check.sh"
        "$SCRIPT_DIR/docker-health-monitor.service"
        "$SCRIPT_DIR/docker-health-monitor.timer"
    )

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "Required file not found: $file"
            exit 1
        fi
    done

    print_success "All required files found"
}

# Install systemd service and timer
install_systemd_units() {
    print_info "Installing systemd service and timer..."

    # Copy service file
    cp "$SCRIPT_DIR/docker-health-monitor.service" "/etc/systemd/system/"
    print_info "Installed service file: /etc/systemd/system/docker-health-monitor.service"

    # Copy timer file
    cp "$SCRIPT_DIR/docker-health-monitor.timer" "/etc/systemd/system/"
    print_info "Installed timer file: /etc/systemd/system/docker-health-monitor.timer"

    # Set proper permissions
    chmod 644 "/etc/systemd/system/docker-health-monitor.service"
    chmod 644 "/etc/systemd/system/docker-health-monitor.timer"

    # Reload systemd
    systemctl daemon-reload
    print_success "Systemd units installed and reloaded"
}

# Enable and start the monitoring service
enable_monitoring() {
    print_info "Enabling Docker health monitoring..."

    # Enable the timer (this will also enable the service)
    systemctl enable "$TIMER_NAME.timer"
    print_success "Enabled $TIMER_NAME.timer"

    # Start the timer
    systemctl start "$TIMER_NAME.timer"
    print_success "Started $TIMER_NAME.timer"

    # Show timer status
    print_info "Timer status:"
    systemctl status "$TIMER_NAME.timer" --no-pager -l
}

# Create log rotation configuration
setup_log_rotation() {
    print_info "Setting up log rotation for Docker health check logs..."

    cat > /etc/logrotate.d/docker-health-check << 'EOF'
/var/log/docker-health-check.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        # Send SIGHUP to rsyslog to reopen log files
        /bin/kill -HUP `cat /var/run/rsyslogd.pid 2> /dev/null` 2> /dev/null || true
    endscript
}
EOF

    print_success "Log rotation configured"
}

# Test the installation
test_installation() {
    print_info "Testing Docker health monitoring installation..."

    # Test the health check script directly
    print_info "Running health check test..."
    if "$SCRIPT_DIR/docker-health-check.sh" --check; then
        print_success "Health check script test passed"
    else
        print_warning "Health check script test failed, but installation will continue"
    fi

    # Check timer status
    if systemctl is-active --quiet "$TIMER_NAME.timer"; then
        print_success "Timer is active and running"
    else
        print_error "Timer is not active"
        return 1
    fi

    # Show next scheduled run
    print_info "Next scheduled health check:"
    systemctl list-timers "$TIMER_NAME.timer" --no-pager
}

# Show installation summary
show_summary() {
    print_status "$GREEN" "=== Docker Health Monitoring Installation Complete ==="
    echo
    print_info "Installation Summary:"
    echo "  • Health check script: $SCRIPT_DIR/docker-health-check.sh"
    echo "  • Systemd service: /etc/systemd/system/docker-health-monitor.service"
    echo "  • Systemd timer: /etc/systemd/system/docker-health-monitor.timer"
    echo "  • Log file: /var/log/docker-health-check.log"
    echo "  • Log rotation: /etc/logrotate.d/docker-health-check"
    echo
    print_info "Management Commands:"
    echo "  • Check status: systemctl status docker-health-monitor.timer"
    echo "  • View logs: journalctl -u docker-health-monitor.service"
    echo "  • View health log: tail -f /var/log/docker-health-check.log"
    echo "  • Run manual check: $SCRIPT_DIR/docker-health-check.sh --check"
    echo "  • Run manual fix: $SCRIPT_DIR/docker-health-check.sh --fix"
    echo "  • Stop monitoring: systemctl stop docker-health-monitor.timer"
    echo "  • Start monitoring: systemctl start docker-health-monitor.timer"
    echo
    print_success "Docker health monitoring is now active and will run every 15 minutes"
}

# Uninstall function
uninstall_monitoring() {
    print_info "Uninstalling Docker health monitoring..."

    # Stop and disable timer
    systemctl stop "$TIMER_NAME.timer" 2>/dev/null || true
    systemctl disable "$TIMER_NAME.timer" 2>/dev/null || true

    # Remove systemd units
    rm -f "/etc/systemd/system/docker-health-monitor.service"
    rm -f "/etc/systemd/system/docker-health-monitor.timer"

    # Remove log rotation config
    rm -f "/etc/logrotate.d/docker-health-check"

    # Reload systemd
    systemctl daemon-reload

    print_success "Docker health monitoring uninstalled"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Docker Health Monitoring Installation Script

OPTIONS:
    --install       Install Docker health monitoring (default)
    --uninstall     Uninstall Docker health monitoring
    --test          Test existing installation
    --help          Show this help message

EXAMPLES:
    sudo $0                 # Install monitoring
    sudo $0 --install       # Install monitoring
    sudo $0 --uninstall     # Uninstall monitoring
    sudo $0 --test          # Test installation

EOF
}

# Main function
main() {
    local action="install"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install)
                action="install"
                shift
                ;;
            --uninstall)
                action="uninstall"
                shift
                ;;
            --test)
                action="test"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    case $action in
        install)
            check_root
            check_files
            install_systemd_units
            enable_monitoring
            setup_log_rotation
            test_installation
            show_summary
            ;;
        uninstall)
            check_root
            uninstall_monitoring
            ;;
        test)
            check_root
            test_installation
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
