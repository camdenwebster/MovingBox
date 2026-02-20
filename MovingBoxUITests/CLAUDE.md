# MovingBoxUITests

UI tests using XCTest with Page Object Model pattern.

## Test Commands
```bash
# Smoke plan (fast PR/agent gate)
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' -derivedDataPath ./.build/DerivedData -testPlan SmokeTests 2>&1 | xcsift

# UI interaction plan
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' -derivedDataPath ./.build/DerivedData -testPlan MovingBoxUITests 2>&1 | xcsift

# Release E2E CRUD plan
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxUITests -destination 'id=4DA6503A-88E2-4019-B404-EBBB222F3038' -derivedDataPath ./.build/DerivedData -testPlan ReleaseTests 2>&1 | xcsift
```

## Plan Intent
- `SmokeTests`: Fast deterministic checks for PRs and agent validation.
- `MovingBoxUITests`: UI interaction/state coverage.
- `ReleaseTests`: Deterministic E2E app-functionality/CRUD coverage.
- Membership is managed via `selectedTests` allowlists.

## Launch Arguments

| Argument | Purpose |
|----------|---------|
| `Mock-AI` | Mock AI API calls |
| `Use-Test-Data` | Load 53+ test items |
| `Disable-Animations` | Faster, stable tests |
| `Skip-Onboarding` | Skip welcome flow |
| `Show-Onboarding` | Force welcome flow |
| `Is-Pro` | Enable pro features |
| `UI-Testing-Mock-Camera` | Mock camera |
| `Disable-Persistence` | In-memory storage |

## Standard Test Setup

```swift
final class FeatureUITests: XCTestCase {
    let app = XCUIApplication()
    var dashboard: DashboardScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "Mock-AI",
            "Use-Test-Data",
            "Disable-Animations",
            "Skip-Onboarding"
        ]
        dashboard = DashboardScreen(app: app)
        app.launch()
        XCTAssertTrue(dashboard.isDisplayed(), "Dashboard should be visible")
    }
}
```

## Screen Objects (Screens/)

| Screen | File | Purpose |
|--------|------|---------|
| `DashboardScreen` | `DashboardScreen.swift` | Main dashboard |
| `InventoryListScreen` | `InventoryListScreen.swift` | Item list |
| `InventoryDetailScreen` | `InventoryDetailScreen.swift` | Item detail |
| `CameraScreen` | `CameraScreen.swift` | Photo capture |
| `SettingsScreen` | `SettingsScreen.swift` | Settings |
| `PaywallScreen` | `PaywallScreen.swift` | Subscriptions |
| `ImportScreen` | `ImportScreen.swift` | Data import |
| `TabBar` | `TabBar.swift` | Tab navigation |

## Screen Object Pattern

```swift
class ScreenName {
    let app: XCUIApplication

    // Elements
    let saveButton: XCUIElement
    let nameField: XCUIElement

    init(app: XCUIApplication) {
        self.app = app
        self.saveButton = app.buttons["inventory-item-save-button"]
        self.nameField = app.textFields["inventory-item-name-field"]
    }

    // Actions (no assertions)
    func tapSave() { saveButton.tap() }
    func enterName(_ name: String) {
        nameField.tap()
        nameField.typeText(name)
    }

    // Queries
    func isDisplayed() -> Bool {
        saveButton.waitForExistence(timeout: 5)
    }
}
```

## Accessibility Identifier Convention

```
{feature}-{component}-{action/type}

Examples:
- inventory-item-save-button
- dashboard-stats-card-value
- settings-export-button
- onboarding-continue-button
```

## Timeout Guidelines

| Operation | Timeout |
|-----------|---------|
| Fast UI | 2-3s |
| Standard | 5s |
| Network/AI | 10-30s |
| App launch | 10s |

## Permission Handlers

```swift
func addCameraPermissionsHandler() {
    addUIInterruptionMonitor(withDescription: "Camera") { alert in
        alert.buttons["OK"].tap()
        return true
    }
}
```
