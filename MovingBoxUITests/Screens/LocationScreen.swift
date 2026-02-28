//
//  LocationScreen.swift
//  MovingBoxUITests
//
//  Created by Claude on 1/29/26.
//

import XCTest

class LocationScreen {
    let app: XCUIApplication

    // Locations List Elements
    let addLocationButton: XCUIElement
    let editButton: XCUIElement
    let noLocationCard: XCUIElement

    // Delete Alert Elements
    let deleteAlert: XCUIElement
    let deleteAlertConfirm: XCUIElement
    let deleteAlertCancel: XCUIElement

    // Edit Location Elements
    let nameField: XCUIElement
    let saveButton: XCUIElement
    let iconRow: XCUIElement

    init(app: XCUIApplication) {
        self.app = app

        // Locations List
        self.addLocationButton = app.buttons["addLocation"]
        self.editButton = app.buttons["locations-edit-button"]
        self.noLocationCard = app.buttons["locations-no-location-card"]

        // Delete Alert
        self.deleteAlert = app.alerts["Delete Location?"]
        self.deleteAlertConfirm = app.alerts["Delete Location?"].buttons["Delete"]
        self.deleteAlertCancel = app.alerts["Delete Location?"].buttons["Cancel"]

        // Edit Location
        self.nameField = app.textFields["location-name-field"]
        self.saveButton = app.buttons["location-save-button"]
        self.iconRow = app.buttons["location-icon-row"]
    }

    // MARK: - Navigation Actions

    func tapAddLocation() {
        addLocationButton.tap()
    }

    func enterLocationName(_ name: String) {
        nameField.tap()
        nameField.typeText(name)
    }

    func tapSave() {
        saveButton.tap()
    }

    func tapIconRow() {
        iconRow.tap()
    }

    func selectSymbol(named symbolName: String) {
        let symbolButton = app.buttons["symbol-picker-\(symbolName)"]
        symbolButton.tap()
    }

    func selectNoIcon() {
        let noIconButton = app.buttons["symbol-picker-none"]
        noIconButton.tap()
    }

    /// Create a new location with optional symbol
    func createLocation(name: String, symbol: String? = nil) {
        tapAddLocation()
        XCTAssertTrue(waitForEditLocationScreen(), "Edit location screen should appear")
        enterLocationName(name)
        if let symbol = symbol {
            tapIconRow()
            XCTAssertTrue(waitForSymbolPicker(), "Symbol picker should appear")
            selectSymbol(named: symbol)
        }
        tapSave()
    }

    // MARK: - Edit Mode Actions

    func tapEdit() {
        editButton.tap()
    }

    func tapDone() {
        editButton.tap()
    }

    func tapLocationToDelete(named name: String) {
        let deleteButton = app.buttons["location-delete-\(name)"]
        deleteButton.firstMatch.tap()
    }

    func confirmDelete() {
        if deleteAlertConfirm.exists {
            deleteAlertConfirm.tap()
            return
        }

        let sheetDelete = app.sheets.buttons["Delete"].firstMatch
        if sheetDelete.waitForExistence(timeout: 3) {
            sheetDelete.tap()
            return
        }

        XCTFail("Delete confirmation button was not found")
    }

    func cancelDelete() {
        if deleteAlertCancel.exists {
            deleteAlertCancel.tap()
            return
        }

        let sheetCancel = app.sheets.buttons["Cancel"].firstMatch
        if sheetCancel.waitForExistence(timeout: 3) {
            sheetCancel.tap()
            return
        }

        XCTFail("Delete cancel button was not found")
    }

    func tapNoLocationCard() {
        noLocationCard.tap()
    }

    // MARK: - Delete Verification

    func waitForDeleteAlert(timeout: TimeInterval = 8) -> Bool {
        if deleteAlert.waitForExistence(timeout: timeout) {
            return true
        }
        return app.sheets.buttons["Delete"].firstMatch.waitForExistence(timeout: 2)
    }

    func noLocationCardExists() -> Bool {
        return noLocationCard.exists
    }

    func waitForNoLocationCard(timeout: TimeInterval = 5) -> Bool {
        return noLocationCard.waitForExistence(timeout: timeout)
    }

    // MARK: - Verification

    func isLocationsListDisplayed() -> Bool {
        return app.navigationBars["Locations"].waitForExistence(timeout: 5)
    }

    func waitForLocationsList() -> Bool {
        return isLocationsListDisplayed()
    }

    func isEditLocationDisplayed() -> Bool {
        return app.navigationBars["New Location"].waitForExistence(timeout: 5)
    }

    func waitForEditLocationScreen() -> Bool {
        return isEditLocationDisplayed()
    }

    func waitForSymbolPicker() -> Bool {
        return app.navigationBars["Choose Icon"].waitForExistence(timeout: 5)
    }

    func locationExists(named name: String) -> Bool {
        return app.staticTexts[name].exists
    }

    func waitForLocationToExist(named name: String, timeout: TimeInterval = 5) -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if app.staticTexts[name].exists {
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }
}
