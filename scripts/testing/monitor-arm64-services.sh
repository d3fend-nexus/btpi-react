#!/bin/bash
# BTPI-REACT ARM64 Service Monitoring Script  
# Purpose: Real-time monitoring and health checking for ARM64 deployments
# Provides continuous monitoring with performance metrics and alerting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
MONITOR_INTERVAL=30  # seconds between checks
LOG_FILE="$PROJECT_ROOT/logs/arm64-monitor-$(date +%Y%m%d).log"
METRICS_FILE="$PROJECT_ROOT/logs/arm64-metrics-$(date +%Y%m%d).csv"
MAX_LOG_SIZE=100000000  # 100MB
CONTINUOUS_MODE=false
ALERT_MODE=false
PERFORMANCE_MODE=false

# Service configuration
declare -A SERVICE_PORTS=(
    ["elasticsearch"]="9200"
    ["wazuh-indexer"]="9400"
    ["cassandra"]="9042"
    ["portainer"]="9443"
    ["velociraptor"]="8889"
    ["wazuh-manager"]="55000"
)

declare -A SERVICE_HEALTH_CHECKS=(
    ["elasticsearch"]="curl -s -f http://localhost:9200/_cluster/health --max-time 5"
    ["wazuh-indexer"]="curl -s -f http://localhost:9400/_cluster/health --max-time 5"
    ["cassandra"]="docker exec cassandra cqlsh -e 'SELECT release_version FROM system.local;' 2>/dev/null"
    ["portainer"]="curl -k -s -f https://localhost:9443/ --max-time 5"
    ["velociraptor"]="curl -k -s -f https://localhost:8889/ --max-time 5"
    ["wazuh-manager"]="curl -k -s -f https://localhost:55000/ --max-time 5"
)

declare -A SERVICE_STATUS=()
declare -A SERVICE_LAST_SEEN=()
declare -A SERVICE_RESTART_COUNT=()

# Logging functions
log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_metric() {
    echo "$1" >> "$METRICS_FILE"
}

# Initialize monitoring environment
initialize_monitoring() {
    mkdir -p "$PROJECT_ROOT/logs"
    
    # Initialize log file
    if [ ! -f "$LOG_FILE" ]; then
        echo "# BTPI-REACT ARM64 Service Monitor Log - $(date)" > "$LOG_FILE"
    fi
    
    # Initialize metrics file with CSV header
    if [ ! -f "$METRICS_FILE" ]; then
        echo "timestamp,service,status,cpu_usage,memory_usage,disk_usage,response_time_ms,architecture" > "$METRICS_FILE"
    fi
    
    # Rotate log if too large
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        echo "# BTPI-REACT ARM64 Service Monitor Log - $(date)" > "$LOG_FILE"
        log_info "Log file rotated due to size"
    fi
    
    # Source platform detection
    if [ -f "$PROJECT_ROOT/scripts/core/detect-platform.sh" ]; then
        source "$PROJECT_ROOT/scripts/core/detect-platform.sh" --source
        detect_architecture || true
    else
        export BTPI_ARCH="$(uname -m)"
        export BTPI_PLATFORM="$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')"
    fi
    
    log_info "ARM64 Service Monitor initialized"
    log_info "Platform: $BTPI_PLATFORM ($BTPI_ARCH)"
    log_info "Monitor interval: ${MONITOR_INTERVAL}s"
    log_info "Log file: $LOG_FILE"
    log_info "Metrics file: $METRICS_FILE"
}

