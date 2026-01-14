import XCTest

@MainActor
final class NavigationSystemUITests: XCTestCase {
    var navigationHelper: NavigationHelper!
    var dashboardScreen: DashboardScreen!
    var listScreen: InventoryListScreen!
    var settingsScreen: SettingsScreen!
    var detailScreen: InventoryDetailScreen!
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
        navigationHelper = NavigationHelper(app: app)
        dashboardScreen = DashboardScreen(app: app)
        listScreen = InventoryListScreen(app: app)
        settingsScreen = SettingsScreen(app: app)
        detailScreen = InventoryDetailScreen(app: app)

        setupSnapshot(app)
        app.launch()
    }

    override func tearDownWithError() throws {
        navigationHelper = nil
        dashboardScreen = nil
        listScreen = nil
        settingsScreen = nil
        detailScreen = nil
    }

    // MARK: - Navigation Helper Tests

    func testNavigationHelperAllItemsFromDashboard() throws {
        // Given: User is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should start on dashboard")

        // And: Dashboard elements are loaded
        XCTAssertTrue(
            dashboardScreen.allInventoryButton.waitForExistence(timeout: 10),
            "All Inventory button should be visible")

        // When: Using navigation helper to go to All Items
        navigationHelper.navigateToAllItems()

        // Then: Should be on inventory list (check multiple indicators)
        let onInventoryList =
            listScreen.createFromCameraButton.waitForExistence(timeout: 10)
            || app.staticTexts["All Items"].waitForExistence(timeout: 5)
            || app.staticTexts["No Items"].waitForExistence(timeout: 5)

        XCTAssertTrue(onInventoryList, "Should navigate to inventory list")

        // And: Should not be on dashboard anymore
        XCTAssertFalse(
            dashboardScreen.allInventoryButton.exists,
            "Should have navigated away from dashboard")
    }

    func testNavigationHelperAllItemsFromSettings() throws {
        // Given: User is on settings
        navigationHelper.navigateToSettings()
        XCTAssertFalse(dashboardScreen.allInventoryButton.exists, "Should be away from dashboard")

        // When: Using navigation helper to go to All Items
        navigationHelper.navigateToAllItems()

        // Then: Should be on inventory list
        XCTAssertTrue(
            listScreen.createFromCameraButton.waitForExistence(timeout: 5),
            "Should navigate to inventory list from settings")
    }

    func testNavigationHelperSettingsFromDashboard() throws {
        // Given: User is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should start on dashboard")

        // When: Using navigation helper to go to Settings
        navigationHelper.navigateToSettings()

        // Then: Should be on settings view
        // TODO: Add proper settings screen validation
        XCTAssertFalse(dashboardScreen.allInventoryButton.exists, "Should be away from dashboard")
    }

    func testNavigationHelperSettingsFromList() throws {
        // Given: User is on inventory list
        navigationHelper.navigateToAllItems()
        XCTAssertTrue(listScreen.createFromCameraButton.exists, "Should be on inventory list")

        // When: Using navigation helper to go to Settings
        navigationHelper.navigateToSettings()

        // Then: Should be on settings view
        XCTAssertFalse(listScreen.createFromCameraButton.exists, "Should be away from list")
        XCTAssertFalse(dashboardScreen.allInventoryButton.exists, "Should be away from dashboard")
    }

    // MARK: - Navigation Stack Tests

    func testNavigationStackDepth() throws {
        // Given: Starting from dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should start on dashboard")

        // When: Navigating through multiple levels
        navigationHelper.navigateToAllItems()
        XCTAssertTrue(listScreen.createFromCameraButton.exists, "Should be on list")

        // And: Going deeper into detail view (if items exist)
        if dashboardScreen.hasRecentItems() {
            // Navigate back to dashboard first
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(dashboardScreen.isDisplayed(), "Should be back on dashboard")

            // Then navigate to recent item detail
            dashboardScreen.tapFirstRecentItem()
            XCTAssertTrue(
                detailScreen.titleField.waitForExistence(timeout: 5),
                "Should be on detail view")

            // Then: Should be able to navigate back through stack
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to dashboard")
        }
    }

    func testNavigationStackConsistency() throws {
        // Given: Multiple navigation operations
        navigationHelper.navigateToAllItems()
        navigationHelper.navigateToSettings()
        navigationHelper.navigateToAllItems()

        // When: Using back navigation
        app.navigationBars.buttons.firstMatch.tap()

        // Then: Should consistently return to dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to dashboard consistently")
    }

    // MARK: - Cross-Screen Navigation Tests

    func testDirectNavigationPaths() throws {
        // Test all direct navigation paths from dashboard
        let navigationTests = [
            (
                "All Items", { self.dashboardScreen.tapAllInventory() },
                { self.listScreen.createFromCameraButton.waitForExistence(timeout: 5) }
            ),
            (
                "Settings", { self.dashboardScreen.tapSettings() },
                { !self.dashboardScreen.allInventoryButton.exists }
            ),
        ]

        for (testName, navigationAction, validation) in navigationTests {
            // Given: Return to dashboard
            if !dashboardScreen.isDisplayed() {
                // Navigate back to dashboard
                repeat {
                    app.navigationBars.buttons.firstMatch.tap()
                    sleep(1)
                } while !dashboardScreen.isDisplayed() && app.navigationBars.buttons.firstMatch.exists
            }

            // When: Performing navigation
            navigationAction()

            // Then: Validation should pass
            XCTAssertTrue(validation(), "Navigation to \(testName) should work")
        }
    }

    // MARK: - Navigation Performance Tests

    func testNavigationSpeed() throws {
        let navigationOperations = [
            ("Dashboard to All Items", { self.navigationHelper.navigateToAllItems() }),
            ("All Items to Settings", { self.navigationHelper.navigateToSettings() }),
            ("Settings to All Items", { self.navigationHelper.navigateToAllItems() }),
            (
                "Back to Dashboard",
                {
                    self.app.navigationBars.buttons.firstMatch.tap()
                    _ = self.dashboardScreen.waitForDashboard()
                }
            ),
        ]

        for (operationName, operation) in navigationOperations {
            let startTime = Date()
            operation()
            let duration = Date().timeIntervalSince(startTime)

            XCTAssertLessThan(
                duration, 3.0,
                "\(operationName) should complete within 3 seconds, took \(duration)s")
        }
    }

    // MARK: - Navigation State Tests

    func testNavigationStatePreservation() throws {
        // TODO: Test that navigation state is preserved during app lifecycle events
        // This should test backgrounding/foregrounding and memory warnings
        throw XCTSkip("Navigation state preservation testing not implemented")
    }

    func testDeepLinkingNavigation() throws {
        // TODO: Test navigation via deep links and URL schemes
        // This should test external navigation triggers
        throw XCTSkip("Deep linking navigation testing not implemented")
    }

    // MARK: - Navigation Error Handling Tests

    func testNavigationWithMissingData() throws {
        // TODO: Test navigation behavior when expected data is missing
        // This should test graceful degradation and error states
        throw XCTSkip("Navigation error handling testing not implemented")
    }

    func testNavigationMemoryPressure() throws {
        // TODO: Test navigation under memory pressure conditions
        // This should verify proper cleanup and memory management
        throw XCTSkip("Navigation memory pressure testing not implemented")
    }

    // MARK: - Multi-Modal Navigation Tests

    func testSheetPresentationNavigation() throws {
        // TODO: Test navigation when sheets (modals) are presented
        // This should test item creation flows and settings modals
        throw XCTSkip("Sheet presentation navigation testing not implemented")
    }

    func testAlertPresentationNavigation() throws {
        // TODO: Test navigation when system alerts are presented
        // This should test permission dialogs and error alerts
        throw XCTSkip("Alert presentation navigation testing not implemented")
    }

    // MARK: - Accessibility Navigation Tests

    func testVoiceOverNavigation() throws {
        // TODO: Test navigation using VoiceOver accessibility features
        // This should verify proper accessibility labels and navigation hints
        throw XCTSkip("VoiceOver navigation testing not implemented")
    }

    func testKeyboardNavigation() throws {
        // TODO: Test navigation using external keyboard shortcuts (iPad)
        // This should test cmd+tab, arrow keys, and other shortcuts
        throw XCTSkip("Keyboard navigation testing not implemented")
    }

    // MARK: - Device-Specific Navigation Tests

    func testLandscapeNavigation() throws {
        // TODO: Test navigation in landscape orientation
        // This should verify layout adaptation and navigation preservation
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        // Test basic navigation still works in landscape
        navigationHelper.navigateToAllItems()
        XCTAssertTrue(
            listScreen.createFromCameraButton.waitForExistence(timeout: 5),
            "Navigation should work in landscape mode")
    }

    func testSplitViewNavigation() throws {
        // TODO: Test navigation in iPad split view mode
        // This should test sidebar navigation and dual pane interactions
        throw XCTSkip("Split view navigation testing not implemented - requires iPad testing")
    }

    // MARK: - Navigation Analytics Tests

    func testNavigationTracking() throws {
        // TODO: Test that navigation events are properly tracked for analytics
        // This should verify telemetry integration without exposing user data
        throw XCTSkip("Navigation analytics testing not implemented")
    }
}
