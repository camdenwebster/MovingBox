import XCTest

class PaywallScreen {
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    var okButton: XCUIElement {
        return app.scrollViews.containing(.button, identifier: "OK").firstMatch
    }
    
    func waitForPaywall(timeout: TimeInterval = 5) -> Bool {
        let viewExists = okButton.waitForExistence(timeout: timeout)
        
        return viewExists
    }
    
    
    func dismiss(timeout: TimeInterval = 5) {
        guard okButton.waitForExistence(timeout: timeout) else {
            XCTFail("OK button on paywall alert nnot found")
            return
        }
        okButton.tap()
        
        let expectation = XCTestExpectation(description: "Paywall dismissed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !self.okButton.exists {
                expectation.fulfill()
            }
        }
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
    }
}
