import XCTest

class ImportScreen {
    let app: XCUIApplication
    
    let itemsToggle: XCUIElement
    let locationsToggle: XCUIElement
    let labelsToggle: XCUIElement
    let selectFileButton: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        // Use descendants to find the actual switch element within the toggle container
        self.itemsToggle = app.switches.matching(NSPredicate(format: "identifier == 'import-items-toggle'")).firstMatch
        self.locationsToggle = app.switches.matching(NSPredicate(format: "identifier == 'import-locations-toggle'")).firstMatch
        self.labelsToggle = app.switches.matching(NSPredicate(format: "identifier == 'import-labels-toggle'")).firstMatch
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
        let currentValue = itemsToggle.value as? String
        let isCurrentlyOn = currentValue == "1"
        if isCurrentlyOn != enabled {
            itemsToggle.tap()
        }
    }
    
    func toggleLocations(_ enabled: Bool) {
        let currentValue = locationsToggle.value as? String
        let isCurrentlyOn = currentValue == "1"
        if isCurrentlyOn != enabled {
            locationsToggle.tap()
        }
    }
    
    func toggleLabels(_ enabled: Bool) {
        let currentValue = labelsToggle.value as? String
        let isCurrentlyOn = currentValue == "1"
        if isCurrentlyOn != enabled {
            labelsToggle.tap()
        }
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
