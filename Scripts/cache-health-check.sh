#!/bin/bash
set -euo pipefail

# cache-health-check.sh
# Comprehensive cache health monitoring for MovingBox CI/CD

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAX_CACHE_SIZE_GB=50
MAX_DERIVED_DATA_GB=20
MAX_SIMULATOR_GB=30
GITHUB_CACHE_LIMIT=10

function human_readable_size() {
    local bytes=$1
    if [[ $bytes -gt 1073741824 ]]; then
        echo "$(($bytes / 1073741824))GB"
    elif [[ $bytes -gt 1048576 ]]; then
        echo "$(($bytes / 1048576))MB"
    elif [[ $bytes -gt 1024 ]]; then
        echo "$(($bytes / 1024))KB"
    else
        echo "${bytes}B"
    fi
}

function get_directory_size_bytes() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        du -sk "$dir" 2>/dev/null | cut -f1 | awk '{print $1 * 1024}'
    else
        echo "0"
    fi
}

function check_spm_cache() {
    echo -e "${BLUE}📦 Swift Package Manager Cache${NC}"
    echo "================================"
    
    local spm_cache_dir="$HOME/Library/Caches/org.swift.swiftpm"
    local spm_size_bytes=$(get_directory_size_bytes "$spm_cache_dir")
    local spm_size_human=$(human_readable_size $spm_size_bytes)
    local spm_size_gb=$((spm_size_bytes / 1073741824))
    
    echo "📍 Location: $spm_cache_dir"
    echo "📊 Size: $spm_size_human"
    
    if [[ $spm_size_gb -gt $MAX_CACHE_SIZE_GB ]]; then
        echo -e "${RED}⚠️  Cache size exceeds recommended limit (${MAX_CACHE_SIZE_GB}GB)${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "${GREEN}✅ Cache size within limits${NC}"
    fi
    
    # Check cache freshness
    if [[ -d "$spm_cache_dir" ]]; then
        local cache_age_days=$(find "$spm_cache_dir" -name "*" -mtime +7 | wc -l | xargs)
        if [[ $cache_age_days -gt 100 ]]; then
            echo -e "${YELLOW}⚠️  $cache_age_days items older than 7 days${NC}"
        else
            echo -e "${GREEN}✅ Cache is reasonably fresh${NC}"
        fi
        
        # Count packages
        local package_count=$(find "$spm_cache_dir" -name "*.git" 2>/dev/null | wc -l | xargs)
        echo "📦 Cached packages: $package_count"
    else
        echo -e "${YELLOW}⚠️  SPM cache directory does not exist${NC}"
    fi
    
    echo ""
}

function check_derived_data() {
    echo -e "${BLUE}🏗️ Xcode DerivedData${NC}"
    echo "======================="
    
    local derived_data_dir="$HOME/Library/Developer/Xcode/DerivedData"
    local dd_size_bytes=$(get_directory_size_bytes "$derived_data_dir")
    local dd_size_human=$(human_readable_size $dd_size_bytes)
    local dd_size_gb=$((dd_size_bytes / 1073741824))
    
    echo "📍 Location: $derived_data_dir"
    echo "📊 Size: $dd_size_human"
    
    if [[ $dd_size_gb -gt $MAX_DERIVED_DATA_GB ]]; then
        echo -e "${RED}⚠️  DerivedData size exceeds recommended limit (${MAX_DERIVED_DATA_GB}GB)${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "${GREEN}✅ DerivedData size within limits${NC}"
    fi
    
    # Check for MovingBox specific data
    if [[ -d "$derived_data_dir" ]]; then
        local movingbox_dirs=$(find "$derived_data_dir" -name "*MovingBox*" -type d 2>/dev/null | wc -l | xargs)
        echo "🎯 MovingBox build directories: $movingbox_dirs"
        
        # Check for old builds
        local old_builds=$(find "$derived_data_dir" -name "*MovingBox*" -mtime +3 2>/dev/null | wc -l | xargs)
        if [[ $old_builds -gt 0 ]]; then
            echo -e "${YELLOW}⚠️  $old_builds old MovingBox build directories (>3 days)${NC}"
        else
            echo -e "${GREEN}✅ No stale build directories${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  DerivedData directory does not exist${NC}"
    fi
    
    echo ""
}

