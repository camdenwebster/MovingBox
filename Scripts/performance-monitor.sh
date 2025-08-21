#!/bin/bash
set -euo pipefail

# performance-monitor.sh
# Real-time performance monitoring for MovingBox CI/CD builds

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
MONITOR_DURATION=${MONITOR_DURATION:-300}  # Default 5 minutes
SAMPLE_INTERVAL=${SAMPLE_INTERVAL:-5}      # Sample every 5 seconds
OUTPUT_FORMAT=${OUTPUT_FORMAT:-"console"}  # console, json, csv
LOG_FILE=${LOG_FILE:-"performance_monitor.log"}
METRICS_FILE=${METRICS_FILE:-"performance_metrics.json"}
ALERT_THRESHOLD_CPU=${ALERT_THRESHOLD_CPU:-80}
ALERT_THRESHOLD_MEMORY=${ALERT_THRESHOLD_MEMORY:-85}
ALERT_THRESHOLD_DISK=${ALERT_THRESHOLD_DISK:-90}
VERBOSE=${VERBOSE:-false}

function log() {
    echo -e "${2:-}$3${NC}"
}

function log_debug() { [[ "$VERBOSE" == "true" ]] && log "DEBUG" "$BLUE" "🔍 $1"; }
function log_info() { log "INFO" "$GREEN" "ℹ️ $1"; }
function log_warn() { log "WARN" "$YELLOW" "⚠️ $1"; }
function log_error() { log "ERROR" "$RED" "❌ $1"; }
function log_success() { log "SUCCESS" "$GREEN" "✅ $1"; }
function log_metric() { log "METRIC" "$PURPLE" "📊 $1"; }

function get_cpu_usage() {
    # Get CPU usage percentage
    top -l 1 -s 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' | head -1 || echo "0"
}

function get_memory_usage() {
    # Get memory usage percentage
    local mem_pressure=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $5}' | sed 's/%//' || echo "50")
    echo $((100 - mem_pressure))
}

function get_disk_usage() {
    # Get disk usage percentage
    df . | tail -1 | awk '{print $5}' | sed 's/%//'
}

function get_load_average() {
    # Get 1-minute load average
    uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs
}

function get_process_count() {
    # Get total process count
    ps aux | wc -l | xargs
}

function get_xcode_processes() {
    # Count Xcode-related processes
    ps aux | grep -E "(xcodebuild|Xcode|Simulator)" | grep -v grep | wc -l | xargs
}

function get_network_activity() {
    # Get basic network activity (simplified)
    netstat -I en0 -b | tail -1 | awk '{print $7 "," $10}' 2>/dev/null || echo "0,0"
}

function get_simulator_count() {
    # Count running simulators
    if command -v xcrun &> /dev/null; then
        xcrun simctl list devices 2>/dev/null | grep -c "Booted" || echo "0"
    else
        echo "0"
    fi
}

