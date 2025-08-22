//
//  DataDeletionScreen.swift
//  MovingBox
//
//  Created by Claude on 8/21/25.
//

import XCTest

class DataDeletionScreen {
    let app: XCUIApplication
    
    // Warning section elements
    let warningLabel: XCUIElement
    let warningDescription: XCUIElement
    let inventoryItemsWarning: XCUIElement
    let locationsWarning: XCUIElement
    let labelsWarning: XCUIElement
    let homeInfoWarning: XCUIElement
    
    // Scope selection elements
    let deletionScopeHeader: XCUIElement
    let localOnlyOption: XCUIElement
    let localAndICloudOption: XCUIElement
    let localOnlyDescription: XCUIElement
    let localAndICloudDescription: XCUIElement
    
    // Confirmation section elements
    let confirmationInstructions: XCUIElement
    let confirmationTextField: XCUIElement
    let deleteButton: XCUIElement
    let irreversibleWarning: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        
        // Warning section
        self.warningLabel = app.staticTexts["Warning"]
        self.warningDescription = app.staticTexts["This will permanently delete all your inventory data including:"]
        self.inventoryItemsWarning = app.staticTexts["All inventory items and photos"]
        self.locationsWarning = app.staticTexts["All locations and room data"]
        self.labelsWarning = app.staticTexts["All labels and categories"]
        self.homeInfoWarning = app.staticTexts["Home information and settings"]
        
        // Scope selection
        self.deletionScopeHeader = app.staticTexts["Deletion Scope"]
        self.localOnlyOption = app.staticTexts["Local Only"]
        self.localAndICloudOption = app.staticTexts["Local and iCloud"]
        self.localOnlyDescription = app.staticTexts["Delete data only from this device. Your data will remain in iCloud and on other devices."]
        self.localAndICloudDescription = app.staticTexts["Delete all data from this device and iCloud. This will remove data from all your devices."]
        
        // Confirmation section
        self.confirmationInstructions = app.staticTexts["To confirm deletion, type \"DELETE\" below:"]
        self.confirmationTextField = app.textFields["Type DELETE"]
        self.deleteButton = app.buttons["Delete All Data"]
        self.irreversibleWarning = app.staticTexts["This action is irreversible. Make sure you have exported your data if you want to keep a backup."]
    }
    
    // MARK: - Actions
    
    func selectLocalOnlyScope() {
        localOnlyOption.tap()
    }
    
    func selectLocalAndICloudScope() {
        localAndICloudOption.tap()
    }
    
    func enterConfirmationText(_ text: String) {
        confirmationTextField.tap()
        confirmationTextField.clearAndEnterText(text)
    }
    
    func tapDeleteButton() {
        deleteButton.tap()
    }
    
    func performDeletion(confirmationText: String = "DELETE") {
        enterConfirmationText(confirmationText)
        tapDeleteButton()
    }
    
    // MARK: - Alert Handling
    
    func handleFinalConfirmationAlert(confirm: Bool = true) {
        let alert = app.alerts["Final Confirmation"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Final confirmation alert should appear")
        
        if confirm {
            alert.buttons["Delete All Data"].tap()
        } else {
            alert.buttons["Cancel"].tap()
        }
    }
    
    func getFinalConfirmationAlert() -> XCUIElement {
        return app.alerts["Final Confirmation"]
    }
    
    // MARK: - Verification Methods
    
    func isDisplayed() -> Bool {
        return app.navigationBars["Delete All Data"].waitForExistence(timeout: 5) &&
               warningLabel.exists
    }
    
    func waitForScreen() -> Bool {
        return isDisplayed()
    }
    
    func isWarningSectionVisible() -> Bool {
        return warningLabel.exists &&
               warningDescription.exists &&
               inventoryItemsWarning.exists &&
               locationsWarning.exists &&
               labelsWarning.exists &&
               homeInfoWarning.exists
    }
    
    func isScopeSectionVisible() -> Bool {
        return deletionScopeHeader.exists &&
               localOnlyOption.exists &&
               localAndICloudOption.exists &&
               localOnlyDescription.exists &&
               localAndICloudDescription.exists
    }
    
    func isConfirmationSectionVisible() -> Bool {
        return confirmationInstructions.exists &&
               confirmationTextField.exists &&
               deleteButton.exists &&
               irreversibleWarning.exists
    }
    
    func isDeleteButtonEnabled() -> Bool {
        return deleteButton.isHittable
    }
    
    func getConfirmationText() -> String {
        return confirmationTextField.value as? String ?? ""
    }
    
    func isFinalConfirmationAlertVisible() -> Bool {
        let alert = app.alerts["Final Confirmation"]
        return alert.exists
    }
    
    func getFinalConfirmationMessage() -> String {
        let alert = app.alerts["Final Confirmation"]
        return alert.staticTexts["This action cannot be undone. Are you sure you want to delete all your inventory data?"].label
    }
    
    func areFinalConfirmationButtonsVisible() -> Bool {
        let alert = app.alerts["Final Confirmation"]
        return alert.buttons["Cancel"].exists && alert.buttons["Delete All Data"].exists
    }
}

// MARK: - XCUIElement Extension

extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        // Clear existing text
        let currentValue = self.value as? String ?? ""
        if !currentValue.isEmpty {
            // Select all text
            self.press(forDuration: 1.0)
            let app = XCUIApplication()
            if app.menuItems["Select All"].exists {
                app.menuItems["Select All"].tap()
            }
        }
        
        // Type new text
        self.typeText(text)
    }
}