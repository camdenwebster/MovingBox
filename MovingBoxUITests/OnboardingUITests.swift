import XCTest

final class OnboardingUITests: XCTestCase {
    let app = XCUIApplication()
    var cameraScreen: CameraScreen!
    var detailScreen: InventoryDetailScreen!
    var paywallScreen: PaywallScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "Show-Onboarding",
            "Disable-Persistence",
            "UI-Testing-Mock-Camera",
            "Disable-Animations"
        ]
        cameraScreen = CameraScreen(app: app, testCase: self)
        detailScreen = InventoryDetailScreen(app: app)
        paywallScreen = PaywallScreen(app: app)
        
        addNotificationsPermissionsHandler()
        
        app.launch()
    }
    
    func testOnboardingHappyPath() throws {
        // Welcome View
        handleOnboardingWelcomeStep(app: app)
        
        // Item View
        handleOnboardingItemsStep(app: app, camera: cameraScreen)
        
        // Notification View
        handleOnboardingNotificationsStep(app: app)
        
        // Survey View
        handleOnboardingSurveyStep(app: app)
        
        // Completion View
        handleOnboardingCompletionStep(app: app)
        
        // Paywall
        handleOnboardingPaywallStep(app: app)
        
        // Verify we're on the dashboard
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))
        
        // When the user closes and re-opens the app
        app.terminate()
        app.launch()
        
        // The user should be brought straight to the dashboard
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))
    }
    
    func testOnboardingSurveyRequiresSelection() throws {
        
        // Navigate to survey screen
        handleOnboardingWelcomeStep(app: app)
        
        XCTAssertTrue(app.buttons["onboarding-item-take-photo-button"].waitForExistence(timeout: 5), "'Take photo' button in the onboarding view did not appear")
        app.navigationBars.buttons["Skip"].tap()
        
        XCTAssertTrue(app.buttons["notificationsButton"].waitForExistence(timeout: 10), "'Enable notifications' button in the onboarding did not appear")
        app.navigationBars.buttons["Skip"].tap()
        
        // Survey View - continue button should be disabled without selection
        let surveyContinueButton = app.buttons["onboarding-survey-continue-button"]
        XCTAssertTrue(surveyContinueButton.waitForExistence(timeout: 5))
        XCTAssertFalse(surveyContinueButton.isEnabled, "Continue button should be disabled without selection")
        
        // Select an option
        let surveyProtectOption = app.buttons["onboarding-survey-option-protect"]
        XCTAssertTrue(surveyProtectOption.exists)
        surveyProtectOption.tap()
        
        // Continue button should now be enabled
        XCTAssertTrue(surveyContinueButton.isEnabled, "Continue button should be enabled after selection")
        
        // Deselect the option
        surveyProtectOption.tap()
        
        // Continue button should be disabled again
        XCTAssertFalse(surveyContinueButton.isEnabled, "Continue button should be disabled when all options deselected")
    }
    
    func testOnboardingSurveySkip() throws {
        
        // Navigate to survey screen
        app.buttons["onboarding-welcome-continue-button"].waitForExistence(timeout: 10)
        app.buttons["onboarding-welcome-continue-button"].tap()
        
        app.buttons["onboarding-item-take-photo-button"].waitForExistence(timeout: 5)
        app.navigationBars.buttons["Skip"].tap()
        
        app.buttons["notificationsButton"].waitForExistence(timeout: 10)
        app.navigationBars.buttons["Skip"].tap()
        
        // Survey View - skip should work
        let surveyProtectOption = app.buttons["onboarding-survey-option-protect"]
        XCTAssertTrue(surveyProtectOption.waitForExistence(timeout: 5))
        
        app.navigationBars.buttons["Skip"].tap()
        
        // Should reach completion view
        let completionContinueButton = app.buttons["onboarding-completion-continue-button"]
        XCTAssertTrue(completionContinueButton.waitForExistence(timeout: 5))
    }
    
    func testOnboardingSurveyMultipleSelections() throws {
        
        // Navigate to survey screen
        app.buttons["onboarding-welcome-continue-button"].waitForExistence(timeout: 10)
        app.buttons["onboarding-welcome-continue-button"].tap()
        
        app.buttons["onboarding-item-take-photo-button"].waitForExistence(timeout: 5)
        app.navigationBars.buttons["Skip"].tap()
        
        app.buttons["notificationsButton"].waitForExistence(timeout: 10)
        app.navigationBars.buttons["Skip"].tap()
        
        // Survey View - select multiple options
        let surveyProtectOption = app.buttons["onboarding-survey-option-protect"]
        XCTAssertTrue(surveyProtectOption.waitForExistence(timeout: 5))
        surveyProtectOption.tap()
        
        let surveyOrganizeOption = app.buttons["onboarding-survey-option-organize"]
        XCTAssertTrue(surveyOrganizeOption.exists)
        surveyOrganizeOption.tap()
        
        let surveyMoveOption = app.buttons["onboarding-survey-option-move"]
        XCTAssertTrue(surveyMoveOption.exists)
        surveyMoveOption.tap()
        
        let surveyExploringOption = app.buttons["onboarding-survey-option-exploring"]
        XCTAssertTrue(surveyExploringOption.exists)
        surveyExploringOption.tap()
        
        // All options should be selectable
        let surveyContinueButton = app.buttons["onboarding-survey-continue-button"]
        XCTAssertTrue(surveyContinueButton.isEnabled, "Continue button should be enabled with multiple selections")
        
        surveyContinueButton.tap()
        
        // Should reach completion view
        let completionContinueButton = app.buttons["onboarding-completion-continue-button"]
        XCTAssertTrue(completionContinueButton.waitForExistence(timeout: 5))
    }
}

