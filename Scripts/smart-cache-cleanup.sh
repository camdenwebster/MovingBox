#!/bin/bash
set -euo pipefail

# smart-cache-cleanup.sh
# Intelligent cache cleanup for MovingBox CI/CD pipeline

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
AGGRESSIVE_MODE=false
PRESERVE_RECENT_DAYS=3
MAX_CACHE_AGE_DAYS=14
VERBOSE=false

function log() {
    if [[ "$VERBOSE" == "true" ]] || [[ "$1" != "DEBUG" ]]; then
        echo -e "${2:-}$3${NC}"
    fi
}

function log_debug() { log "DEBUG" "$BLUE" "🔍 $1"; }
function log_info() { log "INFO" "$GREEN" "ℹ️ $1"; }
function log_warn() { log "WARN" "$YELLOW" "⚠️ $1"; }
function log_error() { log "ERROR" "$RED" "❌ $1"; }
function log_success() { log "SUCCESS" "$GREEN" "✅ $1"; }

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
        du -sk "$dir" 2>/dev/null | cut -f1 | awk '{print $1 * 1024}' || echo "0"
    else
        echo "0"
    fi
}

function safe_remove() {
    local target=$1
    local description=${2:-"$target"}
    
    if [[ ! -e "$target" ]]; then
        log_debug "Target does not exist: $target"
        return 0
    fi
    
    local size_before=0
    if [[ -d "$target" ]]; then
        size_before=$(get_directory_size_bytes "$target")
    elif [[ -f "$target" ]]; then
        size_before=$(stat -f%z "$target" 2>/dev/null || echo "0")
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Would remove $description ($(human_readable_size $size_before))"
        return 0
    fi
    
    log_debug "Removing $description"
    rm -rf "$target" 2>/dev/null || log_warn "Failed to remove $target"
    
    if [[ ! -e "$target" ]]; then
        log_success "Removed $description (freed $(human_readable_size $size_before))"
        TOTAL_FREED=$((TOTAL_FREED + size_before))
    else
        log_error "Failed to remove $target"
    fi
}

function cleanup_spm_cache() {
    log_info "Cleaning Swift Package Manager cache..."
    
    local spm_cache_dir="$HOME/Library/Caches/org.swift.swiftpm"
    
    if [[ ! -d "$smp_cache_dir" ]]; then
        log_info "SPM cache directory does not exist"
        return 0
    fi
    
    local original_size=$(get_directory_size_bytes "$spm_cache_dir")
    log_info "SPM cache current size: $(human_readable_size $original_size)"
    
    # Clean old repository checkouts
    if [[ -d "$spm_cache_dir/repositories" ]]; then
        log_debug "Cleaning old repository checkouts..."
        find "$spm_cache_dir/repositories" -name "*" -mtime +$MAX_CACHE_AGE_DAYS -type d -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Clean old build artifacts
    if [[ -d "$spm_cache_dir/ModuleCache" ]]; then
        log_debug "Cleaning old module cache..."
        find "$spm_cache_dir/ModuleCache" -name "*" -mtime +$PRESERVE_RECENT_DAYS -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Aggressive cleanup if requested
    if [[ "$AGGRESSIVE_MODE" == "true" ]]; then
        log_warn "Aggressive mode: Clearing entire SPM cache"
        safe_remove "$spm_cache_dir" "entire SPM cache"
    fi
    
    # Re-calculate size after cleanup
    if [[ -d "$spm_cache_dir" ]]; then
        local new_size=$(get_directory_size_bytes "$spm_cache_dir")
        local freed=$((original_size - new_size))
        if [[ $freed -gt 0 ]]; then
            log_success "SPM cache cleanup freed $(human_readable_size $freed)"
        fi
    fi
}

