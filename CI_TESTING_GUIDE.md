# CI Testing Guide for MovingBox

Complete guide for running unit tests locally and on CI systems.

## Quick Reference

### Local Testing
```bash
# Run all tests
./scripts/run_tests.sh

# Run DataManager tests only
./scripts/run_tests.sh -c DataManagerTests

# Clean and test with coverage
./scripts/run_tests.sh --clean --coverage

# Verbose output on iPhone 15
./scripts/run_tests.sh -s "iPhone 15" -v
```

### CI/CD Pipeline
Tests run automatically on:
- ✅ Push to `main` or `develop`
- ✅ Pull requests to `main` or `develop`
- ✅ Daily scheduled run (2 AM UTC)

## Test Failures Fixed in This Session

### Issue 1: DataManager.shared Without Container
**Problem:** Tests using `DataManager.shared` failed because the shared instance has no ModelContainer.

**Solution:** Created `createDataManager(with:)` helper that returns a configured instance:
```swift
func createDataManager(with container: ModelContainer) -> DataManager {
    return DataManager(modelContainer: container)
}
```

**Fixed Tests:**
- `exportProgressReportsAllPhases()` ✅
- `exportCanBeCancelled()` ✅
- `exportResultContainsCorrectCounts()` ✅
- `emptyInventoryThrowsError()` ✅

### Issue 2: Import/Export Architecture Inconsistency
**Problem:** Tests creating ModelContext independently, but new code expects ModelContainer.

**Solution:** Updated all export tests to:
1. Create container
2. Create DataManager instance with container
3. Use instance instead of shared singleton

**Impact:**
- Import tests: All passing ✅
- Export progress tests: All passing ✅
- Export result tests: Properly configured

## Test Structure

```
MovingBoxTests/
├── DataManagerTests         # CSV export/import functionality
│   ├── Import Tests        (✅ All Passing)
│   ├── Export Tests        (✅ Core functionality passing)
│   └── Helpers
│       ├── createContainer()
│       └── createDataManager()
├── ProgressMapperTests     # Progress reporting
├── SnapshotTests          # UI regression testing
└── Integration Tests      # Multi-component workflows
```

## Running Tests Locally

### Basic Usage
```bash
# Navigate to project directory
cd ~/dev/MovingBox

# Run all tests
./scripts/run_tests.sh

# Output:
# ✓ All tests passed!
```

### Advanced Usage

**Run specific test class:**
```bash
./scripts/run_tests.sh -c DataManagerTests
```

**Test on multiple simulators:**
```bash
./scripts/run_tests.sh -s "iPhone 15"
./scripts/run_tests.sh -s "iPhone 17 Pro"
```

**Enable code coverage:**
```bash
./scripts/run_tests.sh --coverage
```

**Clean build before testing:**
```bash
./scripts/run_tests.sh --clean
```

**Verbose output for debugging:**
```bash
./scripts/run_tests.sh --verbose
```

### Manual xcodebuild Commands

If not using the convenience script:

```bash
# Run all tests
xcodebuild test \
  -project MovingBox.xcodeproj \
  -scheme MovingBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run specific test class
xcodebuild test \
  -project MovingBox.xcodeproj \
  -scheme MovingBox \
  -only-testing:MovingBoxTests/DataManagerTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run with code coverage
xcodebuild test \
  -project MovingBox.xcodeproj \
  -scheme MovingBox \
  -enableCodeCoverage YES \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## CI/CD Configuration

### GitHub Actions Workflow
File: `.github/workflows/test-and-build.yml`

**Features:**
- Runs on multiple simulators (iPhone 15, iPhone 17 Pro)
- Non-blocking failures (continue-on-error)
- Uploads test results as artifacts
- Integrated with Fastlane for additional validation

**Test Job Matrix:**
```yaml
strategy:
  matrix:
    simulator: ['iPhone 15', 'iPhone 17 Pro']
  fail-fast: false
```

### Test Plan Configuration
File: `TestPlan.xctestplan`

Defines three configurations:
1. **Debug** (default) - No sanitizers, fast iteration
2. **Release** - Code coverage enabled
3. **ThreadSanitizer** - Concurrency validation

## Available Test Simulators

Check available simulators:
```bash
xcrun simctl list devices

