import XCTest

class PaywallScreen {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    var closeButton: XCUIElement {
        return app.scrollViews.buttons.firstMatch
    }

    func waitForPaywall(timeout: TimeInterval = 30) -> Bool {
        return app.buttons["Restore Purchases"].firstMatch.waitForExistence(timeout: timeout)
    }

    func dismiss(timeout: TimeInterval = 5) {
        guard closeButton.waitForExistence(timeout: timeout) else {
            XCTFail("Close button on paywall alert not found")
            return
        }
        closeButton.tap()

        let expectation = XCTestExpectation(description: "Paywall dismissed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !self.closeButton.exists {
                expectation.fulfill()
            }
        }
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
    }
}
