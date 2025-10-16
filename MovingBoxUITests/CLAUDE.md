# MovingBoxUITests Directory - UI Testing Best Practices

This directory contains UI tests for the MovingBox iOS app using XCTest framework with the Page Object Model pattern.

## Page Object Model Architecture

### Current Screen Objects
- **CameraScreen**: Camera functionality and photo capture
- **DashboardScreen**: Main dashboard interactions and data validation
- **ImportExportScreen**: Data import/export functionality
- **InventoryDetailScreen**: Item detail view interactions
- **InventoryListScreen**: Inventory list management
- **PaywallScreen**: Subscription and paywall interactions
- **SettingsScreen**: App settings management
- **TabBar**: Navigation between main app sections

### Screen Object Design Pattern

#### Basic Structure
```swift
import XCTest

class ScreenName {
    let app: XCUIApplication
    
    // UI Elements
    let primaryButton: XCUIElement
    let textField: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        self.primaryButton = app.buttons["accessibility-identifier"]
        self.textField = app.textFields["text-field-identifier"]
    }
    
    // Actions
    func performAction() {
        primaryButton.tap()
    }
    
    // Validations
    func isDisplayed() -> Bool {
        return primaryButton.waitForExistence(timeout: 5)
    }
}
```

## UI Testing Best Practices

### Test Structure and Organization

#### Test Class Setup
```swift
final class FeatureUITests: XCTestCase {
    let app = XCUIApplication()
    var screenObject: ScreenObject!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "UI-Testing-Mock-Camera",
            "Disable-Animations",
            "Use-Test-Data"
        ]
        screenObject = ScreenObject(app: app)
        app.launch()
        
        // IMPORTANT: Make sure user is on dashboard (splash screen has disappeared)
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
    }
}
```

#### Test Method Structure
Follow the Arrange-Act-Assert pattern:
```swift
func testFeatureFunctionality() throws {
    // Arrange: Set up initial state
    XCTAssertTrue(screen.isDisplayed())
    
    // Act: Perform user actions
    screen.performAction()
    
    // Assert: Verify expected outcomes
    XCTAssertTrue(screen.expectedElement.exists)
}
```

### Launch Arguments for Testing

#### Essential Launch Arguments
- `"UI-Testing-Mock-Camera"`: Mock camera functionality for consistent testing
- `"Disable-Animations"`: Speed up tests by disabling UI animations
- `"Use-Test-Data"`: Load predefined test data for consistent scenarios
- `"Skip-Onboarding"`: Bypass onboarding for most tests
- `"Show-Onboarding"`: Explicitly test onboarding flow
- `"Disable-Persistence"`: Use in-memory storage for test isolation
- `"Is-Pro"`: Test pro features and subscription functionality

#### Test-Specific Configuration
```swift
// For onboarding tests
app.launchArguments = [
    "Show-Onboarding",
    "Disable-Persistence", 
    "UI-Testing-Mock-Camera",
    "Disable-Animations"
]

// For feature tests with data
app.launchArguments = [
    "Skip-Onboarding",
    "Use-Test-Data",
    "Disable-Animations"
]
```

### Element Identification Strategies

#### Accessibility Identifiers (Preferred)
Use consistent, descriptive accessibility identifiers:
```swift
// In SwiftUI View
Button("Save") {
    // action
}
.accessibilityIdentifier("inventory-item-save-button")

// In UI Test
let saveButton = app.buttons["inventory-item-save-button"]
```

#### Naming Conventions for Accessibility Identifiers
- **Format**: `{feature}-{component}-{action/type}`
- **Examples**:
  - `"inventory-item-save-button"`
  - `"onboarding-welcome-continue-button"`
  - `"dashboard-stats-card-label"`
  - `"settings-export-button"`

#### Fallback Strategies
When accessibility identifiers aren't available:
```swift
// By button text (less reliable)
let button = app.buttons["Button Text"]

// By static text
let label = app.staticTexts["Label Text"]

// By position (avoid when possible)
let firstButton = app.buttons.firstMatch
```

