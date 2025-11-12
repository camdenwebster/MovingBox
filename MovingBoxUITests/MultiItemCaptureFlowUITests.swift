import XCTest

@MainActor
final class MultiItemCaptureFlowUITests: XCTestCase {
    var dashboardScreen: DashboardScreen!
    var addItemScreen: AddInventoryItemScreen!
    var navigationHelper: NavigationHelper!
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "Skip-Onboarding",
            "Disable-Persistence", 
            "UI-Testing-Mock-Camera",
            "Disable-Animations"
        ]
        
        // Initialize screen objects
        dashboardScreen = DashboardScreen(app: app)
        addItemScreen = AddInventoryItemScreen(app: app)
        navigationHelper = NavigationHelper(app: app)
        
        setupSnapshot(app)
        app.launch()
        
        // Make sure user is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
    }

    override func tearDownWithError() throws {
        dashboardScreen = nil
        addItemScreen = nil
        navigationHelper = nil
    }

    // MARK: - Capture Mode Selection Tests
    
    func testNavigationToCaptureModeSelection() throws {
        // Given: User is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
        
        // When: User taps the floating Add Item button
        XCTAssertTrue(dashboardScreen.addItemFromCameraButton.waitForExistence(timeout: 5), 
                     "Add Item button should be visible")
        dashboardScreen.addItemFromCameraButton.tap()
        
        // Then: Should navigate to capture mode selection screen
        XCTAssertTrue(addItemScreen.isDisplayed(), "Add Item screen should be displayed")
        XCTAssertTrue(addItemScreen.captureModeSelectionVisible(), 
                     "Capture mode selection should be visible")
    }
    
    func testEmptyStateAddItemButtonNavigation() throws {
        // Given: User is on dashboard with empty state
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
        
        // When: User taps the empty state Add Item button
        if dashboardScreen.emptyStateAddItemButton.exists {
            dashboardScreen.emptyStateAddItemButton.tap()
            
            // Then: Should navigate to capture mode selection screen
            XCTAssertTrue(addItemScreen.isDisplayed(), "Add Item screen should be displayed")
            XCTAssertTrue(addItemScreen.captureModeSelectionVisible(), 
                         "Capture mode selection should be visible")
        } else {
            throw XCTSkip("Empty state not available - test data might be loaded")
        }
    }
    
    func testCaptureModeSelectionOptions() throws {
        // Given: User navigates to capture mode selection
        navigationHelper.navigateToAddItem()
        XCTAssertTrue(addItemScreen.captureModeSelectionVisible(), 
                     "Capture mode selection should be visible")
        
        // Then: Both capture mode options should be available
        XCTAssertTrue(addItemScreen.singleItemModeButton.exists, 
                     "Single Item mode button should be visible")
        XCTAssertTrue(addItemScreen.multiItemModeButton.exists, 
                     "Multi Item mode button should be visible")
        
        // And: Mode descriptions should be displayed
        XCTAssertTrue(addItemScreen.singleItemDescription.exists,
                     "Single item description should be visible")
        XCTAssertTrue(addItemScreen.multiItemDescription.exists,
                     "Multi item description should be visible")
    }
    
    func testSingleItemModeSelection() throws {
        // Given: User is on capture mode selection screen
        navigationHelper.navigateToAddItem()
        XCTAssertTrue(addItemScreen.captureModeSelectionVisible(), 
                     "Capture mode selection should be visible")
        
        // When: User selects Single Item mode
        addItemScreen.selectSingleItemMode()
        
        // Then: Should navigate to enhanced item creation flow
        XCTAssertTrue(addItemScreen.enhancedItemCreationFlowVisible(),
                     "Enhanced item creation flow should be displayed")
    }
    
    func testMultiItemModeSelection() throws {
        // Given: User is on capture mode selection screen
        navigationHelper.navigateToAddItem()
        XCTAssertTrue(addItemScreen.captureModeSelectionVisible(), 
                     "Capture mode selection should be visible")
        
        // When: User selects Multi Item mode
        addItemScreen.selectMultiItemMode()
        
        // Then: Should navigate to enhanced item creation flow with multi-item mode
        XCTAssertTrue(addItemScreen.enhancedItemCreationFlowVisible(),
                     "Enhanced item creation flow should be displayed")
    }
    
    func testMultiItemModeProFeatureGating() throws {
        // Given: User is not a Pro subscriber (default test state)
        navigationHelper.navigateToAddItem()
        XCTAssertTrue(addItemScreen.captureModeSelectionVisible(), 
                     "Capture mode selection should be visible")
        
        // When: User selects Multi Item mode
        addItemScreen.selectMultiItemMode()
        
        // Then: Should show paywall for non-Pro users
        XCTAssertTrue(addItemScreen.paywallDisplayed(),
                     "Paywall should be displayed for multi-item mode")
        
        // And: Multi Item option should show Pro badge
        XCTAssertTrue(addItemScreen.multiItemProBadge.exists,
                     "Multi Item mode should display Pro badge")
    }
    
    // MARK: - Navigation and Back Button Tests
    
    func testBackNavigationFromCaptureModeSelection() throws {
        // Given: User navigates to capture mode selection
        navigationHelper.navigateToAddItem()
        XCTAssertTrue(addItemScreen.isDisplayed(), "Add Item screen should be displayed")
        
        // When: User taps back button
        app.navigationBars.buttons.element(boundBy: 0).tap()
        
        // Then: Should return to dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to dashboard")
    }
    
    func testNavigationTitleDisplay() throws {
        // Given: User navigates to capture mode selection
        navigationHelper.navigateToAddItem()
        XCTAssertTrue(addItemScreen.isDisplayed(), "Add Item screen should be displayed")
        
        // Then: Navigation title should be displayed correctly
        XCTAssertTrue(app.navigationBars["Add New Item"].exists,
                     "Navigation title should be 'Add New Item'")
    }
    
    // MARK: - Integration with Settings Tests
    
    func testPreferredCaptureModeDefault() throws {
        // Given: User navigates to capture mode selection
        navigationHelper.navigateToAddItem()
        XCTAssertTrue(addItemScreen.captureModeSelectionVisible(), 
                     "Capture mode selection should be visible")
        
        // Then: Default capture mode should be single item (for non-Pro users)
        XCTAssertTrue(addItemScreen.singleItemModeSelected(),
                     "Single item mode should be selected by default")
    }
    
    // MARK: - Error Handling Tests
    
    func testCameraPermissionDeniedHandling() throws {
        // Given: User selects a capture mode
        navigationHelper.navigateToAddItem()
        addItemScreen.selectSingleItemMode()
        
        // When: Camera permission is denied (simulated)
        // This would typically be handled by the mock camera system
        
        // Then: Should show permission alert
        if app.alerts.element.waitForExistence(timeout: 5) {
            XCTAssertTrue(app.alerts["Camera Access Required"].exists,
                         "Camera permission alert should be displayed")
            
            // And: Should provide settings navigation option
            XCTAssertTrue(app.alerts.buttons["Go to Settings"].exists,
                         "Settings button should be available")
            
            // Dismiss alert for cleanup
            app.alerts.buttons["Cancel"].tap()
        }
    }
    
    // MARK: - Performance Tests
    
    func testCaptureModeSelectionLoadTime() throws {
        // Given: User is on dashboard
        let startTime = Date()
        
        // When: User navigates to capture mode selection
        dashboardScreen.addItemFromCameraButton.tap()
        
        // Then: Screen should load quickly
        XCTAssertTrue(addItemScreen.captureModeSelectionVisible(),
                     "Capture mode selection should be visible")
        
        let loadTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(loadTime, 2.0, 
                         "Capture mode selection should load within 2 seconds")
    }
    
    // MARK: - Accessibility Tests
    
    func testCaptureModeSelectionAccessibility() throws {
        // Given: User navigates to capture mode selection
        navigationHelper.navigateToAddItem()
        XCTAssertTrue(addItemScreen.captureModeSelectionVisible(), 
                     "Capture mode selection should be visible")
        
        // Then: All elements should have proper accessibility identifiers
        XCTAssertTrue(addItemScreen.singleItemModeButton.exists,
                     "Single item button should have accessibility identifier")
        XCTAssertTrue(addItemScreen.multiItemModeButton.exists,
                     "Multi item button should have accessibility identifier")
        
        // And: Elements should have meaningful labels
        let singleItemLabel = addItemScreen.singleItemModeButton.label
        let multiItemLabel = addItemScreen.multiItemModeButton.label
        
        XCTAssertFalse(singleItemLabel.isEmpty, 
                      "Single item button should have accessibility label")
        XCTAssertFalse(multiItemLabel.isEmpty, 
                      "Multi item button should have accessibility label")
    }
}

