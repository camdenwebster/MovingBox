# MovingBoxTests Directory - Code-Level Testing Best Practices

This directory contains unit tests, integration tests, and snapshot tests for the MovingBox iOS app using Swift Testing framework.

## Testing Philosophy and Strategy

### Test-Driven Development (TDD)
Follow the Red-Green-Refactor cycle as outlined in the `/unittest` slash command:
1. **Red Phase**: Write failing tests that define expected behavior
2. **Green Phase**: Implement minimal code to make tests pass
3. **Refactor Phase**: Improve code quality while maintaining green tests

### Testing Pyramid
MovingBox follows a comprehensive testing strategy across multiple levels:

```
        UI Tests (Few)
    Integration Tests (Some)  
Unit Tests (Many) + Snapshot Tests
```

## Test Categories and Coverage

### Unit Tests
**Purpose**: Test individual components in isolation
**Scope**: Single classes, functions, or small modules
**Examples**: `CurrencyFormatterTests`, `SettingsManagerTests`, `JWTManagerTests`

#### Model Testing
- **SwiftData Models**: Test model behavior, relationships, and constraints
- **Data Validation**: Verify business rule enforcement
- **Migration Logic**: Test model migrations and data transformations
- **Example**: `InventoryItemModelTests`, `HomeMigrationTests`

#### Service Testing  
- **Business Logic**: Test core service functionality
- **API Integration**: Mock external dependencies (OpenAI, RevenueCat)
- **Error Handling**: Verify proper error scenarios and recovery
- **Examples**: `OpenAIServiceTests`, `OptimizedImageManagerTests`, `OnboardingManagerTests`

#### Utility Testing
- **Helper Functions**: Test formatters, extensions, and utilities
- **Data Processing**: Verify data transformation logic
- **Example**: `CurrencyFormatterTests`

### Integration Tests
**Purpose**: Test interactions between multiple components
**Scope**: Multiple services, data flow, and system interactions
**Examples**: `MultiPhotoIntegrationTests`, `DataManagerTests`

#### Service Interactions
- **Multi-Component Flows**: Test services working together
- **Data Pipeline**: Verify end-to-end data processing
- **Cross-Service Communication**: Test service dependencies

#### AI Integration
- **OpenAI Service**: Test with mock and real API responses
- **Image Processing**: Verify image preparation and analysis
- **Response Parsing**: Test structured response handling
- **Examples**: `OpenAIMultiPhotoIntegrationTests`, `OpenAILiveDebugTests`

#### Data Management
- **Import/Export**: Test CSV generation and ZIP archive creation
- **File Operations**: Verify file system operations
- **Data Integrity**: Ensure data consistency across operations
- **Example**: `DataManagerTests`

### System Tests
**Purpose**: Test complete user workflows and system behavior
**Scope**: End-to-end scenarios, performance, and reliability

#### Performance Testing
- **Memory Usage**: Monitor memory consumption with large datasets
- **Processing Time**: Verify acceptable response times
- **Resource Management**: Test resource cleanup and optimization
- **Example**: Memory performance testing in `MultiPhotoIntegrationTests`

#### Data Flow Testing
- **Camera → AI → Storage**: Complete photo processing pipeline
- **Import → Process → Export**: Full data lifecycle
- **Sync Operations**: CloudKit integration testing

### Snapshot Tests
**Purpose**: Visual regression testing for UI components
**Scope**: SwiftUI view rendering consistency
**Location**: `SnapshotTests.swift` with `__Snapshots__/` directory

#### Coverage Areas
- All major SwiftUI views in light and dark modes
- Different data states (empty, populated, mock data)
- Various device sizes and orientations
- Pro vs free feature states

## Swift Testing Framework Usage

### Test Structure
```swift
@MainActor
struct ServiceNameTests {
    
    @Test("Descriptive test name explaining what is verified")
    func testSpecificScenario() async throws {
        // Arrange: Set up test data and dependencies
        let testObject = createTestObject()
        
        // Act: Execute the functionality being tested
        let result = await testObject.performOperation()
        
        // Assert: Verify expected outcomes
        #expect(result.isSuccess)
        #expect(result.value == expectedValue)
    }
}
```

### Test Naming Conventions
- **Test Functions**: `testFunctionality` describing specific behavior
- **Test Attributes**: Descriptive strings explaining what is verified
- **Examples**: 
  - `@Test("Export with items creates zip file")`
  - `@Test("Multi-photo capture and AI analysis integration")`
  - `@Test("Memory performance with multiple high-resolution images")`