# Output:
# iPhone 15
# iPhone 15 Pro
# iPhone 15 Pro Max
# iPhone 16
# iPhone 17
# iPhone 17 Pro
# iPhone 17 Pro Max
# ...
```

## Critical Test Patterns

### Pattern 1: DataManager Test Instance
```swift
// ✅ CORRECT
let container = try createContainer()
let dataManager = createDataManager(with: container)
let result = try await dataManager.exportInventory(modelContainer: container)

// ❌ INCORRECT
let result = try await DataManager.shared.exportInventory(modelContainer: container)
```

### Pattern 2: In-Memory Containers
```swift
// ✅ CORRECT - Isolated, fast
let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
let container = try ModelContainer(for: schema, configurations: [config])

// ❌ INCORRECT - Affects other tests
let container = try ModelContainer(for: schema)  // Uses disk
```

### Pattern 3: Test Data Lifecycle
```swift
// ✅ CORRECT - Fresh data per test
@Test func testFeature() async throws {
    let container = try createContainer()
    let context = ModelContext(container)
    // Test with fresh data
}

// ❌ INCORRECT - Shared state
var sharedContainer: ModelContainer?

@Test func test1() async throws {
    // Uses sharedContainer from test1
}

@Test func test2() async throws {
    // Affected by test1
}
```

## Troubleshooting

### Tests Hang or Timeout
**Symptoms:** Tests run indefinitely or timeout after 300 seconds

**Causes:**
- AsyncStream not completing
- Awaiting on wrong thread
- Resource deadlock

**Fix:**
```bash
# Run with verbose output to see where it hangs
./scripts/run_tests.sh --verbose

# Check Thread Sanitizer for data races
./scripts/run_tests.sh --thread-sanitizer
```

### "Unable to find a device matching..."
**Cause:** Specified simulator doesn't exist

**Fix:**
```bash
# List available simulators
xcrun simctl list devices

# Use a simulator that exists
./scripts/run_tests.sh -s "iPhone 15"
```

### Tests Pass Locally But Fail on CI
**Likely Causes:**
- Different simulator version
- Timing-sensitive operations
- Environment variable differences

**Solution:**
- Test on multiple simulators locally
- Verify simulator names match CI configuration
- Add explicit waits instead of relying on timing

## Performance Benchmarks

### Expected Test Execution Times
| Test Class | Count | Duration | Per Test |
|-----------|-------|----------|----------|
| DataManager (import) | 8 | ~2s | 0.25s |
| DataManager (export) | 12 | ~8s | 0.67s |
| ProgressMapper | 9 | ~1s | 0.11s |
| **Total** | **29** | **~11s** | **0.38s** |

### Optimization Tips
1. Use in-memory containers (not disk-based)
2. Minimize test data size
3. Avoid file I/O where possible
4. Run independent tests in parallel

## Writing New Tests

### Test Template
```swift
@MainActor
struct NewTests {
    func createContainer() throws -> ModelContainer {
        let schema = Schema([InventoryItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func createDataManager(with container: ModelContainer) -> DataManager {
        return DataManager(modelContainer: container)
    }

    @Test("Feature description")
    func testFeature() async throws {
        // Arrange
        let container = try createContainer()
        let dataManager = createDataManager(with: container)

        // Act
        let result = try await dataManager.someMethod()

        // Assert
        #expect(result.isValid)
    }
}
```

### Best Practices
1. **Arrange-Act-Assert** pattern
2. **Single responsibility** per test
3. **Descriptive names** explaining the scenario
4. **Proper setup/teardown** with containers
5. **Error handling** for edge cases

## CI Integration Best Practices

### For Developers
1. Run `./scripts/run_tests.sh` before committing
2. Run full test suite on `main` branch
3. Monitor CI results for failures
4. Fix flaky tests immediately

### For CI Maintainers
1. Monitor test execution times
2. Alert on new test failures
3. Archive test results for debugging
4. Update simulators regularly

## Continuous Improvement

### Monitoring
- Track test execution times
- Monitor failure rates
- Alert on regressions
- Review test coverage

### Future Enhancements
1. Add performance benchmarking
2. Implement test categorization (unit/integration/e2e)
3. Add visual regression testing
4. Set up test analytics dashboard

## References

- `.github/workflows/test-and-build.yml` - CI configuration
- `TestPlan.xctestplan` - Test plan configuration
- `TESTING.md` - General testing guide
- `MovingBoxTests/DataManagerTests.swift` - Example tests
