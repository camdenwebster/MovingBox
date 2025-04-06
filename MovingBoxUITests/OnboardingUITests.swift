import XCTest

final class OnboardingUITests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }
    
    func testOnboardingHappyPath() throws {
        // Welcome View
        XCTAssertTrue(app.buttons["onboarding-welcome-continue-button"].exists)
        app.buttons["onboarding-welcome-continue-button"].tap()
        
        // Home View
        let homeAddPhotoButton = app.buttons["onboarding-home-add-photo-button"]
        XCTAssertTrue(homeAddPhotoButton.exists)
        homeAddPhotoButton.tap()
        
        allowCameraAccess()
        simulatePhotoCapture()
        
        let homeNameField = app.textFields["onboarding-home-name-field"]
        XCTAssertTrue(homeNameField.exists)
        homeNameField.tap()
        homeNameField.typeText("My Home")
        
        let homeContinueButton = app.buttons["onboarding-home-continue-button"]
        XCTAssertTrue(homeContinueButton.exists)
        homeContinueButton.tap()
        
        // Location View
        let locationAddPhotoButton = app.buttons["onboarding-location-add-photo-button"]
        XCTAssertTrue(locationAddPhotoButton.exists)
        locationAddPhotoButton.tap()
        
        simulatePhotoCapture()
        
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
        XCTAssertTrue(itemTakePhotoButton.exists)
        itemTakePhotoButton.tap()
        
        // Handle privacy notice alert
        let alertContinueButton = app.alerts.buttons["Continue"]
        XCTAssertTrue(alertContinueButton.waitForExistence(timeout: 5))
        alertContinueButton.tap()
        
        simulatePhotoCapture()
        
        // Wait for AI processing and save item
        let saveItemButton = app.buttons["save-item-button"] // Make sure to add this identifier to your item detail view
        XCTAssertTrue(saveItemButton.waitForExistence(timeout: 10))
        saveItemButton.tap()
        
        // Completion View
        let completionContinueButton = app.buttons["onboarding-completion-continue-button"]
        XCTAssertTrue(completionContinueButton.exists)
        completionContinueButton.tap()
        
        // Paywall
        let paywallCloseButton = app.buttons["paywall-close-button"] // Make sure to add this identifier to your paywall view
        XCTAssertTrue(paywallCloseButton.waitForExistence(timeout: 5))
        paywallCloseButton.tap()
        
        // Verify we're on the dashboard
        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 5))
    }
    
    private func allowCameraAccess() {
        addUIInterruptionMonitor(withDescription: "Camera Permission Alert") { alert in
            alert.buttons["Allow"].tap()
            return true
        }
        // Trigger the interruption handler
        app.tap()
    }
    
    private func simulatePhotoCapture() {
        let takePhotoButton = app.buttons["camera-shutter-button"] // Make sure to add this identifier to your camera view
        XCTAssertTrue(takePhotoButton.waitForExistence(timeout: 5))
        takePhotoButton.tap()
        
        let usePhotoButton = app.buttons["use-photo-button"] // Make sure to add this identifier to your photo review view
        XCTAssertTrue(usePhotoButton.waitForExistence(timeout: 5))
        usePhotoButton.tap()
    }
}

extension XCUIApplication {
    func setLaunchArgument(skipOnboarding: Bool) {
        if skipOnboarding {
            launchArguments.append("--Skip-Onboarding")
        }
    }
}