function cleanup_derived_data() {
    log_info "Cleaning Xcode DerivedData..."
    
    local derived_data_dir="$HOME/Library/Developer/Xcode/DerivedData"
    
    if [[ ! -d "$derived_data_dir" ]]; then
        log_info "DerivedData directory does not exist"
        return 0
    fi
    
    local original_size=$(get_directory_size_bytes "$derived_data_dir")
    log_info "DerivedData current size: $(human_readable_size $original_size)"
    
    # Clean old MovingBox builds (preserve recent ones)
    log_debug "Cleaning old MovingBox build data..."
    find "$derived_data_dir" -name "*MovingBox*" -type d -mtime +$PRESERVE_RECENT_DAYS -exec rm -rf {} + 2>/dev/null || true
    
    # Clean all old derived data if aggressive
    if [[ "$AGGRESSIVE_MODE" == "true" ]]; then
        log_warn "Aggressive mode: Cleaning all old DerivedData"
        find "$derived_data_dir" -name "*" -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
    else
        # Clean very old builds from any project
        find "$derived_data_dir" -name "*" -type d -mtime +$MAX_CACHE_AGE_DAYS -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Clean module cache
    local module_cache="$derived_data_dir/ModuleCache.noindex"
    if [[ -d "$module_cache" ]]; then
        log_debug "Cleaning module cache..."
        find "$module_cache" -name "*" -mtime +$PRESERVE_RECENT_DAYS -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Re-calculate size after cleanup
    local new_size=$(get_directory_size_bytes "$derived_data_dir")
    local freed=$((original_size - new_size))
    if [[ $freed -gt 0 ]]; then
        log_success "DerivedData cleanup freed $(human_readable_size $freed)"
    fi
}

function cleanup_simulators() {
    log_info "Cleaning iOS Simulators..."
    
    if ! command -v xcrun &> /dev/null; then
        log_warn "xcrun not available, skipping simulator cleanup"
        return 0
    fi
    
    # Get initial simulator count and size
    local simulator_dir="$HOME/Library/Developer/CoreSimulator"
    local original_size=$(get_directory_size_bytes "$simulator_dir")
    local initial_count=$(xcrun simctl list devices 2>/dev/null | grep -c "iPhone\|iPad" || echo "0")
    
    log_info "Simulators: $initial_count devices ($(human_readable_size $original_size))"
    
    # Remove unavailable simulators
    log_debug "Removing unavailable simulators..."
    if [[ "$DRY_RUN" == "false" ]]; then
        xcrun simctl delete unavailable 2>/dev/null || log_warn "Failed to delete unavailable simulators"
    else
        local unavailable_count=$(xcrun simctl list devices unavailable 2>/dev/null | grep -c "iPhone\|iPad" || echo "0")
        log_info "Would remove $unavailable_count unavailable simulators"
    fi
    
    # Clean old simulator data
    if [[ "$AGGRESSIVE_MODE" == "true" ]]; then
        log_warn "Aggressive mode: Erasing all simulators"
        if [[ "$DRY_RUN" == "false" ]]; then
            xcrun simctl erase all 2>/dev/null || log_warn "Failed to erase all simulators"
        else
            log_info "Would erase all simulator data"
        fi
    else
        # Only clean shutdown simulators that are old
        log_debug "Cleaning old simulator data..."
        local old_simulators=$(xcrun simctl list devices 2>/dev/null | grep "Shutdown" | grep -E "\(iOS [0-9]" | head -10)
        if [[ -n "$old_simulators" ]]; then
            echo "$old_simulators" | while read -r line; do
                local sim_id=$(echo "$line" | grep -o "([A-F0-9-]*)" | tr -d "()")
                if [[ -n "$sim_id" && "$DRY_RUN" == "false" ]]; then
                    xcrun simctl delete "$sim_id" 2>/dev/null || true
                fi
            done
        fi
    fi
    
    # Clean simulator logs
    local sim_logs="$HOME/Library/Logs/CoreSimulator"
    if [[ -d "$sim_logs" ]]; then
        log_debug "Cleaning simulator logs..."
        find "$sim_logs" -name "*" -mtime +$PRESERVE_RECENT_DAYS -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Re-calculate size and count after cleanup
    if [[ "$DRY_RUN" == "false" ]]; then
        local new_size=$(get_directory_size_bytes "$simulator_dir")
        local final_count=$(xcrun simctl list devices 2>/dev/null | grep -c "iPhone\|iPad" || echo "0")
        local freed=$((original_size - new_size))
        local devices_removed=$((initial_count - final_count))
        
        if [[ $freed -gt 0 ]] || [[ $devices_removed -gt 0 ]]; then
            log_success "Simulator cleanup: removed $devices_removed devices, freed $(human_readable_size $freed)"
        fi
    fi
}

