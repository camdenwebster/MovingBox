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

    func testEnableFamilySharingShowsPrivateHomeWarning() throws {
        openFamilySharing()

        let enableButton = app.buttons["family-sharing-enable-button"]
        XCTAssertTrue(enableButton.waitForExistence(timeout: 5), "Enable Family Sharing button should be visible")
        enableButton.tap()

        let warningText = app.staticTexts[
            "You can keep specific homes private and exclude them from automatic sharing."
        ]
        XCTAssertTrue(warningText.waitForExistence(timeout: 5), "Private-home warning should be shown")

        let confirmButton = app.alerts.buttons["Enable"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Enable confirmation button should be visible")
        confirmButton.tap()

        XCTAssertTrue(
            app.segmentedControls["family-sharing-policy-picker"].waitForExistence(timeout: 5),
            "Global sharing policy picker should be shown after enabling"
        )
    }

    func testInviteAcceptanceUpdatesGlobalSharingMembers() throws {
        openFamilySharing()
        enableSharingIfNeeded()

        let inviteButton = app.buttons["family-sharing-invite-button"]
        XCTAssertTrue(inviteButton.waitForExistence(timeout: 5), "Invite button should be visible")
        inviteButton.tap()

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name field should appear in invite sheet")
        nameField.tap()
        nameField.typeText("Alex")

        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText("alex@example.com")

        app.buttons["Send Invite"].tap()

        let markAccepted = app.buttons["Mark Accepted"].firstMatch
        XCTAssertTrue(markAccepted.waitForExistence(timeout: 5), "Pending invite should be visible")
        markAccepted.tap()

        XCTAssertTrue(
            app.staticTexts["Alex"].waitForExistence(timeout: 5)
                || app.staticTexts["alex@example.com"].waitForExistence(timeout: 5),
            "Accepted invite should appear in active members"
        )
    }

    func testHomeAccessOverrideControlsAreInteractive() throws {
        openFamilySharing()
        enableSharingIfNeeded()
        inviteAndAcceptMember(name: "Jordan", email: "jordan@example.com")

        navigateBackIfPossible()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Should return to Settings")

        settingsScreen.tapManageHomes()
        XCTAssertTrue(app.navigationBars["Homes"].waitForExistence(timeout: 5), "Home list should be visible")

        openMainHomeFromList()

        let privateToggle = app.switches["home-private-toggle"]
        XCTAssertTrue(privateToggle.waitForExistence(timeout: 5), "Private home toggle should be shown")
        privateToggle.tap()

        let overridePicker = app.segmentedControls.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home-override-picker-")
        ).firstMatch
        XCTAssertTrue(overridePicker.waitForExistence(timeout: 5), "Member home override picker should be visible")

        let denyButton = overridePicker.buttons["Deny"]
        XCTAssertTrue(denyButton.exists, "Deny segment should be available")
        denyButton.tap()
        XCTAssertTrue(denyButton.exists, "Deny segment should remain visible after selection")
    }

    private func openFamilySharing() {
        dashboardScreen.tapSettings()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings should be visible")

        settingsScreen.tapFamilySharing()
        XCTAssertTrue(app.navigationBars["Family Sharing"].waitForExistence(timeout: 5), "Family Sharing should open")
    }

    private func enableSharingIfNeeded() {
        let enableButton = app.buttons["family-sharing-enable-button"]
        if enableButton.waitForExistence(timeout: 2) {
            enableButton.tap()
            let confirmButton = app.alerts.buttons["Enable"]
            XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Enable confirmation should appear")
            confirmButton.tap()
        }

        XCTAssertTrue(
            app.segmentedControls["family-sharing-policy-picker"].waitForExistence(timeout: 5),
            "Policy picker should be visible once sharing is enabled"
        )
    }

    private func inviteAndAcceptMember(name: String, email: String) {
        let inviteButton = app.buttons["family-sharing-invite-button"]
        XCTAssertTrue(inviteButton.waitForExistence(timeout: 5), "Invite button should be visible")
        inviteButton.tap()

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Invite name field should be visible")
        nameField.tap()
        nameField.typeText(name)

        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText(email)

        app.buttons["Send Invite"].tap()

        let markAccepted = app.buttons["Mark Accepted"].firstMatch
        XCTAssertTrue(markAccepted.waitForExistence(timeout: 5), "Pending invite should exist")
        markAccepted.tap()

        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: 5)
                || app.staticTexts[email].waitForExistence(timeout: 5),
            "Accepted invite should appear in members"
        )
    }

    private func openMainHomeFromList() {
        let predicates = [
            NSPredicate(format: "label CONTAINS[c] %@", "Main House"),
            NSPredicate(format: "label CONTAINS[c] %@", "123 Main Street"),
        ]

        for predicate in predicates {
            let candidate = app.buttons.matching(predicate).firstMatch
            if candidate.waitForExistence(timeout: 2) {
                candidate.tap()
                if app.switches["home-private-toggle"].waitForExistence(timeout: 5) {
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
