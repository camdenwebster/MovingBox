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
            "Skip-Onboarding",
            "Disable-Persistence",
            "UI-Testing-Mock-Camera",
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

    func testAiLimitShowsAlertFromDashboard() throws {
        // TODO: Fix after multi-home architecture merge - paywall not appearing on item limit
        throw XCTSkip("Paywall logic broken after multi-home merge - needs investigation")

        // Given: User has reached free tier limit
        app.launchArguments.append("Use-Test-Data")
        app.launch()

        // And the user is on the Dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed())

        // When: User attempts to add item via dashboard camera button
        dashboardScreen.tapAddItemFromCamera()

        // Then: Paywall should appear
        XCTAssertTrue(
            paywallScreen.waitForPaywall(),
            "Paywall should appear after tapping upgrade in alert")
    }

    func testAiLimitShowsAlertFromListView() throws {
        // Given: User has reached item limit
        app.launchArguments.append("Use-Test-Data")
        app.launch()

        // And the user is on the Dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed())

        // When: User attempts to add item via list view camera option
        navigationHelper.navigateToAllItems()
        listScreen.tapAddItem()

        // Then: Paywall should appear
        XCTAssertTrue(
            paywallScreen.waitForPaywall(),
            "Paywall should appear after tapping upgrade in alert")

        // When: User dismisses paywall
        paywallScreen.dismiss()

        // Then: Should return to list view
        XCTAssertTrue(
            listScreen.createFromCameraButton.exists,
            "Should return to list view after canceling alert")
    }

    func testSettingsViewPaywallButton() throws {
        // Given a user is in the Settings view
        app.launch()
        dashboardScreen.waitForDashboard()
        navigationHelper.navigateToSettings()
        // When the user taps "Get MovingBox Pro"

        // Then the paywall should be displayed
    }

    // MARK: - Pro Tier Tests

    func testProUserBypassesPaywallForManualItemCreationOverLimit() throws {
        // TODO: Fix after multi-home architecture merge - dashboard elements not loading
        throw XCTSkip("Dashboard loading broken after multi-home merge - needs investigation")

        // Given: Pro user with items over limit
        app.launchArguments.append("Is-Pro")
        app.launchArguments.append("Use-Test-Data")
        app.launch()
        sleep(5)

        // When: User attempts actions that would normally show paywall
        navigationHelper.navigateToAllItems()
        listScreen.openToolbarMenu()
        listScreen.tapCreateManually()

        // Then: Should be able to create new item
        XCTAssertTrue(
            detailScreen.titleField.exists,
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

        // Then: Camera should be ready
        XCTAssertTrue(
            cameraScreen.waitForCamera(),
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
        XCTAssertTrue(
            cameraScreen.waitForCamera(),
            "Camera should be ready after permissions")

    }
}