### Screen Object Implementation Guidelines

#### Element Declaration
```swift
class InventoryDetailScreen {
    let app: XCUIApplication
    
    // Primary elements
    let saveButton: XCUIElement
    let nameTextField: XCUIElement
    let photoButton: XCUIElement
    
    // Navigation elements
    let backButton: XCUIElement
    let editButton: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        self.saveButton = app.buttons["inventory-item-save-button"]
        self.nameTextField = app.textFields["inventory-item-name-field"]
        self.photoButton = app.buttons["inventory-item-photo-button"]
        self.backButton = app.navigationBars.buttons["Back"]
        self.editButton = app.buttons["inventory-item-edit-button"]
    }
}
```

#### Action Methods
```swift
// Single action methods
func tapSaveButton() {
    saveButton.tap()
}

func enterItemName(_ name: String) {
    nameTextField.tap()
    nameTextField.typeText(name)
}

// Complex action methods
func saveItemWithName(_ name: String) {
    enterItemName(name)
    tapSaveButton()
}

// Navigation methods
func navigateBack() {
    backButton.tap()
}
```

#### Validation Methods
```swift
// Existence checks
func isDisplayed() -> Bool {
    return saveButton.waitForExistence(timeout: 5)
}

func isEditMode() -> Bool {
    return editButton.exists && editButton.isEnabled
}

// Content validation
func getItemName() -> String {
    return nameTextField.value as? String ?? ""
}

// State validation
func isSaveButtonEnabled() -> Bool {
    return saveButton.isEnabled
}
```

### Waiting and Timing Strategies

#### Smart Waiting
```swift
// Wait for element existence
func waitForSaveButton() -> Bool {
    return saveButton.waitForExistence(timeout: 10)
}

// Wait for element to disappear
func waitForLoadingToComplete() -> Bool {
    let loadingIndicator = app.activityIndicators["loading"]
    return !loadingIndicator.waitForExistence(timeout: 1)
}

// Wait for specific state
func waitForDataLoad() -> Bool {
    var iterations = 0
    while statCardValue.label.isEmpty && iterations < 10 {
        sleep(1)
        iterations += 1
    }
    return !statCardValue.label.isEmpty
}
```

#### Timeout Guidelines
- **Fast interactions**: 2-3 seconds
- **Standard UI updates**: 5 seconds  
- **Network/AI operations**: 10-30 seconds
- **App launch**: 10 seconds
- **Complex operations**: Up to 60 seconds

### Camera and Photo Testing

#### Camera Mock Setup
```swift
class CameraScreen {
    let app: XCUIApplication
    let testCase: XCTestCase
    
    let shutterButton: XCUIElement
    let doneButton: XCUIElement
    
    init(app: XCUIApplication, testCase: XCTestCase) {
        self.app = app
        self.testCase = testCase
        self.shutterButton = app.buttons["PhotoCapture"]
        self.doneButton = app.buttons["Done"]
    }
    
    func waitForCamera() -> Bool {
        return shutterButton.waitForExistence(timeout: 10)
    }
    
    func takePhoto() {
        shutterButton.tap()
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()
    }
}
```

#### Permission Handling
```swift
extension XCTestCase {
    func addCameraPermissionsHandler() {
        addUIInterruptionMonitor(withDescription: "Camera Authorization Alert") { alert in
            let allowButton = alert.buttons["OK"]
            if allowButton.exists {
                allowButton.tap()
                return true
            }
            return false
        }
    }
    
    func addNotificationsPermissionsHandler() {
        addUIInterruptionMonitor(withDescription: "Notifications Authorization Alert") { alert in
            let allowButton = alert.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
                return true
            }
            return false
        }
    }
}
```

### Device-Specific Testing

