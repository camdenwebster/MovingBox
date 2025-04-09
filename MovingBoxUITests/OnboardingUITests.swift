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
            "UI-Testing-Mock-Camera"
        ]
        cameraScreen = CameraScreen(app: app, testCase: self)
        detailScreen = InventoryDetailScreen(app: app)
        paywallScreen = PaywallScreen(app: app)
        app.launch()
    }
    
    func testOnboardingHappyPath() throws {
        
        // Welcome View
        XCTAssertTrue(app.buttons["onboarding-welcome-continue-button"].waitForExistence(timeout: 10))
        app.buttons["onboarding-welcome-continue-button"].tap()
        
        // Home View
        let homeAddPhotoButton = app.buttons["onboarding-home-add-photo-button"]
        XCTAssertTrue(homeAddPhotoButton.waitForExistence(timeout: 10))
        homeAddPhotoButton.tap()
        
        app.sheets.buttons["takePhoto"].tap()
        
        // Then: Camera should be ready
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera should be ready after permissions")
        
        // When: User takes a photo
        cameraScreen.takePhoto()
        
        let homeNameField = app.textFields["onboarding-home-name-field"]
        XCTAssertTrue(homeNameField.exists)
        homeNameField.tap()
        homeNameField.typeText("My Home")
        
        let homeContinueButton = app.buttons["onboarding-home-continue-button"]
        XCTAssertTrue(homeContinueButton.exists)
        homeContinueButton.tap()
        
        // Location View
        let locationAddPhotoButton = app.buttons["onboarding-location-add-photo-button"]
        XCTAssertTrue(locationAddPhotoButton.waitForExistence(timeout: 5))
        locationAddPhotoButton.tap()
        
        app.sheets.buttons["takePhoto"].tap()
        
        // Then: Camera should be ready
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera should be ready after permissions")
        
        // When: User takes a photo
        cameraScreen.takePhoto()
        
        let locationNameField = app.textFields["onboarding-location-name-field"]
        XCTAssertTrue(locationNameField.exists)
        locationNameField.tap()
        locationNameField.typeText("Kitchen")
        
        let locationDescField = app.textFields["onboarding-location-description-field"]
        XCTAssertTrue(locationDescField.exists)
        locationDescField.tap()
        locationDescField.typeText("My awesome kitchen")
        
        let locationContinueButton = app.buttons["onboarding-location-continue-button"]
        XCTAssertTrue(locationContinueButton.exists)
        locationContinueButton.tap()
        
        // Item View
        let itemTakePhotoButton = app.buttons["onboarding-item-take-photo-button"]
        XCTAssertTrue(itemTakePhotoButton.waitForExistence(timeout: 5))
        itemTakePhotoButton.tap()
        
        // Handle privacy notice alert
        let alertContinueButton = app.alerts.buttons["Continue"]
        XCTAssertTrue(alertContinueButton.waitForExistence(timeout: 5))
        alertContinueButton.tap()
        
        // Then: Camera should be ready
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera should be ready after permissions")
        
        // When: User takes a photo
        cameraScreen.takePhoto()
        
        // Wait for AI processing and save item
        XCTAssertTrue(detailScreen.saveButton.waitForExistence(timeout: 10))
        detailScreen.saveButton.tap()
        
        // Completion View
        let completionContinueButton = app.buttons["onboarding-completion-continue-button"]
        XCTAssertTrue(completionContinueButton.waitForExistence(timeout: 5))
        completionContinueButton.tap()
        
        // Paywall
        XCTAssertTrue(paywallScreen.okButton.waitForExistence(timeout: 5))
        paywallScreen.okButton.tap()
        
        // Verify we're on the dashboard
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))
        
        // When the user closes and re-opens the app
        app.terminate()
        app.launch()
        
        // The user should be brought straight to the dashboard
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))

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