// MARK: - AddInventoryItemScreen Page Object

class AddInventoryItemScreen {
    let app: XCUIApplication
    
    // Capture mode selection elements
    let singleItemModeButton: XCUIElement
    let multiItemModeButton: XCUIElement
    let singleItemDescription: XCUIElement
    let multiItemDescription: XCUIElement
    let multiItemProBadge: XCUIElement
    
    // Navigation elements
    let navigationTitle: XCUIElement
    let backButton: XCUIElement
    
    // Flow state elements
    let enhancedItemCreationFlow: XCUIElement
    let paywall: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        
        // Initialize elements based on accessibility identifiers from AddInventoryItemView
        self.singleItemModeButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Single Item'")
        ).firstMatch
        
        self.multiItemModeButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Multi Item'")
        ).firstMatch
        
        self.singleItemDescription = app.staticTexts["Take multiple photos of one item"]
        self.multiItemDescription = app.staticTexts["Take one photo with multiple items"]
        self.multiItemProBadge = app.staticTexts["PRO"]
        
        self.navigationTitle = app.navigationBars["Add New Item"]
        self.backButton = app.navigationBars.buttons.element(boundBy: 0)
        
        self.enhancedItemCreationFlow = app.otherElements.containing(
            NSPredicate(format: "identifier CONTAINS 'enhanced-item-creation'")
        ).firstMatch
        
        self.paywall = app.otherElements.containing(
            NSPredicate(format: "identifier CONTAINS 'paywall'")
        ).firstMatch
    }
    
    // MARK: - Validation Methods
    
    func isDisplayed() -> Bool {
        return navigationTitle.waitForExistence(timeout: 5) || 
               singleItemModeButton.waitForExistence(timeout: 5)
    }
    
    func captureModeSelectionVisible() -> Bool {
        return singleItemModeButton.exists && multiItemModeButton.exists
    }
    
    func singleItemModeSelected() -> Bool {
        // Check if single item button appears selected or highlighted
        return singleItemModeButton.isSelected || 
               singleItemModeButton.value as? String == "selected"
    }
    
    func enhancedItemCreationFlowVisible() -> Bool {
        return enhancedItemCreationFlow.waitForExistence(timeout: 5) ||
               app.buttons["PhotoCapture"].waitForExistence(timeout: 5)
    }
    
    func paywallDisplayed() -> Bool {
        return paywall.waitForExistence(timeout: 5) ||
               app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Upgrade'")).firstMatch.exists
    }
    
    // MARK: - Action Methods
    
    func selectSingleItemMode() {
        singleItemModeButton.tap()
    }
    
    func selectMultiItemMode() {
        multiItemModeButton.tap()
    }
}

// MARK: - NavigationHelper Extension

extension NavigationHelper {
    func navigateToAddItem() {
        let dashboardScreen = DashboardScreen(app: app)
        
        // Ensure we're on dashboard first
        if !dashboardScreen.isDisplayed() {
            // Navigate back to dashboard if needed
            while app.navigationBars.buttons.count > 0 {
                app.navigationBars.buttons.element(boundBy: 0).tap()
                if dashboardScreen.isDisplayed() { break }
            }
        }
        
        // Tap add item button
        XCTAssertTrue(dashboardScreen.addItemFromCameraButton.waitForExistence(timeout: 5))
        dashboardScreen.addItemFromCameraButton.tap()
    }
}