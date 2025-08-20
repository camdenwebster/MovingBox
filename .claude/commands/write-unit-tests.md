# Write Unit Tests

Following Test-Driven Development (TDD) principles, write comprehensive unit tests for the MovingBox functionality described in: $ARGUMENTS

## TDD Approach

### Red Phase - Write Failing Tests
1. **Analyze Requirements**: Understand the expected functionality and behavior
2. **Design Test Cases**: Create test cases for expected input/output pairs
3. **Write Failing Tests**: Implement tests that currently fail (if functionality doesn't exist)
4. **Verify Failures**: Ensure tests fail for the right reasons

### Green Phase - Make Tests Pass
1. **Minimal Implementation**: Write just enough code to make tests pass
2. **Incremental Progress**: Build functionality step by step
3. **Maintain Focus**: Only implement what's needed for current tests

### Refactor Phase - Improve Code Quality
1. **Clean Up**: Improve code structure while keeping tests green
2. **Extract Common Patterns**: Identify reusable components
3. **Optimize Performance**: Address any performance concerns

## Testing Framework Guidelines

### Swift Testing Framework
- Use `@Test` attribute for test functions
- Implement descriptive test names that explain what's being tested
- Use appropriate assertion methods (`#expect`, `#require`)
- Organize tests logically within test classes

### Test Structure
```swift
@Test("Description of what this test verifies")
func testSpecificScenario() {
    // Arrange: Set up test data and dependencies
    // Act: Execute the functionality being tested
    // Assert: Verify expected outcomes
}
```

## MovingBox-Specific Testing Patterns

### SwiftData Model Testing
- Use in-memory containers for test isolation
- Create proper test data setup and teardown
- Test model relationships and constraints
- Verify data persistence and retrieval

### Service Testing
- Mock external dependencies (OpenAI API, RevenueCat, etc.)
- Test error handling scenarios thoroughly
- Verify proper async/await behavior
- Test concurrent access patterns for actors

### SwiftUI View Testing
- Test view state management
- Verify data binding functionality
- Test user interaction scenarios
- Mock @EnvironmentObject dependencies

### Image Processing Testing
- Test OptimizedImageManager functionality
- Verify image compression and storage
- Test migration from external storage
- Handle edge cases (corrupted images, storage limits)

## Test Categories

### Unit Tests
- **Models**: SwiftData model behavior, relationships, validation
- **Services**: Business logic, API integration, data processing
- **Utilities**: Helper functions, formatters, extensions
- **View Models**: State management, data transformation

### Integration Tests
- **Service Interactions**: Multiple services working together
- **Data Flow**: End-to-end data processing
- **AI Integration**: OpenAI service with real/mock responses
- **Subscription Flow**: RevenueCat integration testing

## Test Data Management

### Use TestData.swift
- Leverage existing test data utilities
- Create realistic but deterministic test scenarios
- Handle different app states (onboarded, subscribed, etc.)
- Provide edge case data for boundary testing

### Mock Data Strategy
- Create mock implementations of external services
- Use protocol-based mocking for better testability
- Provide controllable mock responses
- Test both success and failure scenarios

## Testing Best Practices

### Test Isolation
- Ensure tests don't depend on each other
- Clean up resources between tests
- Use fresh data containers for each test
- Reset global state when necessary

### Descriptive Testing
- Use clear, descriptive test names
- Write tests that serve as documentation
- Include comments for complex test scenarios
- Group related tests logically

### Edge Case Coverage
- Test boundary conditions
- Handle null/empty data scenarios
- Test maximum limits and constraints
- Verify error handling paths

### Performance Testing
- Include tests for performance-critical operations
- Test memory usage for large datasets
- Verify timeout handling
- Test concurrent operation behavior

## Specific Test Areas for MovingBox

### AI Integration Tests
- Test OpenAI Vision API request/response handling
- Verify structured response parsing
- Test rate limiting and retry logic
- Mock different AI response scenarios

### Image Management Tests
- Test image storage and retrieval
- Verify compression algorithms
- Test migration scenarios
- Handle storage quota limits

### Data Export Tests
- Test CSV generation accuracy
- Verify ZIP archive creation
- Test large dataset handling
- Verify data integrity in exports

### Navigation Tests
- Test Router navigation logic
- Verify deep linking functionality
- Test tab state management
- Handle navigation edge cases

## Test Execution

### Running Tests
Use the established test commands:
```bash
# Run all unit tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run specific test plan
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -testPlan MovingBoxSnapshotTests -destination 'platform=iOS Simulator,name=iPhone 14 Pro'
```

### Test Configuration
- Use appropriate launch arguments for test scenarios
- Configure mock data and test environments
- Disable animations and external services
- Set up proper test isolation

Remember:
- Write tests BEFORE implementing functionality when possible
- Focus on behavior verification, not implementation details
- Ensure tests are fast, reliable, and maintainable
- Keep test code clean and well-organized
- Use tests as living documentation of expected behavior