function check_thresholds() {
    local cpu=$1
    local memory=$2
    local disk=$3
    local alerts=0
    
    if (( $(echo "$cpu > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        log_warn "High CPU usage: ${cpu}% (threshold: ${ALERT_THRESHOLD_CPU}%)"
        ((alerts++))
    fi
    
    if (( $(echo "$memory > $ALERT_THRESHOLD_MEMORY" | bc -l) )); then
        log_warn "High memory usage: ${memory}% (threshold: ${ALERT_THRESHOLD_MEMORY}%)"
        ((alerts++))
    fi
    
    if (( $(echo "$disk > $ALERT_THRESHOLD_DISK" | bc -l) )); then
        log_warn "High disk usage: ${disk}% (threshold: ${ALERT_THRESHOLD_DISK}%)"
        ((alerts++))
    fi
    
    echo $alerts
}

function collect_metrics() {
    local timestamp=$(date +%s)
    local iso_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Collect system metrics
    local cpu_usage=$(get_cpu_usage)
    local memory_usage=$(get_memory_usage)
    local disk_usage=$(get_disk_usage)
    local load_avg=$(get_load_average)
    local process_count=$(get_process_count)
    local xcode_processes=$(get_xcode_processes)
    local simulator_count=$(get_simulator_count)
    local network=$(get_network_activity)
    local network_in=$(echo "$network" | cut -d',' -f1)
    local network_out=$(echo "$network" | cut -d',' -f2)
    
    # Check for alerts
    local alert_count=$(check_thresholds "$cpu_usage" "$memory_usage" "$disk_usage")
    
    # Create metrics object
    local metrics=$(cat << EOF
{
  "timestamp": $timestamp,
  "iso_timestamp": "$iso_timestamp",
  "system": {
    "cpu_usage_percent": $cpu_usage,
    "memory_usage_percent": $memory_usage,
    "disk_usage_percent": $disk_usage,
    "load_average": $load_avg,
    "process_count": $process_count
  },
  "build_environment": {
    "xcode_processes": $xcode_processes,
    "simulator_count": $simulator_count
  },
  "network": {
    "bytes_in": $network_in,
    "bytes_out": $network_out
  },
  "alerts": {
    "count": $alert_count,
    "cpu_threshold_exceeded": $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l),
    "memory_threshold_exceeded": $(echo "$memory_usage > $ALERT_THRESHOLD_MEMORY" | bc -l),
    "disk_threshold_exceeded": $(echo "$disk_usage > $ALERT_THRESHOLD_DISK" | bc -l)
  }
}
EOF
    )
    
    echo "$metrics"
}

function display_console() {
    local metrics=$1
    local timestamp=$(echo "$metrics" | jq -r '.iso_timestamp')
    local cpu=$(echo "$metrics" | jq -r '.system.cpu_usage_percent')
    local memory=$(echo "$metrics" | jq -r '.system.memory_usage_percent')
    local disk=$(echo "$metrics" | jq -r '.system.disk_usage_percent')
    local load=$(echo "$metrics" | jq -r '.system.load_average')
    local processes=$(echo "$metrics" | jq -r '.system.process_count')
    local xcode_proc=$(echo "$metrics" | jq -r '.build_environment.xcode_processes')
    local simulators=$(echo "$metrics" | jq -r '.build_environment.simulator_count')
    local alert_count=$(echo "$metrics" | jq -r '.alerts.count')
    
    # Clear previous line if not first iteration
    if [[ "${FIRST_ITERATION:-true}" != "true" ]]; then
        printf "\033[A\033[K"
    fi
    FIRST_ITERATION=false
    
    # Color code based on usage levels
    local cpu_color="$GREEN"
    if (( $(echo "$cpu > 70" | bc -l) )); then cpu_color="$YELLOW"; fi
    if (( $(echo "$cpu > 85" | bc -l) )); then cpu_color="$RED"; fi
    
    local mem_color="$GREEN"
    if (( $(echo "$memory > 70" | bc -l) )); then mem_color="$YELLOW"; fi
    if (( $(echo "$memory > 85" | bc -l) )); then mem_color="$RED"; fi
    
    local disk_color="$GREEN"
    if (( $(echo "$disk > 80" | bc -l) )); then disk_color="$YELLOW"; fi
    if (( $(echo "$disk > 90" | bc -l) )); then disk_color="$RED"; fi
    
    # Display metrics line
    printf "📊 %s | CPU: %s%3.1f%%%s | MEM: %s%3.1f%%%s | DISK: %s%2.0f%%%s | LOAD: %4.2f | PROC: %3d | XCODE: %d | SIM: %d" \
        "$(date +%H:%M:%S)" \
        "$cpu_color" "$cpu" "$NC" \
        "$mem_color" "$memory" "$NC" \
        "$disk_color" "$disk" "$NC" \
        "$load" "$processes" "$xcode_proc" "$simulators"
    
    if [[ $alert_count -gt 0 ]]; then
        printf " %s🚨%s" "$RED" "$NC"
    fi
    
    printf "\n"
}

function display_summary() {
    local metrics_file=$1
    
    if [[ ! -f "$metrics_file" ]]; then
        log_warn "No metrics file found for summary"
        return
    fi
    
    log_info "Generating performance summary..."
    
    # Calculate averages and peaks
    local avg_cpu=$(jq '[.[].system.cpu_usage_percent] | add/length' "$metrics_file")
    local avg_memory=$(jq '[.[].system.memory_usage_percent] | add/length' "$metrics_file")
    local avg_disk=$(jq '[.[].system.disk_usage_percent] | add/length' "$metrics_file")
    local peak_cpu=$(jq '[.[].system.cpu_usage_percent] | max' "$metrics_file")
    local peak_memory=$(jq '[.[].system.memory_usage_percent] | max' "$metrics_file")
    local peak_load=$(jq '[.[].system.load_average] | max' "$metrics_file")
    local total_alerts=$(jq '[.[].alerts.count] | add' "$metrics_file")
    
    # Sample count
    local sample_count=$(jq 'length' "$metrics_file")
    local duration_minutes=$(echo "scale=1; $sample_count * $SAMPLE_INTERVAL / 60" | bc)
    
    echo ""
    log_success "Performance Monitoring Summary"
    echo "======================================"
    printf "📊 Monitoring duration: %.1f minutes (%d samples)\n" "$duration_minutes" "$sample_count"
    echo ""
    printf "📈 Average Usage:\n"
    printf "   CPU: %6.1f%%\n" "$avg_cpu"
    printf "   Memory: %3.1f%%\n" "$avg_memory" 
    printf "   Disk: %5.1f%%\n" "$avg_disk"
    echo ""
    printf "⚡ Peak Usage:\n"
    printf "   CPU: %6.1f%%\n" "$peak_cpu"
    printf "   Memory: %3.1f%%\n" "$peak_memory"
    printf "   Load: %6.2f\n" "$peak_load"
    echo ""
    printf "🚨 Total alerts: %d\n" "$total_alerts"
    echo ""
    
    # Performance assessment
    local performance_rating="Excellent"
    if (( $(echo "$avg_cpu > 50" | bc -l) )) || (( $(echo "$avg_memory > 60" | bc -l) )); then
        performance_rating="Good"
    fi
    if (( $(echo "$avg_cpu > 70" | bc -l) )) || (( $(echo "$avg_memory > 75" | bc -l) )); then
        performance_rating="Fair"  
    fi
    if (( $(echo "$avg_cpu > 85" | bc -l) )) || (( $(echo "$avg_memory > 85" | bc -l) )); then
        performance_rating="Poor"
    fi
    
    case $performance_rating in
        "Excellent") log_success "Overall Performance: $performance_rating ✨" ;;
        "Good") log_info "Overall Performance: $performance_rating 👍" ;;
        "Fair") log_warn "Overall Performance: $performance_rating ⚠️" ;;
        "Poor") log_error "Overall Performance: $performance_rating 🔥" ;;
    esac
}

