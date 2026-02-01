import XCTest

class ImportSuccessScreen {
    let app: XCUIApplication

    let dashboardButton: XCUIElement
    let successTitle: XCUIElement
    let itemsCount: XCUIElement
    let locationsCount: XCUIElement
    let labelsCount: XCUIElement

    init(app: XCUIApplication) {
        self.app = app
        self.dashboardButton = app.buttons["import-success-dashboard-button"]
        self.successTitle =
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Import Complete'")).firstMatch
        self.itemsCount =
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'item'")).firstMatch
        self.locationsCount =
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'location'")).firstMatch
        self.labelsCount =
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'label'")).firstMatch
    }

    func isDisplayed() -> Bool {
        return dashboardButton.waitForExistence(timeout: 10) && successTitle.exists
    }

    func tapDashboardButton() {
        dashboardButton.tap()
    }

    func waitForCheckmark() -> Bool {
        let checkmark = app.images.matching(NSPredicate(format: "identifier CONTAINS 'checkmark'"))
            .firstMatch
        return checkmark.waitForExistence(timeout: 5)
    }

    func hasImportedItems() -> Bool {
        return itemsCount.exists
    }

    func hasImportedLocations() -> Bool {
        return locationsCount.exists
    }

    func hasImportedLabels() -> Bool {
        return labelsCount.exists
    }
}
