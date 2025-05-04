import XCTest

class ImportExportScreen {
    let app: XCUIApplication
    
    // Buttons
    let importButton: XCUIElement
    let exportButton: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        self.importButton = app.buttons["importButton"]
        self.exportButton = app.buttons["exportButton"]
    }
    
    func waitForExportCompletion() -> Bool {
        let emptyShareSheet = app.otherElements.containing(.staticText, identifier: "No Recents").firstMatch
        return emptyShareSheet.waitForExistence(timeout: 10)
    }
    
    func waitForImportCompletion() -> Bool {
        let successAlert = app.alerts["Import Successful"]
        return successAlert.waitForExistence(timeout: 10)
    }
    
    func dismissSuccessAlert() {
        let successAlert = app.alerts["Import Successful"]
        if successAlert.exists {
            successAlert.buttons.firstMatch.tap()
        }
    }
}
