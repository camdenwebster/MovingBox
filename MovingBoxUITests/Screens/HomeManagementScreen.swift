//
//  HomeManagementScreen.swift
//  MovingBoxUITests
//
//  Created by Claude Code on 12/21/25.
//

import XCTest

class HomeManagementScreen {
    let app: XCUIApplication

    // Home List Screen Elements
    let homeListNavigationBar: XCUIElement
    let addHomeButton: XCUIElement

    // Add Home Screen Elements
    let homeNameTextField: XCUIElement
    let streetAddressTextField: XCUIElement
    let saveButton: XCUIElement
    let cancelButton: XCUIElement
    let addHomeNavigationBar: XCUIElement

    // Home Detail Screen Elements
    let editButton: XCUIElement
    let doneButton: XCUIElement
    let deleteButton: XCUIElement
    let primaryHomeToggle: XCUIElement

    init(app: XCUIApplication) {
        self.app = app

        // Home List Screen - navigation bar title is "Homes"
        self.homeListNavigationBar = app.navigationBars["Homes"]
        self.addHomeButton = app.buttons["Add Home"]

        // Add Home Screen - navigation bar title is "Add Home"
        self.addHomeNavigationBar = app.navigationBars["Add Home"]
        self.homeNameTextField = app.textFields["Home Name (Optional)"]
        self.streetAddressTextField = app.textFields["Street Address"]
        self.saveButton = app.buttons["Save"]
        self.cancelButton = app.buttons["Cancel"]

        // Home Detail Screen
        self.editButton = app.buttons["Edit"]
        self.doneButton = app.buttons["Done"]
        self.deleteButton = app.buttons["Delete Home"]
        self.primaryHomeToggle = app.switches["Set as Primary"]
    }

    // MARK: - Navigation Actions

    func tapAddHome() {
        addHomeButton.tap()
    }

    func selectHome(named name: String) {
        // Homes are displayed as buttons with the home name
        app.buttons[name].tap()
    }

    // MARK: - Add Home Actions

    func enterHomeName(_ name: String) {
        homeNameTextField.tap()
        homeNameTextField.typeText(name)
    }

    func enterStreetAddress(_ address: String) {
        streetAddressTextField.tap()
        streetAddressTextField.typeText(address)
    }

    func clearAndEnterHomeName(_ name: String) {
        homeNameTextField.tap()
        // Select all and delete
        homeNameTextField.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
            app.keys["delete"].tap()
        }
        homeNameTextField.typeText(name)
    }

    func tapSave() {
        saveButton.tap()
    }

    func tapCancel() {
        cancelButton.tap()
    }

    func createHome(name: String, address: String) {
        tapAddHome()
        XCTAssertTrue(waitForAddHomeScreen(), "Add home screen should be displayed")
        if !name.isEmpty {
            enterHomeName(name)
        }
        enterStreetAddress(address)
        tapSave()
    }

    // MARK: - Edit Home Actions

    func tapEdit() {
        editButton.tap()
    }

    func tapDone() {
        doneButton.tap()
    }

    func tapDelete() {
        deleteButton.tap()
    }

    func confirmDelete() {
        app.buttons["Delete"].tap()
    }

    func togglePrimaryHome() {
        primaryHomeToggle.tap()
    }

    // MARK: - Verification Methods

    func isHomeListDisplayed() -> Bool {
        return homeListNavigationBar.waitForExistence(timeout: 5)
    }

    func waitForHomeList() -> Bool {
        return isHomeListDisplayed()
    }

    func isAddHomeScreenDisplayed() -> Bool {
        return addHomeNavigationBar.waitForExistence(timeout: 5)
    }

    func waitForAddHomeScreen() -> Bool {
        return isAddHomeScreenDisplayed()
    }

    func isHomeDetailDisplayed(homeName: String) -> Bool {
        return app.navigationBars[homeName].waitForExistence(timeout: 5)
    }

    func homeExists(named name: String) -> Bool {
        // Look for the home name in the list - could be a button or static text
        return app.buttons[name].exists || app.staticTexts[name].exists
    }

    func waitForHomeToExist(named name: String, timeout: TimeInterval = 5) -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            // Check for exact match button
            if app.buttons[name].exists {
                return true
            }
            // Check for static text with exact name
            if app.staticTexts[name].exists {
                return true
            }
            // Check for button containing the name (NavigationLink may have combined label)
            let buttonsContaining = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", name)
            )
            if buttonsContaining.count > 0 {
                return true
            }
            // Check cells containing static text with the name
            if app.cells.containing(.staticText, identifier: name).firstMatch.exists {
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    func isSaveButtonEnabled() -> Bool {
        return saveButton.isEnabled
    }

    func getHomeCount() -> Int {
        // Count homes by looking at the cells in the list
        // Each home appears as a NavigationLink which renders as a button
        let homeCells = app.cells.count
        return homeCells
    }

    func isPrimaryHome(named name: String) -> Bool {
        // Check if home row contains PRIMARY badge
        // The PRIMARY text appears as a static text within the home's row
        let homeRow = app.buttons[name]
        return homeRow.staticTexts["PRIMARY"].exists
    }

    func getHomeNames() -> [String] {
        var names: [String] = []
        let cells = app.cells.allElementsBoundByIndex
        for cell in cells {
            // Get the first static text which should be the home name
            let labels = cell.staticTexts.allElementsBoundByIndex
            if let firstLabel = labels.first {
                names.append(firstLabel.label)
            }
        }
        return names
    }
}