### Assertion Methods
- **`#expect(condition)`**: Basic boolean assertions
- **`#require(condition)`**: Assertions that stop test execution on failure
- **`#expect(throws: ErrorType.self)`**: Exception testing
- **`await #expect(throws: ErrorType.self)`**: Async exception testing

## Testing Patterns for MovingBox

### SwiftData Model Testing
```swift
@MainActor
struct ModelTests {
    func createTestContainer() throws -> ModelContainer {
        let schema = Schema([InventoryItem.self, InventoryLocation.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
    
    @Test("Model relationship behavior")
    func testModelRelationships() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        
        // Test model interactions
        let item = InventoryItem()
        let location = InventoryLocation(name: "Test")
        item.location = location
        
        context.insert(item)
        context.insert(location)
        try context.save()
        
        #expect(item.location?.name == "Test")
        #expect(location.items.contains(item))
    }
}
```

### Service Testing with Mocks
```swift
@Test("Service handles API errors gracefully")
func testServiceErrorHandling() async throws {
    // Create service with mock dependencies
    let settings = SettingsManager()
    settings.apiKey = "test_key"
    
    let service = OpenAIService(
        imageBase64: "test_data",
        settings: settings,
        modelContext: mockContext
    )
    
    // Test error scenarios
    #expect(throws: OpenAIService.ServiceError.self) {
        try await service.processWithInvalidData()
    }
}
```

### Integration Testing Patterns
```swift
@Test("Complete workflow integration")
func testEndToEndWorkflow() async throws {
    // Setup multiple components
    let container = try createTestContainer()
    let imageManager = OptimizedImageManager.shared
    let aiService = OpenAIService(...)
    
    // Test complete workflow
    let images = createTestImages(count: 3)
    let savedURLs = try await imageManager.saveImages(images)
    let aiResults = try await aiService.analyze(images)
    
    // Verify integration
    #expect(savedURLs.count == 3)
    #expect(aiResults.isValid)
}
```

### Performance Testing
```swift
@Test("Memory usage stays within bounds")
func testMemoryPerformance() async throws {
    let startMemory = getCurrentMemoryUsage()
    
    // Perform memory-intensive operations
    let largeImages = createLargeTestImages(count: 10)
    try await processLargeImageSet(largeImages)
    
    let endMemory = getCurrentMemoryUsage()
    let memoryIncrease = endMemory - startMemory
    
    // Verify memory usage is reasonable
    #expect(memoryIncrease < 100_000_000, "Memory increase should be under 100MB")
}
```

## Test Data Management

### TestData.swift Integration
```swift
// Leverage existing test data utilities
let testItem = TestData.sampleInventoryItem()
let testLocation = TestData.sampleLocation()
let mockImages = TestData.sampleImages()
```

### Test Data Best Practices
- **Deterministic**: Use consistent, predictable test data
- **Isolated**: Each test creates its own data context
- **Realistic**: Test data should reflect real-world usage
- **Edge Cases**: Include boundary conditions and error scenarios

### Mock Strategies
```swift
// Protocol-based mocking
protocol APIServiceProtocol {
    func fetchData() async throws -> Data
}

class MockAPIService: APIServiceProtocol {
    var shouldSucceed = true
    var mockResponse: Data?
    
    func fetchData() async throws -> Data {
        if shouldSucceed {
            return mockResponse ?? Data()
        } else {
            throw APIError.networkFailure
        }
    }
}
```

## Error Handling Testing

### Comprehensive Error Coverage
```swift
@Test("Handles all error scenarios")
func testErrorScenarios() async throws {
    let service = DataManager.shared
    
    // Test different error conditions
    #expect(throws: DataManager.DataError.nothingToExport) {
        try await service.exportEmptyInventory()
    }
    
    #expect(throws: DataManager.DataError.invalidZipFile) {
        try await service.importInvalidZip()
    }
    
    // Test error recovery
    let result = await service.handleErrorGracefully()
    #expect(result.isRecovered)
}
```

### Error Type Verification
```swift
do {
    try await riskyOperation()
    #expect(Bool(false), "Expected operation to throw error")
} catch let error as SpecificError {
    #expect(error.code == expectedErrorCode)
} catch {
    #expect(Bool(false), "Unexpected error type: \(error)")
}
```