extension XCUIApplication {
    func setLaunchArgument(skipOnboarding: Bool) {
        if skipOnboarding {
            launchArguments.append("Skip-Onboarding")
        } else {
            launchArguments.append("Show-Onboarding")
        }
    }
}

extension XCTestCase {
    // Notifications permissions handler
    func addNotificationsPermissionsHandler() {
        addUIInterruptionMonitor(withDescription: "Notifications Authorization Alert") { alert in
            print("📱 Notifications permission alert appeared")
            let allowButton = alert.buttons["Allow"]
            if allowButton.exists {
                print("✅ Tapping Allow button")
                allowButton.tap()
                return true
            }
            print("❌ Allow button not found")
            return false
        }
    }
    
    func handleOnboardingWelcomeStep(app: XCUIApplication) {
        XCTAssertTrue(app.buttons["onboarding-welcome-continue-button"].waitForExistence(timeout: 10))
        app.buttons["onboarding-welcome-continue-button"].tap()
    }
    
    func handleOnboardingItemsStep(app: XCUIApplication, camera: CameraScreen) {
        let itemTakePhotoButton = app.buttons["onboarding-item-take-photo-button"]
        XCTAssertTrue(itemTakePhotoButton.waitForExistence(timeout: 10))
        itemTakePhotoButton.tap()

        // Handle privacy notice alert
        let alertContinueButton = app.alerts.buttons["Continue"]
        XCTAssertTrue(alertContinueButton.waitForExistence(timeout: 5))
        alertContinueButton.tap()

        // Camera should be ready
        XCTAssertTrue(camera.waitForCamera(),
                     "Camera should be ready after permissions")

        // User takes a photo
        camera.takePhoto()

        // Wait for AI processing and save item
        XCTAssertTrue(self.detailScreen.saveButton.waitForExistence(timeout: 30))
        self.detailScreen.saveButton.tap()
    }
    
    func handleOnboardingNotificationsStep(app: XCUIApplication) {
        let enableNotificationsButton = app.buttons["notificationsButton"]
        XCTAssertTrue(enableNotificationsButton.waitForExistence(timeout: 10))
        enableNotificationsButton.tap()
    }
    
    func handleOnboardingSurveyStep(app: XCUIApplication) {
        let surveyProtectOption = app.buttons["onboarding-survey-option-protect"]
        XCTAssertTrue(surveyProtectOption.waitForExistence(timeout: 5))
        surveyProtectOption.tap()
        
        let surveyOrganizeOption = app.buttons["onboarding-survey-option-organize"]
        XCTAssertTrue(surveyOrganizeOption.exists)
        surveyOrganizeOption.tap()
        
        let surveyContinueButton = app.buttons["onboarding-survey-continue-button"]
        XCTAssertTrue(surveyContinueButton.exists)
        surveyContinueButton.tap()
    }
    
    func handleOnboardingCompletionStep(app: XCUIApplication) {
        let completionContinueButton = app.buttons["onboarding-completion-continue-button"]
        XCTAssertTrue(completionContinueButton.waitForExistence(timeout: 5))
        completionContinueButton.tap()
    }
    
    func handleOnboardingPaywallStep(app: XCUIApplication) {
        XCTAssertTrue(self.paywallScreen.okButton.waitForExistence(timeout: 5))
        self.paywallScreen.okButton.tap()
    }
}
