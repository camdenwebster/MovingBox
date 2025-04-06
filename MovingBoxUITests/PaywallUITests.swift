import XCTest

final class PaywallUITests: XCTestCase {
    var app: XCUIApplication!
    var listScreen: InventoryListScreen!
    var detailScreen: InventoryDetailScreen!
    var cameraScreen: CameraScreen!
    var photoReviewScreen: PhotoReviewScreen!
    var paywallScreen: PaywallScreen!
    var tabBar: TabBar!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Add launch argument to reset UserDefaults in the main app
        app.launchArguments = ["reset-paywall-state"]
        app.launchArguments = ["Skip-Onboarding"]

        // Initialize screen objects
        listScreen = InventoryListScreen(app: app)
        detailScreen = InventoryDetailScreen(app: app)
        cameraScreen = CameraScreen(app: app, testCase: self)
        photoReviewScreen = PhotoReviewScreen(app: app)
        paywallScreen = PaywallScreen(app: app)
        tabBar = TabBar(app: app)
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        // No need for cleanup here since we'll reset on next launch
        app = nil
        listScreen = nil
        detailScreen = nil
        cameraScreen = nil
        photoReviewScreen = nil
        paywallScreen = nil
        tabBar = nil
    }
    
    // MARK: - Free Tier Tests
    
    func testFirstItemCreationShowsPaywall() throws {
        // Given: Fresh install (no items)
        
        app.launch()
        
        // When: User attempts to create first item
        tabBar.tapAllItems()
        listScreen.tapAddItem()
        listScreen.tapCreateManually()
        
        // Then: Paywall should appear
        XCTAssertTrue(paywallScreen.waitForPaywall(),
                     "Paywall should appear for first item creation")
        
        // When: User dismisses paywall
        paywallScreen.dismiss()
        
        // Then: Paywall should not appear for subsequent items
        listScreen.tapAddItem()
        listScreen.tapCreateManually()
        XCTAssertFalse(paywallScreen.paywallView.exists,
                      "Paywall should not appear after being dismissed")
    }
    
    func testItemLimitShowsAlert() throws {
        // Given: User has reached item limit
        app.launchArguments = ["UI-Testing"]
        app.launch()
        
        // When: User attempts to add another item
        tabBar.tapAllItems()
        listScreen.tapAddItem()
        listScreen.tapCreateManually()
        
        // Then: Limit alert should appear
        XCTAssertTrue(app.alerts["Upgrade to Pro"].waitForExistence(timeout: 5),
                     "Limit alert should appear")
        
        // When: User taps upgrade in alert
        app.alerts["Upgrade to Pro"].buttons["Upgrade"].tap()
        
        // Then: Paywall should appear
        XCTAssertTrue(paywallScreen.waitForPaywall(),
                     "Paywall should appear after tapping upgrade in alert")
    }
    
    func testLocationLimitShowsAlert() throws {
        // Given: User has reached location limit
        app.launchArguments = ["UI-Testing"]
        app.launch()
        
        // When: User attempts to add another location
        tabBar.tapLocations()
        app.buttons["addLocation"].tap()
        
        // Then: Limit alert should appear
        XCTAssertTrue(app.alerts["Upgrade to Pro"].waitForExistence(timeout: 5),
                     "Location limit alert should appear")
        
        // When: User taps upgrade in alert
        app.alerts["Upgrade to Pro"].buttons["Upgrade"].tap()
        
        // Then: Paywall should appear
        XCTAssertTrue(paywallScreen.waitForPaywall(),
                     "Paywall should appear after tapping upgrade in alert")
    }
    
    func testItemLimitShowsAlertFromTabBarCamera() throws {
        // Given: User has reached free tier limit
        app.launchArguments = ["UI-Testing"]
        app.launch()
        
        // When: User attempts to add item via tab bar camera
        tabBar.tapAddItem()
        
        // Then: Limit alert should appear
        XCTAssertTrue(app.alerts["Upgrade to Pro"].waitForExistence(timeout: 5),
                     "Limit alert should appear when using camera from tab bar")
        
        // When: User taps upgrade in alert
        app.alerts["Upgrade to Pro"].buttons["Upgrade"].tap()
        
        // Then: Paywall should appear
        XCTAssertTrue(paywallScreen.waitForPaywall(),
                     "Paywall should appear after tapping upgrade in alert")
    }
    
    func testItemLimitShowsAlertFromListViewCamera() throws {
        // Given: User has reached item limit
        app.launchArguments = ["UI-Testing"]
        app.launch()
        
        // When: User attempts to add item via list view camera option
        tabBar.tapAllItems()
        listScreen.tapAddItem()
        listScreen.tapCreateFromCamera()
        
        // Then: Limit alert should appear
        XCTAssertTrue(listScreen.waitForLimitAlert(),
                     "Limit alert should appear when using camera from list view")
        
        // When: User taps upgrade in alert
        listScreen.tapUpgradeInAlert()
        
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
        XCTAssertTrue(listScreen.addItemButton.exists,
                     "Should return to list view after canceling alert")
    }
    
    // MARK: - Pro Tier Tests
    
    func testProUserBypassesPaywallForManualItemCreationOfFirstItem() throws {
        // Given: Pro user with no items
        app.launchArguments = ["UI-Testing-Pro"]
        app.launch()
        
        // When: User attempts to create their first item
        tabBar.tapAllItems()
        listScreen.tapAddItem()
        listScreen.tapCreateManually()
        
        // Then: Should be able to create new item
        XCTAssertTrue(detailScreen.titleField.exists,
                     "Pro user should be able to create items over limit")
        
    }
    
    func testProUserBypassesPaywallForManualItemCreationOverLimit() throws {
        // Given: Pro user with items over limit
        app.launchArguments = ["UI-Testing", "UI-Testing-Pro"]
        app.launch()
        
        // When: User attempts actions that would normally show paywall
        tabBar.tapAllItems()
        listScreen.tapAddItem()
        listScreen.tapCreateManually()
        
        // Then: Should be able to create new item
        XCTAssertTrue(detailScreen.titleField.exists,
                     "Pro user should be able to create items over limit")
        
    }
    
    func testProUserBypassesPaywallForListViewCamera() throws {
        // Given: Pro user with items over limit
        app.launchArguments = ["UI-Testing", "UI-Testing-Pro"]
        app.launch()
        
        // When: User attempts actions that would normally show paywall
        tabBar.tapAllItems()
        listScreen.tapAddItem()
        listScreen.tapCreateFromCamera()
        
        // Then: Camera should be ready
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera should be ready after permissions")
        
    }
    
    func testProUserBypassesPaywallForTabViewCamera() throws {
        // Given: Pro user with items over limit
        app.launchArguments = ["UI-Testing", "UI-Testing-Pro"]
        app.launch()
        
        // When: User attempts to call the camera view from the tab bar
        tabBar.tapAddItem()
        
        // Then: Camera should be ready
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera should be ready after permissions")
        
    }
}
