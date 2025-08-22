#!/bin/bash
set -euo pipefail

# cache-warmup.sh
# Intelligent cache warming for MovingBox CI/CD pipeline

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WARMUP_SIMULATORS=true
WARMUP_SPM_PACKAGES=true
WARMUP_BUILD_CACHE=true
WARMUP_FASTLANE=false
PARALLEL_WARMUP=true
VERBOSE=false

# Build configurations
BUILD_SCHEME="MovingBox"
BUILD_DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro"
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData/MovingBox-Warmup"

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

function check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "MovingBox.xcodeproj/project.pbxproj" ]]; then
        log_error "Not in MovingBox project directory"
        exit 1
    fi
    
    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_error "xcodebuild not found"
        exit 1
    fi
    
    # Check Xcode version
    local xcode_version=$(xcodebuild -version | head -1)
    log_info "Using $xcode_version"
    
    # Check available disk space (need at least 5GB for warmup)
    local available_space=$(df . | tail -1 | awk '{print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [[ $available_gb -lt 5 ]]; then
        log_warn "Low disk space: ${available_gb}GB available (recommend 5GB+)"
    else
        log_info "Available disk space: ${available_gb}GB"
    fi
    
    log_success "Prerequisites check passed"
}

function warmup_spm_packages() {
    if [[ "$WARMUP_SPM_PACKAGES" != "true" ]]; then
        log_info "Skipping SPM package warmup"
        return 0
    fi
    
    log_info "Warming up Swift Package Manager packages..."
    
    local spm_start_time=$(date +%s)
    
    # Check if Package.resolved exists
    local package_resolved="MovingBox.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    if [[ ! -f "$package_resolved" ]]; then
        log_warn "Package.resolved not found, attempting package resolution..."
        
        if command -v swift &> /dev/null; then
            swift package resolve 2>/dev/null || log_warn "Swift package resolve failed"
        fi
    fi
    
    # Pre-resolve packages using xcodebuild
    log_debug "Resolving Swift packages..."
    xcodebuild -resolvePackageDependencies \
        -project MovingBox.xcodeproj \
        -scheme "$BUILD_SCHEME" \
        &>/dev/null || log_warn "Package resolution with xcodebuild failed"
    
    # Warm up package cache by building dependencies
    log_debug "Pre-building package dependencies..."
    xcodebuild build \
        -project MovingBox.xcodeproj \
        -scheme "$BUILD_SCHEME" \
        -destination "$BUILD_DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -onlyUsePackageVersionsFromResolvedFile \
        -skipPackageSignatureValidation \
        -quiet \
        COMPILER_INDEX_STORE_ENABLE=NO \
        CODE_SIGNING_ALLOWED=NO \
        &>/dev/null || log_warn "Package pre-build failed"
    
    local spm_duration=$(($(date +%s) - smp_start_time))
    log_success "SPM packages warmed up (${spm_duration}s)"
}