function show_help() {
    cat << EOF
MovingBox Performance Monitor

Usage: $0 [OPTIONS]

This script provides real-time monitoring of system performance during CI/CD builds.

OPTIONS:
    -d, --duration SECONDS    Monitoring duration (default: $MONITOR_DURATION)
    -i, --interval SECONDS    Sample interval (default: $SAMPLE_INTERVAL)  
    -f, --format FORMAT       Output format: console, json, csv (default: $OUTPUT_FORMAT)
    -o, --output FILE         Output file for metrics (default: $METRICS_FILE)
    -l, --log FILE           Log file for alerts (default: $LOG_FILE)
    --cpu-threshold PERCENT   CPU usage alert threshold (default: $ALERT_THRESHOLD_CPU)
    --memory-threshold PERCENT Memory usage alert threshold (default: $ALERT_THRESHOLD_MEMORY)
    --disk-threshold PERCENT  Disk usage alert threshold (default: $ALERT_THRESHOLD_DISK)
    -v, --verbose            Enable verbose output
    -h, --help               Show this help message

EXAMPLES:
    $0                           # Monitor for 5 minutes with defaults
    $0 -d 600 -i 2              # Monitor for 10 minutes, sample every 2 seconds
    $0 -f json -o build_metrics.json  # Output JSON format to file
    $0 --cpu-threshold 90 -v     # Higher CPU threshold with verbose output

OUTPUT FORMATS:
    console  - Real-time terminal display (default)
    json     - JSON lines format for programmatic use
    csv      - CSV format for spreadsheet analysis

MONITORING METRICS:
    - CPU usage percentage
    - Memory usage percentage  
    - Disk usage percentage
    - System load average
    - Process counts
    - Xcode build processes
    - iOS Simulator instances
    - Network activity
    - Alert conditions

EOF
}

