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
    
    func waitForPaywall(timeout: TimeInterval = 5) -> Bool {
        let viewExists = paywallView.waitForExistence(timeout: timeout)
        let upgradeExists = upgradeButton.waitForExistence(timeout: timeout)
        
        return viewExists && upgradeExists
    }
    
    func upgrade(timeout: TimeInterval = 5) {
        guard waitForPaywall(timeout: timeout) else {
            XCTFail("Paywall not visible")
            return
        }
        upgradeButton.tap()
    }
    
    func dismiss(timeout: TimeInterval = 5) {
        guard dismissButton.waitForExistence(timeout: timeout) else {
            XCTFail("Dismiss button not found")
            return
        }
        dismissButton.tap()
        
        let expectation = XCTestExpectation(description: "Paywall dismissed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !self.paywallView.exists {
                expectation.fulfill()
            }
        }
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
    }
}
