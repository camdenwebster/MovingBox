import XCTest

@MainActor
final class DashboardNavigationUITests: XCTestCase {
    var dashboardScreen: DashboardScreen!
    var listScreen: InventoryListScreen!
    var settingsScreen: SettingsScreen!
    var detailScreen: InventoryDetailScreen!
    var navigationHelper: NavigationHelper!
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "Skip-Onboarding",
            "Disable-Persistence",
            "Use-Test-Data",
            "Disable-Animations",
        ]

        // Initialize screen objects
        dashboardScreen = DashboardScreen(app: app)
        listScreen = InventoryListScreen(app: app)
        settingsScreen = SettingsScreen(app: app)
        detailScreen = InventoryDetailScreen(app: app)
        navigationHelper = NavigationHelper(app: app)

        setupSnapshot(app)
        app.launch()

        // Make sure user is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
    }

    override func tearDownWithError() throws {
        dashboardScreen = nil
        listScreen = nil
        settingsScreen = nil
        detailScreen = nil
        navigationHelper = nil
    }

    // MARK: - Dashboard Navigation Tests

    func testDashboardDisplaysCorrectly() throws {
        // Given: App launches to dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible on launch")

        // Then: Dashboard elements should be present
        XCTAssertTrue(dashboardScreen.statCardLabel.exists, "Stats card label should be visible")
        XCTAssertTrue(dashboardScreen.statCardValue.exists, "Stats card value should be visible")
        XCTAssertTrue(
            dashboardScreen.allInventoryButton.exists, "All Inventory button should be visible")
        XCTAssertTrue(dashboardScreen.settingsButton.exists, "Settings button should be visible")
        XCTAssertTrue(
            dashboardScreen.addItemFromCameraButton.exists, "Add item camera button should be visible")
    }

    func testNavigationFromDashboardToAllItems() throws {
        // Given: User is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should start on dashboard")

        // And: All Inventory button is available
        XCTAssertTrue(
            dashboardScreen.allInventoryButton.waitForExistence(timeout: 10),
            "All Inventory button should be visible")

        // When: User taps All Inventory button
        dashboardScreen.tapAllInventory()

        // Then: Should navigate to inventory list (check for various indicators)
        let onInventoryList =
            listScreen.createFromCameraButton.waitForExistence(timeout: 10)
            || app.staticTexts["All Items"].waitForExistence(timeout: 5)
            || app.staticTexts["No Items"].waitForExistence(timeout: 5)
            || app.buttons["Take a photo"].waitForExistence(timeout: 5)

        XCTAssertTrue(onInventoryList, "Inventory list should be displayed")

        // And: Should have navigated away from dashboard
        XCTAssertFalse(
            dashboardScreen.allInventoryButton.exists,
            "Dashboard should not be visible after navigation")
    }

    func testNavigationFromDashboardToSettings() throws {
        // Given: User is on dashboard

        // When: User taps Settings button
        dashboardScreen.tapSettings()

        // Then: Settings view should be displayed
        // TODO: Add proper settings screen validation once SettingsScreen is updated
        XCTAssertFalse(
            dashboardScreen.allInventoryButton.exists,
            "Dashboard should not be visible")
    }

    func testBackNavigationFromListViewToDashboard() throws {
        // Given: User navigates to All Items
        navigationHelper.navigateToAllItems()
        XCTAssertTrue(listScreen.createFromCameraButton.exists, "Should be on inventory list")

        // When: User taps back button
        app.navigationBars.buttons.firstMatch.tap()

        // Then: Should return to dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to dashboard")
        XCTAssertTrue(dashboardScreen.allInventoryButton.exists, "Dashboard buttons should be visible")
    }

    func testBackNavigationFromSettingsToDashboard() throws {
        // Given: User navigates to Settings
        navigationHelper.navigateToSettings()

        // When: User taps back button
        app.navigationBars.buttons.firstMatch.tap()

        // Then: Should return to dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to dashboard")
        XCTAssertTrue(dashboardScreen.allInventoryButton.exists, "Dashboard buttons should be visible")
    }

    // MARK: - Dashboard Data Display Tests

    func testDashboardStatsDisplayCorrectly() throws {
        // Given: Dashboard is loaded

        // And: Stats cards are present
        XCTAssertTrue(
            dashboardScreen.statCardValue.firstMatch.waitForExistence(timeout: 10),
            "Stats card should be visible")

        // Then: Stats should show values (may be 0 if no test data)
        let statValue = dashboardScreen.statCardValue.firstMatch.label
        XCTAssertFalse(statValue.isEmpty, "Stats value should not be empty")

        // And: Stats should be numeric
        XCTAssertNotNil(Int(statValue), "Stats value should be a valid number: '\(statValue)'")
    }

    func testDashboardRecentItemsSection() throws {
        // Given: Dashboard is loaded with test data
        XCTAssertTrue(dashboardScreen.testDataLoaded(), "Test data should be loaded")

        // When: Recent items are present
        if dashboardScreen.hasRecentItems() {
            // Then: Recent items should be tappable
            XCTAssertTrue(
                dashboardScreen.waitForRecentItems(),
                "Recent items should be visible")

            // And: View All Items button should be present
            XCTAssertTrue(
                dashboardScreen.viewAllItemsButton.waitForExistence(timeout: 5),
                "View All Items button should be visible when items exist")
        } else {
            // Then: Empty state should be shown
            XCTAssertTrue(
                dashboardScreen.isEmptyState(),
                "Empty state should be shown when no items exist")
            XCTAssertTrue(
                dashboardScreen.emptyStateAddItemButton.exists,
                "Empty state add button should be visible")
        }
    }

    func testRecentItemNavigation() throws {
        // Given: Dashboard has recent items
        guard dashboardScreen.hasRecentItems() else {
            throw XCTSkip("No recent items available for testing")
        }

        // When: User taps first recent item
        dashboardScreen.tapFirstRecentItem()

        // Then: Should navigate to item detail
        XCTAssertTrue(
            detailScreen.titleField.waitForExistence(timeout: 5),
            "Should navigate to item detail view")
    }

    func testViewAllItemsButtonNavigation() throws {
        // Given: Dashboard has items and View All button is visible
        guard dashboardScreen.hasRecentItems() && dashboardScreen.viewAllItemsButton.exists else {
            throw XCTSkip("View All Items button not available")
        }

        // When: User taps View All Items button
        dashboardScreen.tapViewAllItems()

        // Then: Should navigate to inventory list
        XCTAssertTrue(
            listScreen.toolbarMenu.waitForExistence(timeout: 5),
            "Should navigate to inventory list")
    }

    // MARK: - Dashboard Toolbar Tests

    func testDashboardToolbarButtons() throws {
        // Given: Dashboard is displayed
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")

        // Then: Toolbar buttons should be present
        XCTAssertTrue(
            dashboardScreen.settingsButton.exists,
            "Settings button should be in toolbar")
        XCTAssertTrue(
            dashboardScreen.addItemFromCameraButton.exists,
            "Add item button should be in toolbar")
    }

    // TODO: Test iOS 26+ search toolbar functionality when available
    func testDashboardSearchToolbar() throws {
        // This test should be implemented when iOS 26+ search features are testable
        // Test search field in toolbar (iOS 26+)
        // Test search functionality integration
        throw XCTSkip("Search toolbar testing not implemented - requires iOS 26+ features")
    }

    // MARK: - Dashboard Performance Tests

    func testDashboardLoadsQuickly() throws {
        // Given: App is launching
        let startTime = Date()

        // When: Dashboard appears
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should load")

        // Then: Should load within reasonable time
        let loadTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(loadTime, 2.0, "Dashboard should load within 2 seconds")
    }

    func testDashboardStatsLoadQuickly() throws {
        // Given: Dashboard is visible
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")

        // When: Waiting for stats to load
        let startTime = Date()
        XCTAssertTrue(
            dashboardScreen.statCardValue.waitForExistence(timeout: 10),
            "Stats should load")

        // Then: Stats should load within reasonable time
        let loadTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(loadTime, 3.0, "Stats should load within 3 seconds")
    }

    // MARK: - Dashboard State Tests

    func testDashboardEmptyState() throws {
        // TODO: Implement test for empty state when no inventory items exist
        // This would require a launch argument to start with empty data
        throw XCTSkip("Empty state testing not implemented - requires empty data launch argument")
    }

    func testDashboardWithLargeDataset() throws {
        // TODO: Implement test for dashboard performance with large datasets
        // This would test scrolling performance and data loading efficiency
        throw XCTSkip("Large dataset testing not implemented - requires large test data")
    }

    // MARK: - Dashboard Accessibility Tests

    func testDashboardAccessibilityIdentifiers() throws {
        // Given: Dashboard is displayed
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")

        // Then: All critical elements should have accessibility identifiers
        XCTAssertTrue(
            dashboardScreen.allInventoryButton.exists,
            "All Inventory button should have accessibility identifier")
        XCTAssertTrue(
            dashboardScreen.settingsButton.exists,
            "Settings button should have accessibility identifier")
        XCTAssertTrue(
            dashboardScreen.addItemFromCameraButton.exists,
            "Add item button should have accessibility identifier")

        // And: Stats cards should have identifiers
        XCTAssertTrue(
            dashboardScreen.statCardLabel.exists,
            "Stats card label should have accessibility identifier")
        XCTAssertTrue(
            dashboardScreen.statCardValue.exists,
            "Stats card value should have accessibility identifier")
    }

    // MARK: - Dashboard Integration Tests

    func testDashboardToItemCreationFlow() throws {
        // TODO: Test complete flow from dashboard -> add item -> save -> return to dashboard
        // This should verify the entire user journey and data persistence
        throw XCTSkip("Complete item creation flow testing not implemented")
    }

    func testDashboardDataRefreshAfterItemCreation() throws {
        // TODO: Test that dashboard stats update after creating new items
        // This should verify real-time data updates and UI refresh
        throw XCTSkip("Dashboard data refresh testing not implemented")
    }
}
