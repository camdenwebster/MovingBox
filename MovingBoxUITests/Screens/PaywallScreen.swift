import XCTest

class PaywallScreen {
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    var restorePurchasesButton: XCUIElement {
        app.buttons["Restore Purchases"]
    }
    
    var closeButton: XCUIElement {
        app.scrollViews.buttons.firstMatch
    }
    
    func waitForPaywall(timeout: TimeInterval = 5) -> Bool {
        restorePurchasesButton.waitForExistence(timeout: timeout)
    }
    
    
    func dismiss(timeout: TimeInterval = 5) {
        // Make sure the Paywall is up
        guard restorePurchasesButton.waitForExistence(timeout: timeout) else {
            XCTFail("Restore Purchases button on paywall alert not found")
            return
        }
        
        // Then tap the close button to dismiss the paywall
        closeButton.tap()
    }
}
