import XCTest

class ExportScreen {
    let app: XCUIApplication

    let formatPicker: XCUIElement
    let photosToggle: XCUIElement
    let homeToggles: XCUIElementQuery
    let exportButton: XCUIElement
    let cancelButton: XCUIElement
    let progressPhaseText: XCUIElement
    let progressValue: XCUIElement

    init(app: XCUIApplication) {
        self.app = app
        self.formatPicker = app.otherElements["export-format-picker"]
        self.photosToggle =
            app.otherElements.matching(NSPredicate(format: "identifier == 'export-photos-toggle'"))
            .firstMatch
        self.homeToggles =
            app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'export-home-toggle-'"))
        self.exportButton = app.buttons["export-data-button"]
        self.cancelButton = app.buttons["export-cancel-button"]
        self.progressPhaseText = app.staticTexts["export-progress-phase-text"]
        self.progressValue =
            app.otherElements.matching(NSPredicate(format: "identifier == 'export-progress-value'"))
            .firstMatch
    }

    func isDisplayed() -> Bool {
        return exportButton.waitForExistence(timeout: 5)
            && app.navigationBars.staticTexts["Export Data"].exists
    }

    func tapExportButton() {
        exportButton.tap()
    }

    func tapCancelButton() {
        cancelButton.tap()
    }

    func disableAllCSVOptions() {
        let count = homeToggles.count
        for index in 0..<count {
            homeToggles.element(boundBy: index).tap()
        }
        if photosToggle.exists {
            photosToggle.tap()
        }
    }

    func waitForExportProgress() -> Bool {
        return progressPhaseText.waitForExistence(timeout: 30)
    }

    func waitForProgressCompletion() -> Bool {
        let shareSheetButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Save'"))
            .firstMatch
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