function check_simulators() {
    echo -e "${BLUE}📱 iOS Simulators${NC}"
    echo "=================="
    
    local simulator_dir="$HOME/Library/Developer/CoreSimulator"
    local sim_size_bytes=$(get_directory_size_bytes "$simulator_dir")
    local sim_size_human=$(human_readable_size $sim_size_bytes)
    local sim_size_gb=$((sim_size_bytes / 1073741824))
    
    echo "📍 Location: $simulator_dir"
    echo "📊 Size: $sim_size_human"
    
    if [[ $sim_size_gb -gt $MAX_SIMULATOR_GB ]]; then
        echo -e "${RED}⚠️  Simulator data exceeds recommended limit (${MAX_SIMULATOR_GB}GB)${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "${GREEN}✅ Simulator data size within limits${NC}"
    fi
    
    # Check available simulators
    if command -v xcrun &> /dev/null; then
        local total_simulators=$(xcrun simctl list devices 2>/dev/null | grep -c "iPhone\|iPad" || echo "0")
        local available_simulators=$(xcrun simctl list devices available 2>/dev/null | grep -c "iPhone\|iPad" || echo "0")
        local unavailable_simulators=$(xcrun simctl list devices unavailable 2>/dev/null | grep -c "iPhone\|iPad" || echo "0")
        
        echo "📱 Total simulators: $total_simulators"
        echo "✅ Available: $available_simulators"
        
        if [[ $unavailable_simulators -gt 0 ]]; then
            echo -e "${YELLOW}⚠️  Unavailable: $unavailable_simulators${NC}"
        else
            echo -e "${GREEN}✅ No unavailable simulators${NC}"
        fi
        
        # Check for iOS versions we care about
        local ios_18_simulators=$(xcrun simctl list devices available 2>/dev/null | grep -c "iOS 18" || echo "0")
        echo "📱 iOS 18 simulators: $ios_18_simulators"
        
        if [[ $ios_18_simulators -eq 0 ]]; then
            echo -e "${YELLOW}⚠️  No iOS 18 simulators available${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  xcrun not available, cannot check simulators${NC}"
    fi
    
    echo ""
}

function check_github_cache() {
    echo -e "${BLUE}☁️ GitHub Actions Cache${NC}"
    echo "========================"
    
    if command -v gh &> /dev/null; then
        # Try to get cache information
        if gh auth status &>/dev/null; then
            local cache_list=$(gh cache list --json key,sizeInBytes,createdAt 2>/dev/null || echo "[]")
            
            if [[ "$cache_list" != "[]" && -n "$cache_list" ]]; then
                local cache_count=$(echo "$cache_list" | jq length 2>/dev/null || echo "0")
                local total_cache_size=$(echo "$cache_list" | jq '[.[].sizeInBytes] | add' 2>/dev/null || echo "0")
                local total_cache_size_human=$(human_readable_size $total_cache_size)
                
                echo "📊 Cache entries: $cache_count"
                echo "📊 Total size: $total_cache_size_human"
                
                # Check cache age
                local old_caches=$(echo "$cache_list" | jq '[.[] | select(.createdAt | fromdateiso8601 < (now - 604800))] | length' 2>/dev/null || echo "0")
                if [[ $old_caches -gt 0 ]]; then
                    echo -e "${YELLOW}⚠️  $old_caches cache entries older than 7 days${NC}"
                else
                    echo -e "${GREEN}✅ All cache entries are recent${NC}"
                fi
                
                # List recent caches
                echo "🔄 Recent cache keys:"
                echo "$cache_list" | jq -r '.[] | select(.createdAt | fromdateiso8601 > (now - 86400)) | "  - " + .key' 2>/dev/null | head -5
            else
                echo -e "${YELLOW}⚠️  No GitHub cache entries found${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  GitHub CLI not authenticated${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  GitHub CLI not available${NC}"
    fi
    
    echo ""
}

function check_fastlane_cache() {
    echo -e "${BLUE}🚀 Fastlane Cache${NC}"
    echo "=================="
    
    local fastlane_logs="$HOME/Library/Logs/fastlane"
    local fastlane_cache="./fastlane"
    
    # Check fastlane logs
    if [[ -d "$fastlane_logs" ]]; then
        local logs_size_bytes=$(get_directory_size_bytes "$fastlane_logs")
        local logs_size_human=$(human_readable_size $logs_size_bytes)
        echo "📝 Logs size: $logs_size_human"
        
        local recent_logs=$(find "$fastlane_logs" -name "*" -mtime -1 | wc -l | xargs)
        echo "📅 Recent log files: $recent_logs"
    else
        echo "📝 No fastlane logs directory"
    fi
    
    # Check project fastlane directory
    if [[ -d "$fastlane_cache" ]]; then
        # Check for test outputs
        local test_output_size=0
        if [[ -d "$fastlane_cache/test_output" ]]; then
            test_output_size=$(get_directory_size_bytes "$fastlane_cache/test_output")
        fi
        local test_output_human=$(human_readable_size $test_output_size)
        echo "🧪 Test output size: $test_output_human"
        
        # Check for screenshots
        local screenshots_size=0
        if [[ -d "$fastlane_cache/screenshots" ]]; then
            screenshots_size=$(get_directory_size_bytes "$fastlane_cache/screenshots")
            local screenshot_count=$(find "$fastlane_cache/screenshots" -name "*.png" | wc -l | xargs)
            echo "📸 Screenshots: $screenshot_count files ($(human_readable_size $screenshots_size))"
        fi
    else
        echo "📁 No local fastlane directory"
    fi
    
    echo ""
}

