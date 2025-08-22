# Build Caching & Optimization Strategy

This document outlines the comprehensive caching and optimization strategy for MovingBox CI/CD pipelines on self-hosted Orchard/Tart runners.

## Overview

Our caching strategy is designed to:
- **Minimize build times** by reusing compiled artifacts
- **Optimize resource usage** on self-hosted runners
- **Ensure consistency** across different build environments
- **Scale efficiently** with team growth

## Caching Architecture

### 1. Multi-Layer Caching Strategy

```
Layer 1: GitHub Actions Cache (Dependencies)
├── Swift Package Manager packages
├── CocoaPods dependencies  
└── Node.js packages (if any)

Layer 2: Local Runner Cache (Build Artifacts)
├── Xcode DerivedData
├── Swift module cache
└── Compiled frameworks

Layer 3: Orchard/Tart VM Cache (Environment)
├── Pre-installed dependencies
├── Xcode installations
└── Common tools (fastlane, etc.)
```

## Implementation Details

### Swift Package Manager Caching

**Cache Key Strategy:**
```yaml
key: ${{ runner.os }}-spm-${{ hashFiles('MovingBox.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved') }}
restore-keys: |
  ${{ runner.os }}-spm-
```

**Cached Paths:**
- `~/Library/Caches/org.swift.swiftpm/`
- `~/Library/Developer/Xcode/DerivedData/MovingBox-*/SourcePackages/`

**Cache Invalidation:**
- Automatic when `Package.resolved` changes
- Manual invalidation via workflow dispatch
- Weekly cleanup of stale entries

### Xcode DerivedData Optimization

**Location Management:**
```bash
# Use consistent DerivedData location
export DERIVED_DATA_PATH="~/Library/Developer/Xcode/DerivedData/MovingBox-CI"
```

**Cache Strategy:**
- Keep successful build artifacts for 24 hours
- Separate cache keys for Debug/Release configurations
- Clean old builds after successful completion

**Cache Paths:**
- `~/Library/Developer/Xcode/DerivedData/MovingBox-*/`
- `~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/`

### Simulator Management

**Optimization Techniques:**
- Boot simulators in parallel for different jobs
- Reuse booted simulators when possible
- Clean up unused simulators after job completion
- Pre-warm simulators with common test data

**Cache Strategy:**
```bash
# Simulator runtime caching
~/Library/Developer/CoreSimulator/Profiles/Runtimes/
```

## Performance Optimizations

### 1. Build Parallelization

**Xcode Build Settings:**
```bash
# Optimize build performance
-jobs $(sysctl -n hw.ncpu)  # Use all CPU cores
-parallel-testing-enabled YES
-parallel-testing-worker-count 4
```

**Swift Compilation:**
```bash
# Swift compiler optimizations
SWIFT_COMPILATION_MODE = wholemodule  # For Release builds
SWIFT_OPTIMIZATION_LEVEL = -O         # For Release builds
```

### 2. Test Execution Optimization

**Parallel Testing:**
- Run unit tests in parallel across multiple schemes
- Distribute UI tests across different simulators
- Use test plans to optimize test execution order

**Test Data Management:**
```bash
# Optimize test data loading
"Use-Test-Data"     # Load minimal test dataset
"Mock-Data"         # Use in-memory mocks
"Disable-Animations" # Speed up UI tests
```

### 3. Artifact Management

**Build Artifact Caching:**
- Cache successful builds for rapid deployment
- Store intermediate build products
- Reuse compiled frameworks across builds

**Upload Optimization:**
- Compress artifacts before upload
- Use parallel upload when possible
- Implement smart artifact retention policies

## Orchard/Tart Specific Optimizations

### 1. VM Image Optimization

**Pre-installed Tools:**
```dockerfile
# Base VM image should include:
- Xcode 16.2 (latest stable)
- Swift Package Manager
- Fastlane latest
- Claude Code CLI
- Common iOS simulators
- Build dependencies
```

**VM Configuration:**
```yaml
# Optimal VM specs for iOS builds
CPU: 8 cores
Memory: 32GB
Storage: 500GB SSD
Network: High bandwidth
```

