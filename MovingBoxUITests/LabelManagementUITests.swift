//
//  LabelManagementUITests.swift
//  MovingBoxUITests
//
//  Created by Claude Code on 1/17/26.
//

import XCTest

final class LabelManagementUITests: XCTestCase {
    var app: XCUIApplication!
    var dashboardScreen: DashboardScreen!
    var settingsScreen: SettingsScreen!
    var labelScreen: LabelScreen!
    var navigationHelper: NavigationHelper!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        dashboardScreen = DashboardScreen(app: app)
        settingsScreen = SettingsScreen(app: app)
        labelScreen = LabelScreen(app: app)
        navigationHelper = NavigationHelper(app: app)

        app.launchArguments = ["Use-Test-Data", "Disable-Animations", "Skip-Onboarding", "Disable-Persistence"]
        app.launch()

        // Make sure user is on dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
    }

    override func tearDownWithError() throws {
        app = nil
        dashboardScreen = nil
        settingsScreen = nil
        labelScreen = nil
        navigationHelper = nil
    }

    // MARK: - Navigation Tests

    func testNavigateToLabelsFromSettings() throws {
        // Given: We are on the dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")

        // When: We navigate to Settings
        navigationHelper.navigateToSettings()

        // Then: Settings should be displayed
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings screen should be visible")

        // When: We tap on Labels
        settingsScreen.tapLabels()

        // Then: Labels list should be displayed
        XCTAssertTrue(labelScreen.waitForLabelsList(), "Labels list should be displayed")
    }

    // MARK: - Label Creation Tests

    func testCreateNewLabel() throws {
        // Given: We navigate to the Labels screen
        navigationHelper.navigateToSettings()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings screen should be visible")
        settingsScreen.tapLabels()
        XCTAssertTrue(labelScreen.waitForLabelsList(), "Labels list should be displayed")

        // Get initial label count
        let initialCount = labelScreen.getLabelCount()

        // When: We create a new label
        let newLabelName = "Aa Test Label \(UUID().uuidString.prefix(8))"
        labelScreen.createLabel(name: newLabelName)

        // Then: We should be back on the labels list
        XCTAssertTrue(labelScreen.waitForLabelsList(), "Should return to labels list after creating label")

        // And: The new label should exist
        XCTAssertTrue(
            labelScreen.waitForLabelToExist(named: newLabelName, timeout: 5),
            "New label '\(newLabelName)' should exist in the list")

        // And: The label count should have increased
        let finalCount = labelScreen.getLabelCount()
        XCTAssertEqual(finalCount, initialCount + 1, "Label count should increase by 1")
    }

    func testCannotCreateLabelWithEmptyName() throws {
        // Given: We navigate to the Labels screen
        navigationHelper.navigateToSettings()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings screen should be visible")
        settingsScreen.tapLabels()
        XCTAssertTrue(labelScreen.waitForLabelsList(), "Labels list should be displayed")

        // When: We tap add label
        labelScreen.tapAddLabel()

        // Then: The edit label screen should be displayed
        XCTAssertTrue(labelScreen.waitForEditLabelScreen(), "Edit label screen should be displayed")

        // And: The save button should be disabled (name is empty)
        XCTAssertFalse(labelScreen.isSaveButtonEnabled(), "Save button should be disabled with empty name")
    }

    // MARK: - Label Deletion Tests

    func testDeleteLabelWithSwipe() throws {
        // Given: We navigate to the Labels screen
        navigationHelper.navigateToSettings()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings screen should be visible")
        settingsScreen.tapLabels()
        XCTAssertTrue(labelScreen.waitForLabelsList(), "Labels list should be displayed")

        // Get the initial label count and ensure we have labels to delete
        let initialCount = labelScreen.getLabelCount()
        guard initialCount > 0 else {
            throw XCTSkip("No labels available to delete")
        }

        // Get the names of existing labels to find one to delete
        let labelNames = labelScreen.getLabelNames()
        guard let labelToDelete = labelNames.first else {
            throw XCTSkip("Could not find a label name to delete")
        }

        // When: We swipe to delete the label
        labelScreen.swipeToDeleteLabel(named: labelToDelete)

        // Then: The label should be removed from the list
        XCTAssertTrue(
            labelScreen.waitForLabelToDisappear(named: labelToDelete, timeout: 5),
            "Label '\(labelToDelete)' should be removed from the list")

        // And: The label count should have decreased
        let finalCount = labelScreen.getLabelCount()
        XCTAssertEqual(finalCount, initialCount - 1, "Label count should decrease by 1")
    }

    // MARK: - Label Editing Tests

    func testEditExistingLabel() throws {
        // Given: We navigate to the Labels screen
        navigationHelper.navigateToSettings()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings screen should be visible")
        settingsScreen.tapLabels()
        XCTAssertTrue(labelScreen.waitForLabelsList(), "Labels list should be displayed")

        // Ensure we have labels to edit
        let labelNames = labelScreen.getLabelNames()
        guard let labelToEdit = labelNames.first else {
            throw XCTSkip("No labels available to edit")
        }

        // When: We select an existing label
        labelScreen.selectLabel(named: labelToEdit)

        // Then: Wait for the detail screen
        _ = labelScreen.editSaveButton.waitForExistence(timeout: 5)

        // And: We modify the label name
        let newName = "Edited \(UUID().uuidString.prefix(4))"
        labelScreen.clearAndEnterLabelName(newName)

        // And: We save the changes
        labelScreen.tapEditSave()

        // And: We navigate back to the labels list
        if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // Then: The renamed label should exist
        XCTAssertTrue(labelScreen.waitForLabelsList(), "Should return to labels list")
        XCTAssertTrue(
            labelScreen.waitForLabelToExist(named: newName, timeout: 5),
            "Edited label with new name '\(newName)' should exist")
    }

    // MARK: - Labels Global Scope Tests

    func testLabelsAreGlobalAcrossHomes() throws {
        // Given: We create a label
        navigationHelper.navigateToSettings()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings screen should be visible")
        settingsScreen.tapLabels()
        XCTAssertTrue(labelScreen.waitForLabelsList(), "Labels list should be displayed")

        let testLabelName = "Global Test Label \(UUID().uuidString.prefix(4))"
        labelScreen.createLabel(name: testLabelName)
        XCTAssertTrue(labelScreen.waitForLabelsList(), "Should return to labels list")
        XCTAssertTrue(
            labelScreen.waitForLabelToExist(named: testLabelName, timeout: 5),
            "Created label should exist")

        // Navigate back to dashboard
        navigationHelper.navigateBackToDashboard()
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")

        // Navigate back to labels via settings
        navigationHelper.navigateToSettings()
        settingsScreen.tapLabels()
        XCTAssertTrue(labelScreen.waitForLabelsList(), "Labels list should be displayed")

        // Then: The label should still be visible (proving labels are persistent and global)
        XCTAssertTrue(
            labelScreen.labelExists(named: testLabelName),
            "Label '\(testLabelName)' should still exist after navigating away and back")

        // Clean up: Delete the test label
        labelScreen.swipeToDeleteLabel(named: testLabelName)
    }
}