function cleanup_fastlane_artifacts() {
    log_info "Cleaning Fastlane artifacts..."
    
    # Clean fastlane logs
    local fastlane_logs="$HOME/Library/Logs/fastlane"
    if [[ -d "$fastlane_logs" ]]; then
        log_debug "Cleaning Fastlane logs..."
        find "$fastlane_logs" -name "*" -mtime +$PRESERVE_RECENT_DAYS -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Clean project fastlane artifacts
    local project_artifacts=(
        "./fastlane/test_output"
        "./fastlane/report.xml"
        "./fastlane/.DS_Store"
        "./test_results"
        "./build"
    )
    
    for artifact in "${project_artifacts[@]}"; do
        if [[ -e "$artifact" ]]; then
            safe_remove "$artifact" "Fastlane artifact: $artifact"
        fi
    done
    
    # Clean screenshots if they're old (preserve recent ones for releases)
    if [[ -d "./fastlane/screenshots" ]]; then
        local screenshot_age_days=7
        if [[ "$AGGRESSIVE_MODE" == "true" ]]; then
            screenshot_age_days=1
        fi
        
        log_debug "Cleaning screenshots older than $screenshot_age_days days..."
        find "./fastlane/screenshots" -name "*.png" -mtime +$screenshot_age_days -exec rm -f {} + 2>/dev/null || true
    fi
}

function cleanup_github_cache() {
    log_info "Cleaning GitHub Actions cache..."
    
    if ! command -v gh &> /dev/null; then
        log_warn "GitHub CLI not available, skipping GitHub cache cleanup"
        return 0
    fi
    
    if ! gh auth status &>/dev/null; then
        log_warn "GitHub CLI not authenticated, skipping GitHub cache cleanup"
        return 0
    fi
    
    # Get cache information
    local cache_list=$(gh cache list --json key,createdAt,sizeInBytes 2>/dev/null || echo "[]")
    
    if [[ "$cache_list" == "[]" || -z "$cache_list" ]]; then
        log_info "No GitHub cache entries found"
        return 0
    fi
    
    local cache_count=$(echo "$cache_list" | jq length 2>/dev/null || echo "0")
    log_info "Found $cache_count GitHub cache entries"
    
    # Clean old cache entries
    local cutoff_date=$(date -u -v-${MAX_CACHE_AGE_DAYS}d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "$MAX_CACHE_AGE_DAYS days ago" '+%Y-%m-%dT%H:%M:%SZ')
    
    if [[ "$AGGRESSIVE_MODE" == "true" ]]; then
        log_warn "Aggressive mode: Clearing all GitHub cache"
        if [[ "$DRY_RUN" == "false" ]]; then
            gh cache delete --all || log_warn "Failed to delete all GitHub cache"
        else
            log_info "Would delete all GitHub cache entries"
        fi
    else
        # Delete old cache entries
        local old_keys=$(echo "$cache_list" | jq -r ".[] | select(.createdAt < \"$cutoff_date\") | .key" 2>/dev/null || echo "")
        
        if [[ -n "$old_keys" ]]; then
            log_debug "Deleting old cache entries..."
            echo "$old_keys" | while read -r key; do
                if [[ -n "$key" && "$DRY_RUN" == "false" ]]; then
                    gh cache delete "$key" 2>/dev/null || log_warn "Failed to delete cache: $key"
                elif [[ -n "$key" ]]; then
                    log_info "Would delete cache: $key"
                fi
            done
        else
            log_info "No old GitHub cache entries to clean"
        fi
    fi
}

