import XCTest

final class FamilySharingUITests: XCTestCase {
    private let app = XCUIApplication()
    private var dashboardScreen: DashboardScreen!
    private var settingsScreen: SettingsScreen!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app.launchArguments = [
            "Use-Test-Data",
            "Disable-Animations",
            "Skip-Onboarding",
            "UI-Testing-Mock-Camera",
            "Mock-AI",
            "Disable-Persistence",
            "Is-Pro",
        ]

        dashboardScreen = DashboardScreen(app: app)
        settingsScreen = SettingsScreen(app: app)

        app.launch()
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible after launch")
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testFamilySharingUsesToggleAndNoCustomInviteSheet() throws {
        openFamilySharing()
        enableFamilySharingIfNeeded()
        let inviteButton = waitForInviteButton(timeout: 20)
        XCTAssertNotNil(inviteButton, "Invite button should be visible and hittable")
        guard let inviteButton else {
            return
        }
        inviteButton.tap()

        XCTAssertFalse(app.textFields["Name"].waitForExistence(timeout: 2), "Legacy invite sheet should not appear")
        XCTAssertFalse(app.textFields["Email"].waitForExistence(timeout: 2), "Legacy invite sheet should not appear")
    }

    func testScopingControlsAreHiddenByDefault() throws {
        openFamilySharing()
        enableFamilySharingIfNeeded()

        XCTAssertFalse(
            app.segmentedControls["family-sharing-policy-picker"].exists,
            "Policy picker should be hidden when scoping feature flag is disabled"
        )

        navigateBackIfPossible()
        settingsScreen.tapManageHomes()
        openMainHomeFromList()
        XCTAssertFalse(
            app.switches["home-private-toggle"].exists,
            "Home scoping controls should be hidden when scoping feature flag is disabled"
        )
    }

    func testScopingControlsAppearWhenFlagEnabled() throws {
        app.terminate()
        app.launchArguments = [
            "Use-Test-Data",
            "Disable-Animations",
            "Skip-Onboarding",
            "UI-Testing-Mock-Camera",
            "Mock-AI",
            "Disable-Persistence",
            "Is-Pro",
            "Enable-Family-Sharing-Scoping",
        ]
        app.launch()

        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible after relaunch")

        openFamilySharing()
        enableFamilySharingIfNeeded()
        let pickerByID = app.segmentedControls["family-sharing-policy-picker"]
        let allHomesOption = app.buttons["All Homes"]
        let ownerScopedOption = app.buttons["Owner Scoped"]
        let pickerVisible =
            pickerByID.waitForExistence(timeout: 15)
            || (allHomesOption.waitForExistence(timeout: 15) && ownerScopedOption.exists)
        XCTAssertTrue(pickerVisible, "Policy picker should be visible when scoping feature flag is enabled")

        navigateBackIfPossible()
        settingsScreen.tapManageHomes()
        openMainHomeFromList()
        let privateToggle = app.switches["home-private-toggle"]
        XCTAssertTrue(privateToggle.waitForExistence(timeout: 5), "Home scoping controls should be visible")
    }

    private func openFamilySharing() {
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings should be visible")

        settingsScreen.tapFamilySharing()
        XCTAssertTrue(app.navigationBars["Family Sharing"].waitForExistence(timeout: 5), "Family Sharing should open")
    }

    private func enableFamilySharingIfNeeded() {
        let sharingToggle = app.switches["family-sharing-toggle"]
        XCTAssertTrue(sharingToggle.waitForExistence(timeout: 8), "Family sharing toggle should be visible")

        let hittableDeadline = Date().addingTimeInterval(8)
        while !sharingToggle.isHittable, Date() < hittableDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        if waitForInviteAffordance(timeout: 5) {
            return
        }

        if sharingToggle.isHittable {
            sharingToggle.tap()
        }

        _ = waitForInviteAffordance(timeout: 15)
    }

    private func waitForInviteButton(timeout: TimeInterval) -> XCUIElement? {
        let navBar = app.navigationBars["Family Sharing"]
        let inviteButton = app.buttons["family-sharing-invite-button"]
        let inviteLabelButton = app.buttons["Invite"]
        let inviteSymbolButton = app.buttons["person.badge.plus"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let candidates: [XCUIElement] = {
                var elements = [inviteButton, inviteLabelButton, inviteSymbolButton]
                if navBar.exists {
                    elements.append(contentsOf: navBar.buttons.allElementsBoundByIndex)
                }
                return elements
            }()

            for candidate in candidates where candidate.exists && candidate.isHittable {
                let label = candidate.label.lowercased()
                if label.contains("back") {
                    continue
                }
                return candidate
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return nil
    }

    private func waitForInviteAffordance(timeout: TimeInterval) -> Bool {
        let inviteHint = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Use the invite button")
        ).firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if inviteHint.exists || waitForInviteButton(timeout: 0.1) != nil {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return inviteHint.exists || waitForInviteButton(timeout: 0.1) != nil
    }

    private func openMainHomeFromList() {
        XCTAssertTrue(app.navigationBars["Homes"].waitForExistence(timeout: 5), "Home list should be visible")
        let predicates = [
            NSPredicate(format: "label CONTAINS[c] %@", "Main House"),
            NSPredicate(format: "label CONTAINS[c] %@", "123 Main Street"),
        ]

        for predicate in predicates {
            let candidate = app.buttons.matching(predicate).firstMatch
            if candidate.waitForExistence(timeout: 2) {
                candidate.tap()
                if !app.navigationBars["Homes"].exists {
                    return
                }
                navigateBackIfPossible()
            }
        }

        XCTFail("Could not open a home detail screen from home list")
    }

    private func navigateBackIfPossible() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
    }
}