### 2. Runner Pool Management

**Auto-scaling Strategy:**
- Scale up during peak hours (business hours)
- Scale down during off-hours
- Maintain minimum pool for nightly builds
- Emergency scaling for release builds

**Load Balancing:**
```bash
# Distribute builds across available runners
- Primary pool: 4-6 runners (standard builds)
- Release pool: 2-3 runners (production builds)  
- Testing pool: 2-3 runners (comprehensive testing)
```

### 3. Network Optimization

**Download Optimization:**
- Cache Xcode downloads locally
- Use local package mirrors when possible
- Implement bandwidth throttling during peak hours

**Upload Optimization:**
- Compress TestFlight uploads
- Use parallel upload streams
- Implement retry logic with exponential backoff

## Cache Management Scripts

### 1. Cache Health Check

```bash
#!/bin/bash
# scripts/check-cache-health.sh

echo "🔍 Checking cache health..."

# Check SPM cache size
SPM_CACHE_SIZE=$(du -sh ~/Library/Caches/org.swift.swiftpm/ 2>/dev/null | cut -f1 || echo "0B")
echo "📦 SPM Cache: $SPM_CACHE_SIZE"

# Check DerivedData size
DERIVED_DATA_SIZE=$(du -sh ~/Library/Developer/Xcode/DerivedData/ 2>/dev/null | cut -f1 || echo "0B") 
echo "🏗️ DerivedData: $DERIVED_DATA_SIZE"

# Check simulator cache
SIMULATOR_CACHE_SIZE=$(du -sh ~/Library/Developer/CoreSimulator/ 2>/dev/null | cut -f1 || echo "0B")
echo "📱 Simulators: $SIMULATOR_CACHE_SIZE"

# Cache hit rate estimation
GITHUB_CACHE_HITS=$(gh cache list --json key,cacheHitCount | jq '[.[] | .cacheHitCount] | add')
echo "📊 GitHub Cache Hits: ${GITHUB_CACHE_HITS:-0}"

echo "✅ Cache health check completed"
```

### 2. Smart Cache Cleanup

```bash
#!/bin/bash  
# scripts/smart-cache-cleanup.sh

echo "🧹 Starting smart cache cleanup..."

# Clean old DerivedData (older than 7 days)
find ~/Library/Developer/Xcode/DerivedData/ -name "*MovingBox*" -mtime +7 -exec rm -rf {} + 2>/dev/null

# Clean unused SPM packages
swift package clean-cache 2>/dev/null || true

# Clean old simulators
xcrun simctl delete unavailable
xcrun simctl list devices | grep "Shutdown" | grep -E "\(iOS [0-9]" | head -20 | cut -d "(" -f2 | cut -d ")" -f1 | xargs -I {} xcrun simctl delete {} 2>/dev/null || true

# Clean fastlane artifacts
rm -rf ~/Library/Logs/fastlane/
rm -rf ./fastlane/test_output/

echo "✅ Smart cleanup completed"
```

### 3. Cache Warm-up

```bash
#!/bin/bash
# scripts/cache-warmup.sh  

echo "🔥 Warming up build caches..."

# Pre-resolve Swift packages
swift package resolve

# Pre-build common targets
xcodebuild -project MovingBox.xcodeproj \
  -scheme MovingBox \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath ~/Library/Developer/Xcode/DerivedData/MovingBox-CI \
  build-for-testing

# Pre-boot common simulators
xcrun simctl boot "iPhone 16 Pro" 2>/dev/null || true
xcrun simctl boot "iPhone 14 Pro" 2>/dev/null || true

echo "✅ Cache warm-up completed"
```

## Performance Monitoring

### 1. Build Time Tracking

**Metrics to Monitor:**
- Total build duration
- Individual phase timing (dependencies, compilation, linking, testing)
- Cache hit/miss ratios
- Resource utilization (CPU, memory, disk I/O)

**Implementation:**
```yaml
# Add to workflows
- name: Track Build Performance  
  run: |
    echo "build_start_time=$(date +%s)" >> $GITHUB_ENV
    # ... build steps ...
    BUILD_DURATION=$(($(date +%s) - $build_start_time))
    echo "Build completed in ${BUILD_DURATION}s"
```

