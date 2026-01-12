# MovingBoxTests

Unit tests using Swift Testing framework.

## Test Commands
```bash
# Run all unit tests
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'id=31D4A8DF-E68A-4884-BAAA-DFDF61090577' -derivedDataPath ./DerivedData 2>&1 | xcsift

# Run snapshot tests only
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -testPlan MovingBoxSnapshotTests -destination 'id=31D4A8DF-E68A-4884-BAAA-DFDF61090577' -derivedDataPath ./DerivedData 2>&1 | xcsift
```

## Test Structure (Swift Testing)

```swift
@MainActor
struct ServiceNameTests {

    @Test("Descriptive test name")
    func testSpecificBehavior() async throws {
        // Arrange
        let container = try createTestContainer()
        let context = ModelContext(container)

        // Act
        let result = await service.performAction()

        // Assert
        #expect(result.isSuccess)
        #expect(result.value == expected)
    }
}
```

## In-Memory SwiftData Container

```swift
func createTestContainer() throws -> ModelContainer {
    let schema = Schema([
        InventoryItem.self, InventoryLocation.self,
        InventoryLabel.self, Home.self, InsurancePolicy.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}
```

## Test Categories

| Category | Location | Purpose |
|----------|----------|---------|
| Unit | `*Tests.swift` | Single component isolation |
| Integration | `*IntegrationTests.swift` | Multi-component flows |
| Snapshot | `SnapshotTests.swift` | Visual regression |

## Snapshot Tests

- Location: `SnapshotTests.swift`
- Reference images: `__Snapshots__/`
- Device: iPhone 14 Pro (for consistency)
- Variants: Light mode, Dark mode

```swift
assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone14Pro)))
```

## Mock Patterns

```swift
// Use protocol-based mocking
class MockOpenAIService: OpenAIServiceProtocol {
    var shouldFail = false
    var mockResponse: ImageDetails?

    func getImageDetails(...) async throws -> ImageDetails {
        if shouldFail { throw OpenAIError.invalidData }
        return mockResponse ?? ImageDetails.empty()
    }
}
```

## Key Test Files

| File | Tests |
|------|-------|
| `CurrencyFormatterTests.swift` | Currency formatting |
| `SettingsManagerTests.swift` | User preferences |
| `DataManagerTests.swift` | CSV/ZIP export |
| `OpenAIServiceTests.swift` | AI analysis |
| `SnapshotTests.swift` | View rendering |