function main() {
    local start_time=$(date +%s)
    local samples_collected=0
    local metrics_array=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--duration)
                MONITOR_DURATION="$2"
                shift 2
                ;;
            -i|--interval)
                SAMPLE_INTERVAL="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                METRICS_FILE="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            --cpu-threshold)
                ALERT_THRESHOLD_CPU="$2"
                shift 2
                ;;
            --memory-threshold)
                ALERT_THRESHOLD_MEMORY="$2"
                shift 2
                ;;
            --disk-threshold)
                ALERT_THRESHOLD_DISK="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Run '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done
    
    # Validate dependencies
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_error "bc is required but not installed"  
        exit 1
    fi
    
    # Initialize output
    log_success "MovingBox Performance Monitor Starting"
    log_info "Duration: ${MONITOR_DURATION}s, Interval: ${SAMPLE_INTERVAL}s, Format: $OUTPUT_FORMAT"
    log_info "Thresholds - CPU: ${ALERT_THRESHOLD_CPU}%, Memory: ${ALERT_THRESHOLD_MEMORY}%, Disk: ${ALERT_THRESHOLD_DISK}%"
    echo ""
    
    # Initialize metrics file
    echo "[]" > "$METRICS_FILE"
    
    # Main monitoring loop
    local end_time=$((start_time + MONITOR_DURATION))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local metrics=$(collect_metrics)
        ((samples_collected++))
        
        case $OUTPUT_FORMAT in
            "console")
                display_console "$metrics"
                ;;
            "json")
                echo "$metrics"
                ;;
            "csv")
                if [[ $samples_collected -eq 1 ]]; then
                    # CSV header
                    echo "timestamp,cpu_usage,memory_usage,disk_usage,load_average,process_count,xcode_processes,simulator_count"
                fi
                
                # CSV data
                local timestamp=$(echo "$metrics" | jq -r '.timestamp')
                local cpu=$(echo "$metrics" | jq -r '.system.cpu_usage_percent')
                local memory=$(echo "$metrics" | jq -r '.system.memory_usage_percent')
                local disk=$(echo "$metrics" | jq -r '.system.disk_usage_percent')
                local load=$(echo "$metrics" | jq -r '.system.load_average')
                local processes=$(echo "$metrics" | jq -r '.system.process_count')
                local xcode_proc=$(echo "$metrics" | jq -r '.build_environment.xcode_processes')
                local simulators=$(echo "$metrics" | jq -r '.build_environment.simulator_count')
                
                echo "$timestamp,$cpu,$memory,$disk,$load,$processes,$xcode_proc,$simulators"
                ;;
        esac
        
        # Append to metrics file
        local temp_file=$(mktemp)
        jq ". += [$metrics]" "$METRICS_FILE" > "$temp_file" && mv "$temp_file" "$METRICS_FILE"
        
        # Log alerts
        local alert_count=$(echo "$metrics" | jq -r '.alerts.count')
        if [[ $alert_count -gt 0 ]]; then
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ): $alert_count alert(s) - $metrics" >> "$LOG_FILE"
        fi
        
        sleep "$SAMPLE_INTERVAL"
    done
    
    # Final summary
    if [[ "$OUTPUT_FORMAT" == "console" ]]; then
        display_summary "$METRICS_FILE"
    fi
    
    log_success "Performance monitoring completed"
    log_info "Samples collected: $samples_collected"
    log_info "Metrics saved to: $METRICS_FILE"
    
    if [[ -f "$LOG_FILE" && -s "$LOG_FILE" ]]; then
        log_info "Alerts logged to: $LOG_FILE"
    fi
}

# Handle script termination gracefully
trap 'log_warn "Monitoring interrupted by user"; exit 130' INT TERM

# Run main function with all arguments
main "$@"