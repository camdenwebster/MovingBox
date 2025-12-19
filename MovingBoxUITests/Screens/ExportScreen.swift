import XCTest

class ExportScreen {
    let app: XCUIApplication
    
    let itemsToggle: XCUIElement
    let locationsToggle: XCUIElement
    let labelsToggle: XCUIElement
    let exportButton: XCUIElement
    let cancelButton: XCUIElement
    let progressPhaseText: XCUIElement
    let progressValue: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        self.itemsToggle = app.otherElements.matching(NSPredicate(format: "identifier == 'export-items-toggle'")).firstMatch
        self.locationsToggle = app.otherElements.matching(NSPredicate(format: "identifier == 'export-locations-toggle'")).firstMatch
        self.labelsToggle = app.otherElements.matching(NSPredicate(format: "identifier == 'export-labels-toggle'")).firstMatch
        self.exportButton = app.buttons["export-data-button"]
        self.cancelButton = app.buttons["export-cancel-button"]
        self.progressPhaseText = app.staticTexts["export-progress-phase-text"]
        self.progressValue = app.otherElements.matching(NSPredicate(format: "identifier == 'export-progress-value'")).firstMatch
    }
    
    func isDisplayed() -> Bool {
        return exportButton.waitForExistence(timeout: 5) &&
               app.navigationBars.staticTexts["Export Data"].exists
    }
    
    func tapExportButton() {
        exportButton.tap()
    }
    
    func tapCancelButton() {
        cancelButton.tap()
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
    
    func waitForExportProgress() -> Bool {
        return progressPhaseText.waitForExistence(timeout: 30)
    }
    
    func waitForProgressCompletion() -> Bool {
        let shareSheetButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Save'")).firstMatch
        return shareSheetButton.waitForExistence(timeout: 30)
    }
    
    func getProgressPhase() -> String {
        return progressPhaseText.label
    }
    
    func isExportButtonEnabled() -> Bool {
        return exportButton.isEnabled
    }
    
    func isExportButtonDisabled() -> Bool {
        return !exportButton.isEnabled
    }
}
