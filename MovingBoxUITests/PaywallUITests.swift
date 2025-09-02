import XCTest

@MainActor
final class PaywallUITests: XCTestCase {
    var app: XCUIApplication!
    var listScreen: InventoryListScreen!
    var dashboardScreen: DashboardScreen!
    var detailScreen: InventoryDetailScreen!
    var cameraScreen: CameraScreen!
    var paywallScreen: PaywallScreen!
    var navigationHelper: NavigationHelper!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        app.launchArguments = [
            "reset-paywall-state",
            "Skip-Onboarding",
            "Disable-Persistence",
            "UI-Testing-Mock-Camera"
        ]

        // Initialize screen objects
        listScreen = InventoryListScreen(app: app)
        dashboardScreen = DashboardScreen(app: app)
        detailScreen = InventoryDetailScreen(app: app)
        cameraScreen = CameraScreen(app: app, testCase: self)
        paywallScreen = PaywallScreen(app: app)
        navigationHelper = NavigationHelper(app: app)
        
        setupSnapshot(app)
    }
        
    override func tearDownWithError() throws {
        // No need for cleanup here since we'll reset on next launch
        app = nil
        listScreen = nil
        dashboardScreen = nil
        detailScreen = nil
        cameraScreen = nil
        paywallScreen = nil
        navigationHelper = nil
    }
    
    // MARK: - Free Tier Tests

    func testAiLimitShowsAlertFromTabBar() throws {
        // Given: User has reached free tier limit
        app.launchArguments.append("Use-Test-Data")
        app.launch()
        sleep(5)
        
        // When: User attempts to add item via dashboard camera button
        dashboardScreen.tapAddItemFromCamera()
        
        // Then: Paywall should appear
        XCTAssertTrue(paywallScreen.waitForPaywall(),
                     "Paywall should appear after tapping upgrade in alert")
    }
    
    func testAiLimitShowsAlertFromListView() throws {
        // Given: User has reached item limit
        app.launchArguments.append("Use-Test-Data")
        app.launch()
        sleep(5)
        
        // When: User attempts to add item via list view camera option
        navigationHelper.navigateToAllItems()
        listScreen.tapAddItem()
        listScreen.tapCreateFromCamera()
        
        // Then: Paywall should appear
        XCTAssertTrue(paywallScreen.waitForPaywall(),
                     "Paywall should appear after tapping upgrade in alert")
        
        // When: User dismisses paywall
        paywallScreen.dismiss()
        
        // And: Tries again
        listScreen.tapAddItem()
        listScreen.tapCreateFromCamera()
        
        // Then: Alert should appear again (since user is still on free tier)
        XCTAssertTrue(listScreen.waitForLimitAlert(),
                     "Limit alert should appear again after dismissing paywall")
        
        // When: User cancels
        listScreen.tapCancelInAlert()
        
        // Then: Should return to list view
        XCTAssertTrue(listScreen.createFromCameraButton.exists,
                     "Should return to list view after canceling alert")
    }
    
    func testSettingsViewPaywallButton() throws {
        // Given a user is in the Settings view
        app.launch()
        navigationHelper.navigateToSettings()
        // When the user taps "Get MovingBox Pro"
        
        // Then the paywall should be displayed
    }
    
    // MARK: - Pro Tier Tests
    
    func testProUserBypassesPaywallForManualItemCreationOverLimit() throws {
        // Given: Pro user with items over limit
        app.launchArguments.append("Is-Pro")
        app.launchArguments.append("Use-Test-Data")
        app.launch()
        sleep(5)
        
        // When: User attempts actions that would normally show paywall
        navigationHelper.navigateToAllItems()
        listScreen.tapAddItem()
        listScreen.tapCreateManually()
        
        // Then: Should be able to create new item
        XCTAssertTrue(detailScreen.titleField.exists,
                     "Pro user should be able to create items over limit")
        
    }
    
    func testProUserBypassesPaywallForListViewCamera() throws {
        // Given: Pro user with items over limit
        app.launchArguments.append("Is-Pro")
        app.launchArguments.append("Use-Test-Data")
        app.launch()
        sleep(5)
        
        // When: User attempts actions that would normally show paywall
        navigationHelper.navigateToAllItems()
        listScreen.tapAddItem()
        listScreen.tapCreateFromCamera()
        
        // Then: Camera should be ready
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera should be ready after permissions")
        
    }
    
    func testProUserBypassesPaywallForTabViewCamera() throws {
        // Given: Pro user with items over limit
        app.launchArguments.append("Is-Pro")
        app.launchArguments.append("Use-Test-Data")
        app.launch()
        sleep(5)
        
        // When: User attempts to call the camera view from the dashboard
        dashboardScreen.tapAddItemFromCamera()
        
        // Then: Camera should be ready
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera should be ready after permissions")
        
    }
}
