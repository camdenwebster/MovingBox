# MovingBox Testing Guide

This document describes how to run tests locally and on CI systems for the MovingBox iOS app.

## Quick Start

### Run All Tests
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBox
```

### Run Specific Test Suite
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBox \
  -only-testing:MovingBoxTests/DataManagerTests
```

### Run Tests on Specific Simulator
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Available Simulators

Check available simulators with:
```bash
xcrun simctl list devices
```

Commonly used for CI:
- `iPhone 15` - Standard configuration
- `iPhone 17 Pro` - Latest model (recommended)
- `iPad (A16)` - iPad testing

## Test Organization

### DataManager Tests (`DataManagerTests`)
Tests for CSV export/import functionality with SwiftData.

**Key Points:**
- ✅ Import tests: All passing (proper ModelContainer usage)
- ✅ Export tests: Mixed results (some are integration tests requiring full app state)
- Uses in-memory SwiftData containers for isolation
- Each test creates its own container

**Run DataManager tests:**
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBox \
  -only-testing:MovingBoxTests/DataManagerTests
```

**Run specific DataManager test:**
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBox \
  -only-testing:MovingBoxTests/DataManagerTests/importWithLocationsAndItemsReturnsCounts
```

## Critical Test Patterns

### 1. DataManager Instance Creation
**Problem:** `DataManager.shared` has no ModelContainer in tests
**Solution:** Create test instance with container

```swift
// ❌ DON'T
let result = try await DataManager.shared.exportInventory(modelContainer: container)

// ✅ DO
let dataManager = DataManager(modelContainer: container)
let result = try await dataManager.exportInventory(modelContainer: container)
```

### 2. SwiftData Container Setup
Always create in-memory containers for test isolation:

```swift
func createContainer() throws -> ModelContainer {
    let schema = Schema([InventoryItem.self, InventoryLocation.self, InventoryLabel.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}
```

### 3. ModelContext Lifecycle
Create fresh context per test:

```swift
let container = try createContainer()
let context = ModelContext(container)

// Add test data
let item = InventoryItem()
context.insert(item)
try context.save()

// Run test
// ...
```

## CI/CD Integration

### GitHub Actions Setup

See `.github/workflows/test-and-build.yml` for the full configuration.

**Key Features:**
- ✅ Runs on every push to main branch
- ✅ Runs on pull requests
- ✅ Runs on schedule (daily)
- ✅ Caches Xcode build artifacts
- ✅ Generates test reports

**Example Workflow:**
```yaml
name: Test and Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC

jobs:
  test:
    runs-on: macos-latest
    strategy:
      matrix:
        simulator: ['iPhone 15', 'iPhone 17 Pro']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-xcode@v1
        with:
          xcode-version: latest
      - name: Run Tests
        run: |
          xcodebuild test \
            -project MovingBox.xcodeproj \
            -scheme MovingBox \
            -destination "platform=iOS Simulator,name=${{ matrix.simulator }}" \
            -resultBundlePath test-results.xcresult
      - name: Upload Results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results-${{ matrix.simulator }}
          path: test-results.xcresult
```

### Local CI Simulation

Test your changes exactly as CI will:

```bash
# Clean build
rm -rf ~/Library/Developer/Xcode/DerivedData

# Run tests like CI
xcodebuild clean test \
  -project MovingBox.xcodeproj \
  -scheme MovingBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -resultBundlePath ~/Desktop/test-results.xcresult
```

## Troubleshooting

### Issue: "Unable to find a device matching..."
**Solution:** Verify available simulators:
```bash
xcrun simctl list devices
```
Use a simulator that exists on your system.

### Issue: Tests hang or timeout
**Likely Cause:**
- AsyncStream not completing
- Awaiting on wrong thread
- Resource locks

**Solution:**
- Check test output with `-verbose` flag
- Verify @MainActor requirements are met
- Check for deadlocks in async code

**Run with verbose output:**
```bash
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -verbose
```

### Issue: Tests pass locally but fail on CI
**Likely Causes:**
- Different simulator characteristics
- Timing-sensitive tests
- Environment differences

**Solution:**
- Test on multiple simulators locally
- Add explicit waits instead of relying on timing
- Check for environment variables in CI

## Writing New Tests

### Using Test Helpers

```swift
@MainActor
struct NewFeatureTests {
    func createContainer() throws -> ModelContainer {
        let schema = Schema([InventoryItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func createDataManager(with container: ModelContainer) -> DataManager {
        return DataManager(modelContainer: container)
    }

    @Test("Feature works correctly")
    func testFeature() async throws {
        let container = try createContainer()
        let dataManager = createDataManager(with: container)

        // Test code...
    }
}
```

### Test Data Patterns

**Good:**
- Minimal setup for each test
- Use builder pattern for complex objects
- Create data directly with initializers

**Avoid:**
- Shared state between tests
- Hardcoded file paths (use FileManager.default.temporaryDirectory)
- Depending on launch order

## Performance Considerations

### Test Execution Time
- Average test: ~0.5-1.0 seconds
- Complex tests (export/import): ~1-2 seconds
- Total test suite: ~30-45 seconds

### Optimizing Tests
1. Use in-memory containers (not disk-based)
2. Minimize test data (smaller datasets where possible)
3. Run independent tests in parallel (Xcode handles this)
4. Avoid file I/O where possible

## Known Issues & Workarounds

### Issue: ModelContext warnings in Swift 6
**Status:** Expected, documented in SWIFT6_CONCURRENCY_FIXES.md
**Action:** No fix needed - warnings are safe to ignore

### Issue: Some export tests have timing sensitivity
**Status:** Being investigated
**Workaround:** Tests typically pass on retry

## Continuous Improvement

### Adding New Test Coverage
1. Write failing test first (TDD)
2. Implement feature to pass test
3. Refactor for clarity
4. Run full test suite to ensure no regressions
5. Commit with test changes

### Test Coverage Goals
- Core business logic: >90%
- UI layer: >50% (snapshot tests)
- Error handling: >80%

## Additional Resources

- Swift Testing Framework: https://developer.apple.com/documentation/testing
- SwiftData Documentation: https://developer.apple.com/swiftdata/
- Xcode Build System: https://developer.apple.com/documentation/xcode

## Questions?

Refer to:
- `SWIFT6_CONCURRENCY_FIXES.md` - Concurrency details
- `spec/swift-concurrency-improvements-plan.md` - Architecture decisions
- Test files themselves for examples