#### iPad vs iPhone Handling
```swift
class TabBar {
    let app: XCUIApplication
    let dashboardTab: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        
        // Device-specific element selection
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        if isIPad {
            self.dashboardTab = app.buttons["Dashboard"]
        } else {
            self.dashboardTab = app.tabBars.buttons["Dashboard"]
        }
    }
}
```

#### Orientation Testing
```swift
func testLandscapeLayout() throws {
    // Change to landscape
    XCUIDevice.shared.orientation = .landscapeLeft
    
    // Verify layout adapts
    XCTAssertTrue(screen.isDisplayedCorrectly())
    
    // Reset to portrait
    XCUIDevice.shared.orientation = .portrait
}
```

### Data-Driven Testing

#### Test Data Management
```swift
// Use consistent test data
let testItemName = "Test Coffee Maker"
let testLocationName = "Test Kitchen"
let testHomeData = TestHomeData.sampleHome

// Verify test data state
func verifyTestDataLoaded() -> Bool {
    let expectedItemCount = 53
    guard let actualCount = Int(statCardValue.label) else {
        return false
    }
    return actualCount >= expectedItemCount
}
```

#### Dynamic Content Handling
```swift
func handleDynamicContent() {
    // Wait for dynamic content to load
    let contentLoaded = app.staticTexts["content-loaded-indicator"]
    XCTAssertTrue(contentLoaded.waitForExistence(timeout: 15))
    
    // Verify content is not placeholder
    let itemName = app.staticTexts["item-name"]
    XCTAssertFalse(itemName.label.contains("Loading..."))
}
```

### Error Handling and Debugging

#### Test Failure Debugging
```swift
func debugTestFailure() {
    // Print current app state
    print("Current view hierarchy:")
    print(app.debugDescription)
    
    // Take screenshot for analysis
    let screenshot = app.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "failure_screenshot"
    add(attachment)
}
```

#### Robust Element Interaction
```swift
func tapElementSafely(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
    guard element.waitForExistence(timeout: timeout) else {
        XCTFail("Element does not exist: \(element)")
        return false
    }
    
    guard element.isHittable else {
        XCTFail("Element is not hittable: \(element)")
        return false
    }
    
    element.tap()
    return true
}
```

### Performance and Reliability

#### Test Reliability Guidelines
- Always use `waitForExistence` before interacting with elements
- Handle system alerts and permissions proactively
- Use appropriate timeouts for different operations
- Avoid hardcoded delays (`sleep`) - use proper waiting mechanisms
- Test on multiple device sizes and orientations

#### Performance Considerations
- Use `continueAfterFailure = false` to stop on first failure
- Disable animations for faster test execution
- Use mock data for consistent, fast test scenarios
- Minimize app launches and setup time

### Test Coverage Strategy

#### Critical User Flows
1. **Onboarding Flow**: Complete user setup process
2. **Item Creation**: Camera → AI Analysis → Save
3. **Navigation**: Tab switching and deep navigation
4. **Data Management**: Import/Export functionality
5. **Subscription Flow**: Paywall and pro features

#### Edge Cases to Test
- Empty states (no items, no locations)
- Network connectivity issues
- Permission denied scenarios
- Large datasets and performance
- Subscription state changes

### Integration with CI/CD

#### Fastlane Integration
```ruby
# In Fastfile
lane :ui_tests do
  run_tests(
    project: "MovingBox.xcodeproj",
    scheme: "MovingBoxUITests",
    destination: "platform=iOS Simulator,name=iPhone 16 Pro",
    output_directory: "./test_output"
  )
end
```

#### Test Result Analysis
- Capture screenshots on failures
- Generate detailed test reports
- Track test execution times
- Monitor test flakiness and reliability

Remember:
- **Page Objects should be pure**: No assertions in page objects, only actions and queries
- **Tests should be independent**: Each test should work in isolation
- **Use descriptive test names**: Test names should clearly describe what is being tested
- **Handle system interactions**: Mock or handle camera, notifications, and other system features
- **Test real user workflows**: Focus on end-to-end user scenarios rather than isolated UI components
