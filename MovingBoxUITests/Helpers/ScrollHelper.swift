import XCTest

extension XCUIElement {

    /// Scrolls this element to the vertical center of the screen, then taps it.
    ///
    /// Uses a two-phase approach:
    /// 1. Coarse swipes on the parent scrollable container to bring the element on-screen.
    /// 2. A precise coordinate drag to center the element vertically.
    ///
    /// - Parameters:
    ///   - app: The `XCUIApplication` instance used to resolve the screen frame.
    ///   - maxSwipes: Maximum number of coarse swipes before giving up (default 10).
    ///   - timeout: Seconds to wait for the element to exist before scrolling (default 5).
    func scrollToCenter(in app: XCUIApplication, maxSwipes: Int = 10, timeout: TimeInterval = 5) {
        guard waitForExistence(timeout: timeout) || exists else {
            XCTFail("Element \(debugDescription) does not exist after \(timeout)s — cannot scroll to it")
            return
        }

        let screenFrame = app.windows.firstMatch.frame
        let screenMidY = screenFrame.midY

        // Phase 1: Coarse swipes to bring the element on-screen (hittable).
        if !isHittable {
            // Find the nearest scrollable ancestor to swipe on.
            let scrollTarget =
                app.scrollViews.firstMatch.exists
                ? app.scrollViews.firstMatch
                : app

            // Start by swiping down (element might be above the viewport).
            var direction: SwipeDirection = .up
            if frame.midY < screenFrame.minY {
                direction = .down
            }

            for _ in 0..<maxSwipes {
                if isHittable { break }
                switch direction {
                case .up:
                    scrollTarget.swipeUp()
                case .down:
                    scrollTarget.swipeDown()
                }
            }

            guard isHittable else {
                XCTFail("Element \(debugDescription) not hittable after \(maxSwipes) swipes")
                return
            }
        }

        // Phase 2: Fine drag to center the element vertically on screen.
        let elementMidY = frame.midY
        let offset = elementMidY - screenMidY

        // Only adjust if the element is more than 40pt away from center.
        if abs(offset) > 40 {
            let scrollTarget =
                app.scrollViews.firstMatch.exists
                ? app.scrollViews.firstMatch
                : app

            let startPoint = scrollTarget.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
            )
            let endPoint = startPoint.withOffset(CGVector(dx: 0, dy: -offset))
            startPoint.press(forDuration: 0.05, thenDragTo: endPoint)
        }
    }

    /// Scrolls this element to the vertical center of the screen, then taps it.
    ///
    /// Convenience that combines `scrollToCenter(in:)` with `tap()`.
    func scrollToCenterAndTap(in app: XCUIApplication, maxSwipes: Int = 10, timeout: TimeInterval = 5) {
        scrollToCenter(in: app, maxSwipes: maxSwipes, timeout: timeout)
        tap()
    }
}

private enum SwipeDirection {
    case up, down
}
