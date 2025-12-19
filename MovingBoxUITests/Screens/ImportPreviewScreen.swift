import XCTest

class ImportPreviewScreen {
    let app: XCUIApplication
    
    let startButton: XCUIElement
    let dismissButton: XCUIElement
    let itemsCount: XCUIElement
    let locationsCount: XCUIElement
    let labelsCount: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        self.startButton = app.buttons["import-preview-start-button"]
        self.dismissButton = app.buttons["import-preview-dismiss-button"]
        self.itemsCount = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Items'")).firstMatch
        self.locationsCount = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Locations'")).firstMatch
        self.labelsCount = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Labels'")).firstMatch
    }
    
    func isDisplayed() -> Bool {
        return startButton.waitForExistence(timeout: 5) &&
               app.navigationBars.staticTexts["Ready to Import"].exists
    }
    
    func tapStartButton() {
        startButton.tap()
    }
    
    func tapDismissButton() {
        dismissButton.tap()
    }
    
    func waitForImporting() -> Bool {
        let progressIndicator = app.progressIndicators.firstMatch
        return progressIndicator.waitForExistence(timeout: 10)
    }
    
    func waitForImportComplete() -> Bool {
        return !startButton.exists || startButton.isHittable
    }
    
    func isStartButtonEnabled() -> Bool {
        return startButton.isEnabled
    }
    
    func isStartButtonDisabled() -> Bool {
        return !startButton.isEnabled
    }
    
    func waitForErrorState() -> Bool {
        let errorIcon = app.images.matching(NSPredicate(format: "identifier CONTAINS 'xmark'")).firstMatch
        return errorIcon.waitForExistence(timeout: 10)
    }
    
    func getErrorMessage() -> String {
        let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Import Failed'")).firstMatch
        return errorText.label
    }
}