## Async Testing Patterns

### Concurrent Operation Testing
```swift
@Test("Handles concurrent operations safely")
func testConcurrentSafety() async throws {
    let actor = DataActor()
    
    // Test concurrent access
    let results = await withTaskGroup(of: Bool.self) { group in
        for i in 0..<10 {
            group.addTask {
                await actor.safeOperation(id: i)
            }
        }
        
        var successes: [Bool] = []
        for await result in group {
            successes.append(result)
        }
        return successes
    }
    
    #expect(results.allSatisfy { $0 == true })
}
```

### Timeout Testing
```swift
@Test("Operations complete within timeout")
func testOperationTimeout() async throws {
    let service = SlowService()
    
    let result = try await withTimeout(seconds: 5) {
        try await service.longRunningOperation()
    }
    
    #expect(result.isSuccess)
}
```

## Image Processing Testing

### OptimizedImageManager Testing
```swift
@Test("Image optimization maintains quality")
func testImageOptimization() async throws {
    let originalImage = createLargeTestImage(size: 4000)
    let itemId = UUID().uuidString
    
    let optimizedURL = try await OptimizedImageManager.shared.saveImage(
        originalImage, 
        id: itemId
    )
    
    let optimizedData = try Data(contentsOf: optimizedURL)
    let optimizedImage = UIImage(data: optimizedData)
    
    // Verify optimization
    #expect(optimizedData.count < 2_000_000) // Under 2MB
    #expect(optimizedImage != nil) // Still valid image
    #expect(optimizedImage!.size.width <= 1024) // Reasonable dimensions
}
```

### Multi-Photo Testing
```swift
@Test("Multi-photo workflow handles edge cases")
func testMultiPhotoEdgeCases() async throws {
    let images = createTestImages(count: 0) // Empty array
    let result = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: images)
    
    #expect(result.isEmpty)
    
    // Test with maximum images
    let maxImages = createTestImages(count: 20)
    let maxResult = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: maxImages)
    
    #expect(maxResult.count <= 10) // Verify limits are enforced
}
```

## Test Execution and Configuration

### Launch Arguments for Testing
```swift
// In test setup
app.launchArguments = [
    "Use-Test-Data",
    "Mock-Data", 
    "Disable-Animations",
    "Skip-Onboarding"
]
```

### Test Isolation
```swift
override func setUp() async throws {
    // Create isolated test environment
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try ModelContainer(for: schema, configurations: [config])
    
    // Reset global state
    await resetTestEnvironment()
}

override func tearDown() async throws {
    // Clean up test resources
    await cleanupTestFiles()
    container = nil
}
```

## CI/CD Integration

### Test Commands
Reference the existing test execution commands:
```bash
# Run all unit tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run snapshot tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -testPlan MovingBoxSnapshotTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'
```

### Performance Monitoring
- Track test execution times
- Monitor memory usage during tests
- Verify test reliability and consistency
- Generate coverage reports

## Best Practices Summary

### Test Design
- **Single Responsibility**: Each test verifies one specific behavior
- **Fast Execution**: Tests should run quickly and reliably
- **Independent**: Tests don't depend on each other or external state
- **Readable**: Test names and structure should be self-documenting

### MovingBox-Specific Guidelines
- **Use In-Memory Containers**: For SwiftData testing isolation
- **Mock External Services**: OpenAI, RevenueCat, CloudKit integration
- **Test Image Processing**: Verify OptimizedImageManager functionality
- **Cover Error Scenarios**: Test all error paths and recovery mechanisms

### Maintenance
- **Keep Tests Updated**: Maintain tests as code evolves
- **Review Test Coverage**: Ensure critical paths are tested
- **Monitor Test Health**: Address flaky or slow tests
- **Document Complex Tests**: Explain non-obvious test logic

## Integration with Development Workflow

### Using the `/unittest` Slash Command
When writing new tests, use the established slash command:
```
/unittest Feature description or component to test
```

This will guide you through the TDD process following MovingBox-specific patterns and conventions.

### Code Review Focus
- Verify test coverage for new features
- Review test quality and maintainability
- Ensure proper mocking and isolation
- Check performance test coverage for critical paths

Remember: Tests are living documentation of expected behavior. Write them clearly, maintain them diligently, and use them to drive better design decisions.