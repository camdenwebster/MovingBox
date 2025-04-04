import XCTest

class PaywallScreen {
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    var paywallView: XCUIElement {
        app.otherElements["paywallView"]
    }
    
    var upgradeButton: XCUIElement {
        app.buttons["upgradeButton"]
    }
    
    var dismissButton: XCUIElement {
        app.buttons["dismissPaywall"]
    }
    
    func waitForPaywall() -> Bool {
        paywallView.waitForExistence(timeout: 5)
    }
    
    func upgrade() {
        upgradeButton.tap()
    }
    
    func dismiss() {
        dismissButton.tap()
    }
}