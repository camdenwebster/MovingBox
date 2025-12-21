import XCTest

class MultiItemSelectionScreen {
    let app: XCUIApplication
    
    let cancelButton: XCUIElement
    let reanalyzeButton: XCUIElement
    let selectAllButton: XCUIElement
    let deselectAllButton: XCUIElement
    let continueButton: XCUIElement
    let locationButton: XCUIElement
    let selectionCounter: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        
        self.cancelButton = app.buttons["multiItemCancelButton"]
        self.reanalyzeButton = app.buttons["multiItemReanalyzeButton"]
        self.selectAllButton = app.buttons["multiItemSelectAllButton"]
        self.deselectAllButton = app.buttons["multiItemDeselectAllButton"]
        self.continueButton = app.buttons["multiItemContinueButton"]
        self.locationButton = app.buttons["multiItemLocationButton"]
        self.selectionCounter = app.staticTexts["multiItemSelectionCounter"]
    }
    
    func isDisplayed(timeout: TimeInterval = 5) -> Bool {
        return cancelButton.waitForExistence(timeout: timeout)
    }
    
    func getItemCard(at index: Int) -> XCUIElement {
        return app.otherElements["multiItemSelectionCard-\(index)"]
    }
    
    func tapItemCard(at index: Int) {
        let card = getItemCard(at: index)
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Item card at index \(index) should exist")
        card.tap()
    }
    
    func isItemCardVisible(at index: Int) -> Bool {
        return getItemCard(at: index).exists
    }
    
    func getItemCardCount() -> Int {
        var count = 0
        while getItemCard(at: count).exists {
            count += 1
        }
        return count
    }
    
    func tapSelectAll() {
        XCTAssertTrue(selectAllButton.waitForExistence(timeout: 3), "Select All button should exist")
        selectAllButton.tap()
    }
    
    func tapDeselectAll() {
        XCTAssertTrue(deselectAllButton.waitForExistence(timeout: 3), "Deselect All button should exist")
        deselectAllButton.tap()
    }
    
    func tapContinue() {
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3), "Continue button should exist")
        continueButton.tap()
    }
    
    func tapReanalyze() {
        XCTAssertTrue(reanalyzeButton.waitForExistence(timeout: 3), "Reanalyze button should exist")
        reanalyzeButton.tap()
    }
    
    func tapCancel() {
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Cancel button should exist")
        cancelButton.tap()
    }
    
    func tapLocationButton() {
        XCTAssertTrue(locationButton.waitForExistence(timeout: 3), "Location button should exist")
        locationButton.tap()
    }
    
    func getSelectionCounterText() -> String? {
        if selectionCounter.waitForExistence(timeout: 3) {
            return selectionCounter.label
        }
        return nil
    }
    
    func isContinueButtonEnabled() -> Bool {
        return continueButton.isEnabled
    }
    
    func isSelectAllButtonVisible() -> Bool {
        return selectAllButton.exists
    }
    
    func isDeselectAllButtonVisible() -> Bool {
        return deselectAllButton.exists
    }
    
    func waitForAnalysisToComplete(timeout: TimeInterval = 15) -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if isDisplayed(timeout: 1) {
                return true
            }
            sleep(1)
        }
        return false
    }
    
    func scrollToItemCard(at index: Int) {
        let card = getItemCard(at: index)
        if card.exists && !card.isHittable {
            card.swipeLeft()
        }
    }
    
    func getNavigationTitle() -> String? {
        let navigationBar = app.navigationBars.firstMatch
        if navigationBar.waitForExistence(timeout: 3) {
            return navigationBar.identifier
        }
        return nil
    }
}