function check_system_resources() {
    echo -e "${BLUE}💻 System Resources${NC}"
    echo "==================="
    
    # Check available disk space
    local disk_info=$(df -h . | tail -1)
    local disk_usage=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')
    local available_space=$(echo "$disk_info" | awk '{print $4}')
    
    echo "💾 Disk usage: ${disk_usage}% (${available_space} available)"
    
    if [[ $disk_usage -gt 85 ]]; then
        echo -e "${RED}⚠️  Disk usage is high (>85%)${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    elif [[ $disk_usage -gt 70 ]]; then
        echo -e "${YELLOW}⚠️  Disk usage is moderate (>70%)${NC}"
    else
        echo -e "${GREEN}✅ Disk usage is healthy${NC}"
    fi
    
    # Check memory
    if command -v vm_stat &> /dev/null; then
        local memory_pressure=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $5}' | sed 's/%//' || echo "unknown")
        if [[ "$memory_pressure" != "unknown" ]]; then
            echo "🧠 Memory free: ${memory_pressure}%"
            if [[ $memory_pressure -lt 20 ]]; then
                echo -e "${RED}⚠️  Low memory available${NC}"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            else
                echo -e "${GREEN}✅ Memory availability is good${NC}"
            fi
        fi
    fi
    
    echo ""
}

function generate_recommendations() {
    echo -e "${BLUE}💡 Recommendations${NC}"
    echo "=================="
    
    if [[ $ISSUES_FOUND -eq 0 ]]; then
        echo -e "${GREEN}🎉 All cache health checks passed!${NC}"
        echo "✅ Your build cache is optimally configured"
    else
        echo -e "${YELLOW}⚠️  Found $ISSUES_FOUND potential issues${NC}"
        echo ""
        echo "🛠️ Suggested actions:"
        
        # SPM cache recommendations
        local spm_size_gb=$(($(get_directory_size_bytes "$HOME/Library/Caches/org.swift.swiftpm") / 1073741824))
        if [[ $smp_size_gb -gt $MAX_CACHE_SIZE_GB ]]; then
            echo "  📦 Clean SPM cache: rm -rf ~/Library/Caches/org.swift.swiftpm/*"
        fi
        
        # DerivedData recommendations  
        local dd_size_gb=$(($(get_directory_size_bytes "$HOME/Library/Developer/Xcode/DerivedData") / 1073741824))
        if [[ $dd_size_gb -gt $MAX_DERIVED_DATA_GB ]]; then
            echo "  🏗️ Clean old DerivedData: find ~/Library/Developer/Xcode/DerivedData -name '*MovingBox*' -mtime +3 -exec rm -rf {} +"
        fi
        
        # Simulator recommendations
        local sim_size_gb=$(($(get_directory_size_bytes "$HOME/Library/Developer/CoreSimulator") / 1073741824))
        if [[ $sim_size_gb -gt $MAX_SIMULATOR_GB ]]; then
            echo "  📱 Clean simulators: xcrun simctl delete unavailable"
        fi
        
        echo "  🧹 Run automated cleanup: ./scripts/smart-cache-cleanup.sh"
    fi
    
    echo ""
    echo "📊 Regular maintenance suggestions:"
    echo "  • Run cache health check weekly"
    echo "  • Schedule automated cleanup nightly" 
    echo "  • Monitor GitHub Actions cache usage"
    echo "  • Review cache strategies quarterly"
}

function main() {
    local script_start_time=$(date +%s)
    
    echo -e "${BLUE}🔍 MovingBox Cache Health Check${NC}"
    echo "==============================="
    echo "Started: $(date)"
    echo ""
    
    # Initialize issue counter
    ISSUES_FOUND=0
    
    # Run all checks
    check_spm_cache
    check_derived_data  
    check_simulators
    check_github_cache
    check_fastlane_cache
    check_system_resources
    generate_recommendations
    
    # Summary
    local script_duration=$(($(date +%s) - script_start_time))
    echo "=============================="
    echo "Completed: $(date)"
    echo "Duration: ${script_duration}s"
    echo "Issues found: $ISSUES_FOUND"
    
    if [[ $ISSUES_FOUND -gt 0 ]]; then
        exit 1
    fi
}

# Handle command line arguments
case "${1:-check}" in
    "check"|"")
        main
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [check|help]"
        echo ""
        echo "Commands:"
        echo "  check    Run cache health check (default)"
        echo "  help     Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac