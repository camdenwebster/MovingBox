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
    let homeListTitle: XCUIElement
    let addHomeButton: XCUIElement
    
    // Add Home Screen Elements
    let homeNameTextField: XCUIElement
    let saveButton: XCUIElement
    let cancelButton: XCUIElement
    
    // Home Detail Screen Elements
    let editButton: XCUIElement
    let deleteButton: XCUIElement
    let primaryHomeToggle: XCUIElement
    let colorPicker: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        
        // Home List Screen
        self.homeListTitle = app.navigationBars["Homes"]
        self.addHomeButton = app.buttons["Add Home"]
        
        // Add Home Screen
        self.homeNameTextField = app.textFields["Home Name"]
        self.saveButton = app.buttons["Save"]
        self.cancelButton = app.buttons["Cancel"]
        
        // Home Detail Screen
        self.editButton = app.buttons["Edit"]
        self.deleteButton = app.buttons["Delete Home"]
        self.primaryHomeToggle = app.switches["Set as Primary"]
        self.colorPicker = app.otherElements["Color"]
    }
    
    // MARK: - Navigation Actions
    
    func navigateToHomeList(from settingsScreen: SettingsScreen) {
        // Navigate from Settings to Home List
        // Implementation depends on settings structure
    }
    
    func tapAddHome() {
        addHomeButton.tap()
    }
    
    func selectHome(named name: String) {
        app.buttons[name].tap()
    }
    
    // MARK: - Add Home Actions
    
    func enterHomeName(_ name: String) {
        homeNameTextField.tap()
        homeNameTextField.typeText(name)
    }
    
    func tapSave() {
        saveButton.tap()
    }
    
    func tapCancel() {
        cancelButton.tap()
    }
    
    func createHome(named name: String) {
        tapAddHome()
        XCTAssertTrue(waitForAddHomeScreen(), "Add home screen should be displayed")
        enterHomeName(name)
        tapSave()
    }
    
    // MARK: - Edit Home Actions
    
    func tapEdit() {
        editButton.tap()
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
    
    func selectColor(_ colorName: String) {
        // Tap the color picker circle for the specified color
        // Implementation will depend on actual UI structure
    }
    
    // MARK: - Verification Methods
    
    func isHomeListDisplayed() -> Bool {
        return homeListTitle.exists || addHomeButton.waitForExistence(timeout: 5)
    }
    
    func waitForHomeList() -> Bool {
        return isHomeListDisplayed()
    }
    
    func isAddHomeScreenDisplayed() -> Bool {
        return homeNameTextField.waitForExistence(timeout: 5) && saveButton.exists
    }
    
    func waitForAddHomeScreen() -> Bool {
        return isAddHomeScreenDisplayed()
    }
    
    func isHomeDetailDisplayed() -> Bool {
        return editButton.exists || deleteButton.exists
    }
    
    func homeExists(named name: String) -> Bool {
        return app.buttons[name].exists || app.staticTexts[name].exists
    }
    
    func isSaveButtonEnabled() -> Bool {
        return saveButton.isEnabled
    }
    
    func getHomeCount() -> Int {
        // Count the number of home cells in the list
        // This will need to be adjusted based on actual cell structure
        let homeCells = app.cells.matching(identifier: "home-cell")
        return homeCells.count
    }
    
    func isPrimaryHome(named name: String) -> Bool {
        // Check if home has primary badge/indicator
        let homeCell = app.buttons[name]
        return homeCell.staticTexts["PRIMARY"].exists
    }
}