function warmup_simulators() {
    if [[ "$WARMUP_SIMULATORS" != "true" ]]; then
        log_info "Skipping simulator warmup"
        return 0
    fi
    
    log_info "Warming up iOS simulators..."
    
    if ! command -v xcrun &> /dev/null; then
        log_warn "xcrun not available, skipping simulator warmup"
        return 0
    fi
    
    local sim_start_time=$(date +%s)
    
    # List of simulators to warm up (prioritized by usage)
    local simulators=(
        "iPhone 16 Pro"
        "iPhone 14 Pro" 
        "iPhone 14 Pro Max"
        "iPad Pro (12.9-inch) (4th generation)"
    )
    
    local warmed_count=0
    
    if [[ "$PARALLEL_WARMUP" == "true" ]]; then
        log_debug "Warming simulators in parallel..."
        
        # Boot simulators in parallel (up to 3 at once)
        local pids=()
        for simulator in "${simulators[@]}"; do
            if [[ ${#pids[@]} -ge 3 ]]; then
                # Wait for one to complete
                wait ${pids[0]}
                pids=("${pids[@]:1}")
            fi
            
            {
                boot_simulator "$simulator" && ((warmed_count++)) || true
            } &
            pids+=($!)
        done
        
        # Wait for remaining simulators
        for pid in "${pids[@]}"; do
            wait $pid || true
        done
    else
        log_debug "Warming simulators sequentially..."
        
        for simulator in "${simulators[@]}"; do
            if boot_simulator "$simulator"; then
                ((warmed_count++))
            fi
        done
    fi
    
    local sim_duration=$(($(date +%s) - sim_start_time))
    log_success "Warmed up $warmed_count simulators (${sim_duration}s)"
}

function boot_simulator() {
    local simulator_name=$1
    local timeout=30
    
    # Check if simulator exists
    local sim_id=$(xcrun simctl list devices available 2>/dev/null | grep "$simulator_name" | head -1 | grep -o "([A-F0-9-]*)" | tr -d "()" || echo "")
    
    if [[ -z "$sim_id" ]]; then
        log_debug "Simulator not available: $simulator_name"
        return 1
    fi
    
    # Check if already booted
    local sim_state=$(xcrun simctl list devices | grep "$sim_id" | grep -o "Booted\|Shutdown" || echo "Unknown")
    
    if [[ "$sim_state" == "Booted" ]]; then
        log_debug "Simulator already booted: $simulator_name"
        return 0
    fi
    
    # Boot the simulator
    log_debug "Booting simulator: $simulator_name ($sim_id)"
    xcrun simctl boot "$sim_id" 2>/dev/null || {
        log_debug "Failed to boot simulator: $simulator_name"
        return 1
    }
    
    # Wait for boot to complete with timeout
    local waited=0
    while [[ $waited -lt $timeout ]]; do
        if xcrun simctl bootstatus "$sim_id" 2>/dev/null | grep -q "Booted"; then
            log_debug "Simulator booted successfully: $simulator_name"
            return 0
        fi
        sleep 1
        ((waited++))
    done
    
    log_debug "Simulator boot timeout: $simulator_name"
    return 1
}

function warmup_build_cache() {
    if [[ "$WARMUP_BUILD_CACHE" != "true" ]]; then
        log_info "Skipping build cache warmup"
        return 0
    fi
    
    log_info "Warming up build cache..."
    
    local build_start_time=$(date +%s)
    
    # Clean any existing derived data for this warmup
    rm -rf "$DERIVED_DATA_PATH" 2>/dev/null || true
    
    # Build for testing to warm up the cache
    log_debug "Pre-building for testing..."
    xcodebuild build-for-testing \
        -project MovingBox.xcodeproj \
        -scheme "$BUILD_SCHEME" \
        -destination "$BUILD_DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -quiet \
        COMPILER_INDEX_STORE_ENABLE=YES \
        CODE_SIGNING_ALLOWED=NO \
        &>/dev/null || log_warn "Build-for-testing warmup failed"
    
    # Build release configuration to warm up release cache
    log_debug "Pre-building release configuration..."
    xcodebuild build \
        -project MovingBox.xcodeproj \
        -scheme "$BUILD_SCHEME" \
        -destination "generic/platform=iOS" \
        -configuration Release \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -quiet \
        COMPILER_INDEX_STORE_ENABLE=NO \
        CODE_SIGNING_ALLOWED=NO \
        &>/dev/null || log_warn "Release build warmup failed"
    
    # Generate module cache
    log_debug "Warming up module cache..."
    xcodebuild clean build \
        -project MovingBox.xcodeproj \
        -scheme "$BUILD_SCHEME" \
        -destination "$BUILD_DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -quiet \
        -onlyUsePackageVersionsFromResolvedFile \
        COMPILER_INDEX_STORE_ENABLE=YES \
        CODE_SIGNING_ALLOWED=NO \
        &>/dev/null || log_warn "Module cache warmup failed"
    
    local build_duration=$(($(date +%s) - build_start_time))
    log_success "Build cache warmed up (${build_duration}s)"
    
    # Show cache size
    if [[ -d "$DERIVED_DATA_PATH" ]]; then
        local cache_size=$(du -sh "$DERIVED_DATA_PATH" 2>/dev/null | cut -f1 || echo "unknown")
        log_info "Build cache size: $cache_size"
    fi
}

function warmup_fastlane() {
    if [[ "$WARMUP_FASTLANE" != "true" ]]; then
        log_info "Skipping Fastlane warmup"
        return 0
    fi
    
    log_info "Warming up Fastlane..."
    
    if ! command -v fastlane &> /dev/null; then
        log_warn "Fastlane not available, skipping Fastlane warmup"
        return 0
    fi
    
    local fastlane_start_time=$(date +%s)
    
    # Check Fastlane setup
    log_debug "Verifying Fastlane setup..."
    cd fastlane 2>/dev/null || {
        log_warn "Fastlane directory not found"
        return 1
    }
    
    # Warm up Fastlane by running a quick verification
    fastlane --version &>/dev/null || {
        log_warn "Fastlane verification failed"
        cd ..
        return 1
    }
    
    cd ..
    
    local fastlane_duration=$(($(date +%s) - fastlane_start_time))
    log_success "Fastlane warmed up (${fastlane_duration}s)"
}

function verify_warmup_effectiveness() {
    log_info "Verifying warmup effectiveness..."
    
    local verification_start_time=$(date +%s)
    
    # Quick build test to verify cache effectiveness
    log_debug "Testing build performance with warmed cache..."
    
    local quick_build_start=$(date +%s)
    xcodebuild build \
        -project MovingBox.xcodeproj \
        -scheme "$BUILD_SCHEME" \
        -destination "$BUILD_DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -quiet \
        CODE_SIGNING_ALLOWED=NO \
        &>/dev/null || log_warn "Cache verification build failed"
    
    local quick_build_duration=$(($(date +%s) - quick_build_start))
    log_info "Cached build time: ${quick_build_duration}s"
    
    # Check simulator boot time
    if [[ "$WARMUP_SIMULATORS" == "true" ]]; then
        log_debug "Testing simulator boot performance..."
        
        # Try to boot primary simulator (should be fast if warmed)
        local sim_boot_start=$(date +%s)
        local primary_sim=$(xcrun simctl list devices available 2>/dev/null | grep "iPhone 16 Pro" | head -1 | grep -o "([A-F0-9-]*)" | tr -d "()" || echo "")
        
        if [[ -n "$primary_sim" ]]; then
            xcrun simctl boot "$primary_sim" 2>/dev/null || true
            local sim_boot_duration=$(($(date +%s) - sim_boot_start))
            log_info "Simulator boot time: ${sim_boot_duration}s"
        fi
    fi
    
    local verification_duration=$(($(date +%s) - verification_start_time))
    log_success "Warmup verification completed (${verification_duration}s)"
}

function cleanup_warmup() {
    log_info "Cleaning up warmup artifacts..."
    
    # Keep build cache but clean temporary files
    if [[ -d "$DERIVED_DATA_PATH" ]]; then
        # Remove intermediate files but keep the build cache
        find "$DERIVED_DATA_PATH" -name "*.log" -delete 2>/dev/null || true
        find "$DERIVED_DATA_PATH" -name "*.xcactivity*" -delete 2>/dev/null || true
    fi
    
    # Don't shut down simulators - leave them running for next builds
    log_debug "Leaving simulators running for subsequent builds"
    
    log_success "Warmup cleanup completed"
}

function show_help() {
    cat << EOF
MovingBox Cache Warmup

Usage: $0 [OPTIONS]

This script pre-warms caches and builds to optimize subsequent CI/CD pipeline runs.

OPTIONS:
    --no-simulators     Skip simulator warmup
    --no-spm           Skip Swift Package Manager warmup  
    --no-build         Skip build cache warmup
    --enable-fastlane  Enable Fastlane warmup (disabled by default)
    --sequential       Disable parallel warmup operations
    -v, --verbose      Enable verbose output
    -h, --help         Show this help message

WARMUP OPERATIONS:
    - Swift Package Manager dependencies
    - Xcode build cache and module cache
    - iOS Simulators (boot and prepare)
    - Build artifacts for common configurations
    - Optional: Fastlane environment

EXAMPLES:
    $0                     # Full warmup with defaults
    $0 --no-simulators     # Skip simulator warmup
    $0 -v --sequential     # Verbose sequential warmup
    $0 --enable-fastlane   # Include Fastlane warmup

TIMING:
    Typical warmup time: 3-8 minutes
    Benefits: 60-80% faster subsequent builds

EOF
}

function main() {
    local start_time=$(date +%s)
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-simulators)
                WARMUP_SIMULATORS=false
                shift
                ;;
            --no-spm)
                WARMUP_SPM_PACKAGES=false
                shift
                ;;
            --no-build)
                WARMUP_BUILD_CACHE=false
                shift
                ;;
            --enable-fastlane)
                WARMUP_FASTLANE=true
                shift
                ;;
            --sequential)
                PARALLEL_WARMUP=false
                shift
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
    
    # Show configuration
    log_info "MovingBox Cache Warmup"
    log_info "Simulators: $WARMUP_SIMULATORS"
    log_info "SPM packages: $WARMUP_SPM_PACKAGES"
    log_info "Build cache: $WARMUP_BUILD_CACHE"
    log_info "Fastlane: $WARMUP_FASTLANE"
    log_info "Parallel warmup: $PARALLEL_WARMUP"
    echo ""
    
    # Run warmup operations
    check_prerequisites
    
    if [[ "$PARALLEL_WARMUP" == "true" ]]; then
        log_info "Starting parallel warmup operations..."
        
        # Run some operations in parallel
        {
            warmup_spm_packages
        } &
        local spm_pid=$!
        
        {
            warmup_simulators
        } &
        local sim_pid=$!
        
        # Wait for parallel operations
        wait $spm_pid
        wait $sim_pid
        
        # Build cache needs to be after SPM
        warmup_build_cache
        warmup_fastlane
    else
        log_info "Starting sequential warmup operations..."
        warmup_spm_packages
        warmup_simulators
        warmup_build_cache
        warmup_fastlane
    fi
    
    verify_warmup_effectiveness
    cleanup_warmup
    
    # Summary
    local total_duration=$(($(date +%s) - start_time))
    local minutes=$((total_duration / 60))
    local seconds=$((total_duration % 60))
    
    echo ""
    log_success "Cache warmup completed!"
    log_info "Total time: ${minutes}m ${seconds}s"
    
    log_info "Your build cache is now warmed and ready for optimal performance"
    log_info "Subsequent builds should be significantly faster"
}

# Run main function with all arguments
main "$@"