### 2. Cache Effectiveness

**Key Performance Indicators:**
- Cache hit ratio (target: >80%)
- Average download time reduction
- Build time improvement percentage
- Storage efficiency metrics

**Monitoring Script:**
```bash
# Monitor cache effectiveness
CACHE_HIT_RATIO=$(calculate_cache_hit_ratio)
if [[ "$CACHE_HIT_RATIO" -lt "70" ]]; then
  echo "⚠️ Cache hit ratio below threshold: $CACHE_HIT_RATIO%"
  # Trigger cache optimization
fi
```

## Best Practices

### 1. Cache Key Design

**Principles:**
- Use semantic versioning for cache keys
- Include relevant dependencies in key calculation  
- Avoid overly specific keys that reduce hit rates
- Implement fallback keys for partial cache recovery

**Example:**
```yaml
# Good cache key strategy
key: ${{ runner.os }}-v2-spm-${{ hashFiles('Package.resolved', '*.xcodeproj/**') }}
restore-keys: |
  ${{ runner.os }}-v2-spm-
  ${{ runner.os }}-v2-
```

### 2. Resource Management

**Guidelines:**
- Set appropriate timeout values for cache operations
- Implement graceful degradation when cache is unavailable
- Monitor and alert on cache storage usage
- Regular cleanup of stale cache entries

### 3. Security Considerations

**Cache Security:**
- Never cache sensitive information (secrets, keys)
- Validate cache integrity before use
- Implement access controls for shared caches
- Regular security audits of cached content

## Troubleshooting Guide

### Common Cache Issues

**1. Cache Miss Despite No Changes**
```bash
# Debug cache key calculation
echo "Checking cache key components..."
echo "Package.resolved hash: $(shasum Package.resolved)"
echo "Project file hash: $(find . -name "*.xcodeproj" -exec shasum {} \;)"
```

**2. Build Performance Regression**  
```bash
# Analyze build performance
echo "Analyzing build performance..."
# Check for cache corruption
# Verify runner resource availability
# Review recent changes to build configuration
```

**3. Cache Storage Exhaustion**
```bash
# Emergency cache cleanup
echo "Emergency cache cleanup..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/org.swift.swiftpm/*
gh cache delete --all
```

## Advanced Optimizations

### 1. Distributed Caching

**Strategy:**
- Implement shared cache across runner instances
- Use network-attached storage for large artifacts
- Implement cache replication for high availability

### 2. Predictive Caching

**Approach:**
- Analyze historical build patterns
- Pre-cache likely needed dependencies
- Implement machine learning for cache prediction

### 3. Custom Cache Solutions

**Options:**
- Implement Redis-based build artifact cache
- Use CloudFlare for global cache distribution
- Custom S3-based cache with intelligent eviction

## Measurement & Optimization

### Performance Baselines

**Current Targets:**
- Cold build: < 10 minutes
- Cached build: < 3 minutes  
- Test execution: < 5 minutes
- Full pipeline: < 20 minutes

**Optimization Targets:**
- Cache hit ratio: > 85%
- Build time reduction: > 60%
- Resource utilization: > 80%
- Pipeline reliability: > 99%

### Continuous Improvement

**Process:**
1. **Weekly Performance Review** - Analyze build metrics
2. **Monthly Cache Optimization** - Tune cache strategies  
3. **Quarterly Infrastructure Review** - Evaluate runner performance
4. **Annual Strategy Review** - Update optimization approach

---

## Implementation Checklist

- [x] GitHub Actions cache configuration
- [x] SPM cache optimization  
- [x] DerivedData management
- [x] Simulator optimization
- [x] Cache health monitoring
- [x] Performance tracking
- [x] Cleanup automation
- [ ] Advanced distributed caching
- [ ] Predictive cache warming  
- [ ] Custom cache solutions

**Next Steps:**
1. Implement basic caching in all workflows
2. Deploy monitoring and alerting
3. Tune cache parameters based on usage patterns
4. Evaluate advanced optimization opportunities