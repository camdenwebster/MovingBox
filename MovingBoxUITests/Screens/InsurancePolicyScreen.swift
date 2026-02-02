//
//  InsurancePolicyScreen.swift
//  MovingBoxUITests
//
//  Created by Claude on 1/18/26.
//

import XCTest

class InsurancePolicyScreen {
    let app: XCUIApplication

    // MARK: - List View Elements

    let insurancePoliciesList: XCUIElement
    let addPolicyButton: XCUIElement

    // MARK: - Detail View Elements

    let providerNameField: XCUIElement
    let policyNumberField: XCUIElement
    let saveButton: XCUIElement
    let cancelButton: XCUIElement
    let editButton: XCUIElement
    let deleteButton: XCUIElement
    let startDatePicker: XCUIElement
    let endDatePicker: XCUIElement

    // MARK: - Coverage Fields

    let deductibleField: XCUIElement
    let dwellingCoverageField: XCUIElement
    let personalPropertyField: XCUIElement
    let lossOfUseField: XCUIElement
    let liabilityField: XCUIElement
    let medicalPaymentsField: XCUIElement

    init(app: XCUIApplication) {
        self.app = app

        // List view
        self.insurancePoliciesList = app.collectionViews["insurance-policies-list"]
        self.addPolicyButton = app.buttons["insurance-add-button"]

        // Detail view - Policy Info
        self.providerNameField = app.textFields["policy-provider-field"]
        self.policyNumberField = app.textFields["policy-number-field"]
        self.saveButton = app.buttons["policy-save-button"]
        self.cancelButton = app.buttons["Cancel"]
        self.editButton = app.buttons["policy-edit-button"]
        self.deleteButton = app.buttons["policy-delete-button"]

        // Date pickers
        self.startDatePicker = app.datePickers["policy-start-date"]
        self.endDatePicker = app.datePickers["policy-end-date"]

        // Coverage fields
        self.deductibleField = app.textFields["policy-deductible"]
        self.dwellingCoverageField = app.textFields["policy-dwelling"]
        self.personalPropertyField = app.textFields["policy-personal-property"]
        self.lossOfUseField = app.textFields["policy-loss-of-use"]
        self.liabilityField = app.textFields["policy-liability"]
        self.medicalPaymentsField = app.textFields["policy-medical"]
    }

    // MARK: - Navigation Actions

    func tapAddPolicy() {
        addPolicyButton.tap()
    }

    func tapSave() {
        saveButton.tap()
    }

    func tapCancel() {
        cancelButton.tap()
    }

    func tapEdit() {
        editButton.tap()
    }

    func tapDelete() {
        deleteButton.tap()
    }

    // MARK: - Input Actions

    func enterProviderName(_ name: String) {
        providerNameField.tap()
        providerNameField.typeText(name)
    }

    func clearAndEnterProviderName(_ name: String) {
        providerNameField.tap()
        // Select all and delete
        providerNameField.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
        }
        providerNameField.typeText(name)
    }

    func enterPolicyNumber(_ number: String) {
        policyNumberField.tap()
        policyNumberField.typeText(number)
    }

    // MARK: - Home Assignment Actions

    func toggleHomeAssignment(homeId: String) {
        let homeToggle = app.buttons["policy-home-toggle-\(homeId)"]
        if homeToggle.waitForExistence(timeout: 3) {
            homeToggle.tap()
        }
    }

    func toggleHomeAssignment(named homeName: String) {
        // Find the button containing the home name
        let homeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", homeName)).firstMatch
        if homeButton.waitForExistence(timeout: 3) {
            homeButton.tap()
        }
    }

    // MARK: - Verification

    func waitForPoliciesList(timeout: TimeInterval = 5) -> Bool {
        // Check for either the list or the empty state
        let listExists = insurancePoliciesList.waitForExistence(timeout: timeout)
        let emptyStateExists = app.staticTexts["No Insurance Policies"].waitForExistence(timeout: 1)
        let navBarExists = app.navigationBars["Insurance Policies"].waitForExistence(timeout: timeout)
        return listExists || emptyStateExists || navBarExists
    }

    func waitForDetailScreen(timeout: TimeInterval = 5) -> Bool {
        return providerNameField.waitForExistence(timeout: timeout)
            || app.navigationBars["New Policy"].waitForExistence(timeout: timeout)
    }

    func isDisplayed() -> Bool {
        return waitForPoliciesList()
    }

    func isSaveButtonEnabled() -> Bool {
        return saveButton.isEnabled
    }

    func getPolicyCount() -> Int {
        // Count cells in the list
        return app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'policy-row-'")).count
    }

    func policyExists(named providerName: String) -> Bool {
        return app.staticTexts[providerName].exists
    }

    func waitForPolicyToExist(named providerName: String, timeout: TimeInterval = 5) -> Bool {
        return app.staticTexts[providerName].waitForExistence(timeout: timeout)
    }

    func waitForPolicyToDisappear(named providerName: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.staticTexts[providerName])
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    func selectPolicy(named providerName: String) {
        app.staticTexts[providerName].tap()
    }

    func swipeToDeletePolicy(named providerName: String) {
        let cell = app.cells.containing(.staticText, identifier: providerName).firstMatch
        cell.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
    }

    func confirmDelete() {
        if app.buttons["Delete"].waitForExistence(timeout: 3) {
            app.buttons["Delete"].tap()
        }
    }

    func isHomeAssigned(named homeName: String) -> Bool {
        // Look for checkmark next to the home name in edit mode
        let homeRow = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", homeName)).firstMatch
        if homeRow.exists {
            // Check if there's a checkmark image in the row
            return homeRow.images["checkmark"].exists
        }
        return false
    }

    func getAssignedHomesCount() -> Int {
        // In view mode, count displayed homes in the "Assigned Homes" section
        // This is approximate - may need adjustment based on actual UI structure
        return app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'policy-home-toggle-'")).count
    }
}