# Detect running services
detect_services() {
    local detected_services=()
    
    log_info "Detecting running BTPI-REACT services..."
    
    # Check Docker containers
    while read -r container_name; do
        if [ -n "$container_name" ] && [[ "${SERVICE_PORTS[$container_name]:-}" != "" ]]; then
            detected_services+=("$container_name")
            log_info "Detected Docker container: $container_name"
        fi
    done < <(docker ps --format "{{.Names}}" 2>/dev/null | grep -E "(elasticsearch|wazuh-indexer|cassandra|portainer|velociraptor|wazuh-manager)" || true)
    
    # Check systemd services
    while read -r service_name; do
        if [[ "${SERVICE_PORTS[$service_name]:-}" != "" ]]; then
            if ! printf '%s\n' "${detected_services[@]}" | grep -q "^$service_name$"; then
                detected_services+=("$service_name")
                log_info "Detected systemd service: $service_name"
            fi
        fi
    done < <(systemctl list-units --type=service --state=active | grep -E "(elasticsearch|wazuh-indexer|cassandra|portainer|velociraptor|wazuh-manager)" | awk '{print $1}' | sed 's/.service$//' || true)
    
    if [ ${#detected_services[@]} -eq 0 ]; then
        log_warn "No BTPI-REACT services detected"
    else
        log_info "Found ${#detected_services[@]} services to monitor"
    fi
    
    printf '%s\n' "${detected_services[@]}"
}

# Get service architecture information
get_service_architecture() {
    local service_name="$1"
    
    # Check if it's a Docker container
    if docker ps --format "{{.Names}}" | grep -q "^$service_name$"; then
        local image_name=$(docker ps --format "{{.Image}}" --filter "name=$service_name")
        local arch=$(docker image inspect "$image_name" 2>/dev/null | jq -r '.[0].Architecture' 2>/dev/null || echo "unknown")
        echo "container:$arch"
    # Check if it's a systemd service
    elif systemctl list-units --type=service | grep -q "$service_name"; then
        echo "native:$(uname -m)"
    else
        echo "unknown:unknown"
    fi
}

# Get container/process resource usage
get_service_metrics() {
    local service_name="$1"
    local cpu_usage="0"
    local memory_usage="0"
    local disk_usage="0"
    
    # Get Docker container metrics
    if docker ps --format "{{.Names}}" | grep -q "^$service_name$"; then
        local stats=$(docker stats --no-stream --format "table {{.CPUPerc}},{{.MemUsage}}" "$service_name" 2>/dev/null | tail -n1)
        if [ -n "$stats" ] && [ "$stats" != "table CPU %,MEM USAGE / LIMIT" ]; then
            cpu_usage=$(echo "$stats" | cut -d',' -f1 | sed 's/%//')
            local mem_info=$(echo "$stats" | cut -d',' -f2)
            # Extract memory usage in MB (simplified)
            memory_usage=$(echo "$mem_info" | sed 's/[^0-9.]//g' | cut -d'.' -f1)
        fi
        
        # Get container disk usage
        local container_size=$(docker system df --format "table {{.Size}}" | grep -A1 "RECLAIMABLE" | tail -n1 | sed 's/[^0-9]//g' 2>/dev/null || echo "0")
        disk_usage="$container_size"
    # Get systemd service metrics
    elif systemctl list-units --type=service | grep -q "$service_name"; then
        # Try to get CPU usage from systemctl
        local main_pid=$(systemctl show "$service_name" --property=MainPID --value 2>/dev/null)
        if [ -n "$main_pid" ] && [ "$main_pid" != "0" ]; then
            cpu_usage=$(ps -p "$main_pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "0")
            memory_usage=$(ps -p "$main_pid" -o rss --no-headers 2>/dev/null | tr -d ' ' || echo "0")
            memory_usage=$((memory_usage / 1024))  # Convert KB to MB
        fi
    fi
    
    echo "${cpu_usage:-0},${memory_usage:-0},${disk_usage:-0}"
}

# Check service health
check_service_health() {
    local service_name="$1"
    local health_check="${SERVICE_HEALTH_CHECKS[$service_name]}"
    local start_time=$(date +%s%3N)  # milliseconds
    
    # Execute health check
    if eval "$health_check" >/dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        SERVICE_STATUS["$service_name"]="healthy"
        SERVICE_LAST_SEEN["$service_name"]=$(date +%s)
        echo "$response_time"
        return 0
    else
        SERVICE_STATUS["$service_name"]="unhealthy"
        echo "0"
        return 1
    fi
}

# Monitor individual service
monitor_service() {
    local service_name="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get service architecture
    local arch_info=$(get_service_architecture "$service_name")
    
    # Get resource metrics
    local metrics=$(get_service_metrics "$service_name")
    local cpu_usage=$(echo "$metrics" | cut -d',' -f1)
    local memory_usage=$(echo "$metrics" | cut -d',' -f2)
    local disk_usage=$(echo "$metrics" | cut -d',' -f3)
    
    # Check health and get response time
    local response_time=0
    local status="unhealthy"
    
    if response_time=$(check_service_health "$service_name"); then
        status="healthy"
        log_success "$service_name is healthy (${response_time}ms response)"
    else
        status="unhealthy"
        log_error "$service_name is unhealthy"
        
        # Handle unhealthy service
        handle_unhealthy_service "$service_name"
    fi
    
    # Log metrics to CSV
    log_metric "$timestamp,$service_name,$status,$cpu_usage,$memory_usage,$disk_usage,$response_time,$arch_info"
    
    # Performance mode - additional metrics
    if [ "$PERFORMANCE_MODE" = true ]; then
        display_performance_metrics "$service_name" "$cpu_usage" "$memory_usage" "$disk_usage" "$response_time" "$arch_info"
    fi
}

# Handle unhealthy services
handle_unhealthy_service() {
    local service_name="$1"
    local restart_count=${SERVICE_RESTART_COUNT["$service_name"]:-0}
    
    log_warn "$service_name is unhealthy (restart count: $restart_count)"
    
    if [ "$ALERT_MODE" = true ]; then
        # Attempt automatic recovery
        if [ $restart_count -lt 3 ]; then
            log_info "Attempting to restart $service_name..."
            
            if docker ps --format "{{.Names}}" | grep -q "^$service_name$"; then
                docker restart "$service_name" >/dev/null 2>&1
                log_info "$service_name container restarted"
            elif systemctl list-units --type=service | grep -q "$service_name"; then
                systemctl restart "$service_name" >/dev/null 2>&1
                log_info "$service_name systemd service restarted"
            fi
            
            SERVICE_RESTART_COUNT["$service_name"]=$((restart_count + 1))
            sleep 10  # Give service time to restart
        else
            log_error "$service_name has failed too many times, manual intervention required"
        fi
    fi
}

# Display performance metrics
display_performance_metrics() {
    local service_name="$1"
    local cpu_usage="$2"
    local memory_usage="$3"
    local disk_usage="$4"
    local response_time="$5"
    local arch_info="$6"
    
    echo -e "${CYAN}┌─ Performance Metrics: $service_name ─┐${NC}"
    echo -e "${CYAN}│${NC} CPU Usage:     ${cpu_usage}%"
    echo -e "${CYAN}│${NC} Memory Usage:  ${memory_usage}MB"
    echo -e "${CYAN}│${NC} Disk Usage:    ${disk_usage}MB"
    echo -e "${CYAN}│${NC} Response Time: ${response_time}ms"
    echo -e "${CYAN}│${NC} Architecture:  $arch_info"
    echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
}

# Display summary dashboard
display_dashboard() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                    BTPI-REACT ARM64 Service Monitor                          ║
║                          Real-time Dashboard                                 ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${BOLD}System Information:${NC}"
    echo "  Platform: $BTPI_PLATFORM ($BTPI_ARCH)"
    echo "  Time: $(date)"
    echo "  Monitor Interval: ${MONITOR_INTERVAL}s"
    echo ""
    
    echo -e "${BOLD}Service Status Summary:${NC}"
    local healthy_count=0
    local unhealthy_count=0
    local total_count=0
    
    for service in "${!SERVICE_STATUS[@]}"; do
        total_count=$((total_count + 1))
        local status="${SERVICE_STATUS[$service]}"
        local last_seen="${SERVICE_LAST_SEEN[$service]:-0}"
        local age=$(($(date +%s) - last_seen))
        local restart_count="${SERVICE_RESTART_COUNT[$service]:-0}"
        
        if [ "$status" = "healthy" ]; then
            healthy_count=$((healthy_count + 1))
            echo -e "  ${GREEN}✓${NC} $service (healthy, ${age}s ago) restarts: $restart_count"
        else
            unhealthy_count=$((unhealthy_count + 1))
            echo -e "  ${RED}✗${NC} $service (unhealthy, ${age}s ago) restarts: $restart_count"
        fi
    done
    
    echo ""
    echo -e "${BOLD}Summary:${NC} $healthy_count healthy, $unhealthy_count unhealthy, $total_count total"
    echo ""
    
    if [ $unhealthy_count -gt 0 ]; then
        echo -e "${YELLOW}⚠ Warning: Some services are unhealthy${NC}"
    else
        echo -e "${GREEN}✅ All monitored services are healthy${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}Controls:${NC} Ctrl+C to stop | Log: $LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main monitoring loop
start_monitoring() {
    local services=($(detect_services))
    
    if [ ${#services[@]} -eq 0 ]; then
        log_error "No services to monitor. Exiting."
        exit 1
    fi
    
    log_info "Starting monitoring for ${#services[@]} services"
    
    # Initialize service status
    for service in "${services[@]}"; do
        SERVICE_STATUS["$service"]="unknown"
        SERVICE_RESTART_COUNT["$service"]=0
    done
    
    # Monitoring loop
    while true; do
        if [ "$CONTINUOUS_MODE" = true ]; then
            display_dashboard
        fi
        
        for service in "${services[@]}"; do
            monitor_service "$service"
        done
        
        if [ "$CONTINUOUS_MODE" = false ]; then
            # Single run mode
            break
        fi
        
        sleep "$MONITOR_INTERVAL"
    done
}

# Generate monitoring report
generate_report() {
    local report_file="$PROJECT_ROOT/logs/arm64-monitor-report-$(date +%Y%m%d-%H%M%S).txt"
    
    log_info "Generating monitoring report..."
    
    cat > "$report_file" <<EOF
# BTPI-REACT ARM64 Service Monitoring Report
# Generated: $(date)
# Host: $(hostname)
# Architecture: $BTPI_ARCH

================================
MONITORING SUMMARY
================================

Platform: $BTPI_PLATFORM ($BTPI_ARCH)
Monitor Duration: $(date)
Services Monitored: ${#SERVICE_STATUS[@]}

Service Status:
EOF

    for service in "${!SERVICE_STATUS[@]}"; do
        local status="${SERVICE_STATUS[$service]}"
        local restart_count="${SERVICE_RESTART_COUNT[$service]:-0}"
        local arch_info=$(get_service_architecture "$service")
        
        echo "- $service: $status (restarts: $restart_count, arch: $arch_info)" >> "$report_file"
    done
    
    cat >> "$report_file" <<EOF

================================
PERFORMANCE METRICS
================================

Latest metrics from: $METRICS_FILE
(Use CSV tools to analyze performance trends)

Recent log entries:
EOF

    tail -20 "$LOG_FILE" >> "$report_file" 2>/dev/null || echo "No log entries available" >> "$report_file"
    
    cat >> "$report_file" <<EOF

================================
RECOMMENDATIONS
================================

EOF

    # Generate recommendations based on monitoring data
    local healthy_count=0
    for status in "${SERVICE_STATUS[@]}"; do
        [ "$status" = "healthy" ] && healthy_count=$((healthy_count + 1))
    done
    
    if [ $healthy_count -eq ${#SERVICE_STATUS[@]} ]; then
        echo "✅ All services are healthy and performing well." >> "$report_file"
        echo "Continue regular monitoring and maintenance." >> "$report_file"
    else
        echo "⚠️ Some services require attention:" >> "$report_file"
        for service in "${!SERVICE_STATUS[@]}"; do
            if [ "${SERVICE_STATUS[$service]}" != "healthy" ]; then
                echo "- $service: Check logs and restart if necessary" >> "$report_file"
            fi
        done
    fi
    
    echo "" >> "$report_file"
    echo "Report generated: $(date)" >> "$report_file"
    
    log_success "Monitoring report generated: $report_file"
}

# Usage information
usage() {
    cat << EOF
BTPI-REACT ARM64 Service Monitor

Usage: $0 [OPTIONS]

OPTIONS:
    -c, --continuous     Run in continuous monitoring mode (dashboard)
    -a, --alert          Enable alert mode with automatic restart attempts
    -p, --performance    Enable detailed performance metrics display
    -i, --interval SEC   Set monitoring interval in seconds (default: 30)
    -r, --report         Generate monitoring report and exit
    -h, --help          Show this help message

EXAMPLES:
    $0                   # Single monitoring run
    $0 -c                # Continuous monitoring with dashboard
    $0 -c -a -p          # Full monitoring with alerts and performance
    $0 -r                # Generate report only
    $0 -i 10 -c          # Continuous monitoring every 10 seconds

FILES:
    Logs: $PROJECT_ROOT/logs/arm64-monitor-*.log
    Metrics: $PROJECT_ROOT/logs/arm64-metrics-*.csv
    Reports: $PROJECT_ROOT/logs/arm64-monitor-report-*.txt
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--continuous)
                CONTINUOUS_MODE=true
                shift
                ;;
            -a|--alert)
                ALERT_MODE=true
                shift
                ;;
            -p|--performance)
                PERFORMANCE_MODE=true
                shift
                ;;
            -i|--interval)
                MONITOR_INTERVAL="$2"
                shift 2
                ;;
            -r|--report)
                generate_report
                exit 0
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Cleanup on exit
cleanup() {
    log_info "Monitoring stopped by user"
    [ "$CONTINUOUS_MODE" = true ] && generate_report
    exit 0
}

# Main execution
main() {
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM
    
    # Parse arguments
    parse_args "$@"
    
    # Initialize monitoring
    initialize_monitoring
    
    # Start monitoring
    start_monitoring
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
