import XCTest

class ImportScreen {
    let app: XCUIApplication
    
    let itemsToggle: XCUIElement
    let locationsToggle: XCUIElement
    let labelsToggle: XCUIElement
    let selectFileButton: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        self.itemsToggle = app.switches["import-items-toggle"]
        self.locationsToggle = app.switches["import-locations-toggle"]
        self.labelsToggle = app.switches["import-labels-toggle"]
        self.selectFileButton = app.cells.containing(.button, identifier: "import-select-file-button").firstMatch
    }
    
    func isDisplayed() -> Bool {
        return selectFileButton.waitForExistence(timeout: 5) &&
               app.navigationBars.staticTexts["Import Data"].exists
    }
    
    func tapSelectFileButton() {
        selectFileButton.tap()
    }
    
    func toggleItems(_ enabled: Bool) {
        itemsToggle.tap()
    }
    
    func toggleLocations(_ enabled: Bool) {
        locationsToggle.tap()
    }
    
    func toggleLabels(_ enabled: Bool) {
        labelsToggle.tap()
    }
    
    func enableAllOptions() {
        toggleItems(true)
        toggleLocations(true)
        toggleLabels(true)
    }
    
    func disableAllOptions() {
        toggleItems(false)
        toggleLocations(false)
        toggleLabels(false)
    }
    
    func selectOnlyItems() {
        disableAllOptions()
        toggleItems(true)
    }
    
    func selectOnlyLocations() {
        disableAllOptions()
        toggleLocations(true)
    }
    
    func selectOnlyLabels() {
        disableAllOptions()
        toggleLabels(true)
    }
    
    func isSelectFileButtonEnabled() -> Bool {
        return selectFileButton.isEnabled
    }
    
    func isSelectFileButtonDisabled() -> Bool {
        return !selectFileButton.isEnabled
    }
    
    func waitForDuplicateWarning() -> Bool {
        let alert = app.alerts.matching(NSPredicate(format: "label CONTAINS 'Warning'")).firstMatch
        return alert.waitForExistence(timeout: 5)
    }
    
    func acceptDuplicateWarning() {
        let continueButton = app.alerts.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
        }
    }
    
    func dismissDuplicateWarning() {
        let cancelButton = app.alerts.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 5) {
            cancelButton.tap()
        }
    }
}