function cleanup_temporary_files() {
    log_info "Cleaning temporary files..."
    
    local temp_patterns=(
        ".DS_Store"
        "*.tmp"
        "Thumbs.db"
        ".swp"
        ".swo"
        "*~"
    )
    
    for pattern in "${temp_patterns[@]}"; do
        log_debug "Cleaning pattern: $pattern"
        find . -name "$pattern" -type f -exec rm -f {} + 2>/dev/null || true
    done
    
    # Clean system temporary directories if aggressive
    if [[ "$AGGRESSIVE_MODE" == "true" ]]; then
        log_warn "Aggressive mode: Cleaning system temporary files"
        
        local temp_dirs=(
            "/tmp/com.apple.dt.Xcode.*"
            "/tmp/com.apple.CoreSimulator.*"
            "$TMPDIR/com.apple.dt.Xcode.*"
        )
        
        for temp_dir in "${temp_dirs[@]}"; do
            if [[ "$DRY_RUN" == "false" ]]; then
                rm -rf $temp_dir 2>/dev/null || true
            else
                log_info "Would clean: $temp_dir"
            fi
        done
    fi
}

function optimize_git_repository() {
    log_info "Optimizing Git repository..."
    
    if [[ ! -d ".git" ]]; then
        log_info "Not in a Git repository, skipping Git optimization"
        return 0
    fi
    
    local git_size_before=$(get_directory_size_bytes ".git")
    
    # Git garbage collection
    if [[ "$DRY_RUN" == "false" ]]; then
        log_debug "Running Git garbage collection..."
        git gc --aggressive --prune=now 2>/dev/null || log_warn "Git gc failed"
        
        # Clean up Git temporary files
        git prune 2>/dev/null || log_warn "Git prune failed"
        
        # Remove stale remote branches
        git remote prune origin 2>/dev/null || log_warn "Git remote prune failed"
    else
        log_info "Would run Git garbage collection and cleanup"
    fi
    
    local git_size_after=$(get_directory_size_bytes ".git")
    local freed=$((git_size_before - git_size_after))
    
    if [[ $freed -gt 0 ]]; then
        log_success "Git optimization freed $(human_readable_size $freed)"
    fi
}

function show_help() {
    cat << EOF
MovingBox Smart Cache Cleanup

Usage: $0 [OPTIONS]

OPTIONS:
    -d, --dry-run       Show what would be cleaned without actually doing it
    -a, --aggressive    Enable aggressive cleanup (removes more data)
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message
    
    --preserve-days N   Days to preserve recent files (default: $PRESERVE_RECENT_DAYS)
    --max-age-days N    Maximum age for cache entries (default: $MAX_CACHE_AGE_DAYS)

CLEANUP OPERATIONS:
    - Swift Package Manager cache
    - Xcode DerivedData
    - iOS Simulators and logs  
    - Fastlane artifacts
    - GitHub Actions cache
    - Temporary files
    - Git repository optimization

EXAMPLES:
    $0                  # Normal cleanup
    $0 --dry-run        # Preview what would be cleaned
    $0 --aggressive     # Aggressive cleanup (more thorough)
    $0 -v --preserve-days 1  # Verbose cleanup, preserve only 1 day

EOF
}

function main() {
    local start_time=$(date +%s)
    TOTAL_FREED=0
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -a|--aggressive)
                AGGRESSIVE_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --preserve-days)
                PRESERVE_RECENT_DAYS="$2"
                shift 2
                ;;
            --max-age-days)
                MAX_CACHE_AGE_DAYS="$2"
                shift 2
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
    
    # Show configuration
    log_info "MovingBox Smart Cache Cleanup"
    log_info "Dry run: $DRY_RUN"
    log_info "Aggressive mode: $AGGRESSIVE_MODE"
    log_info "Preserve recent days: $PRESERVE_RECENT_DAYS"
    log_info "Max cache age days: $MAX_CACHE_AGE_DAYS"
    echo ""
    
    # Run cleanup operations
    cleanup_spm_cache
    cleanup_derived_data
    cleanup_simulators
    cleanup_fastlane_artifacts
    cleanup_github_cache
    cleanup_temporary_files
    optimize_git_repository
    
    # Summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log_success "Smart cache cleanup completed!"
    log_info "Duration: ${duration}s"
    log_info "Total space freed: $(human_readable_size $TOTAL_FREED)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "This was a dry run - no changes were made"
        log_info "Run without --dry-run to perform actual cleanup"
    fi
}

# Run main function with all arguments
main "$@"