import XCTest

class PaywallScreen {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    var closeButton: XCUIElement {
        if app.buttons["dismissPaywall"].exists {
            return app.buttons["dismissPaywall"]
        }
        if app.navigationBars.buttons["Close"].exists {
            return app.navigationBars.buttons["Close"]
        }
        return app.buttons.matching(NSPredicate(format: "label == 'Close'")).firstMatch
    }

    func waitForPaywall(timeout: TimeInterval = 30) -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if app.buttons["Restore Purchases"].exists
                || app.otherElements["paywallView"].exists
                || app.buttons["upgradeButton"].exists
                || app.buttons["dismissPaywall"].exists
            {
                return true
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    func dismiss(timeout: TimeInterval = 5) {
        if closeButton.waitForExistence(timeout: timeout) {
            closeButton.tap()
            _ = waitForPaywallToDismiss(timeout: timeout)
            return
        }

        // Fallback for sheet-style paywalls without an explicit close button.
        if app.sheets.firstMatch.exists {
            app.sheets.firstMatch.swipeDown()
            _ = waitForPaywallToDismiss(timeout: timeout)
            return
        }

        XCTFail("Close button on paywall alert not found")
    }

    @discardableResult
    private func waitForPaywallToDismiss(timeout: TimeInterval) -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if !app.buttons["Restore Purchases"].exists
                && !app.otherElements["paywallView"].exists
                && !app.buttons["upgradeButton"].exists
                && !app.buttons["dismissPaywall"].exists
            {
                return true
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }
}
