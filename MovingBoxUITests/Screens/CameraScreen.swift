import XCTest

class CameraScreen {
    let app: XCUIApplication
    let testCase: XCTestCase
    
    // Camera controls
    let captureButton: XCUIElement
    let switchCameraButton: XCUIElement
    let dismissButton: XCUIElement
    
    init(app: XCUIApplication, testCase: XCTestCase) {
        self.app = app
        self.testCase = testCase
        
        // Initialize camera controls
        self.captureButton = app.buttons["takePhotoButton"]
        self.switchCameraButton = app.buttons["switchCamera"]
        self.dismissButton = app.buttons["dismissCamera"]
        
        // Set up interruption monitor for camera permissions
        addCameraPermissionsHandler()
    }
    
    // Camera permissions handler
    private func addCameraPermissionsHandler() {
        testCase.addUIInterruptionMonitor(withDescription: "Camera Authorization Alert") { alert in
            print("📱 Camera permission alert appeared")
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
    
    func waitForCamera(timeout: TimeInterval = 5) -> Bool {
        app.tap()
        let captureButtonExists = captureButton.waitForExistence(timeout: timeout)
        
        return captureButtonExists
    }
    
    func takePhoto(timeout: TimeInterval = 5) {
        guard waitForCamera(timeout: timeout) else {
            XCTFail("❌ Camera not ready")
            return
        }
        print("📸 Taking photo")
        captureButton.tap()
        
        let expectation = testCase.expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: captureButton,
            handler: nil
        )
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
    }
    
    func switchCamera(timeout: TimeInterval = 5) {
        guard waitForCamera(timeout: timeout) else {
            XCTFail("❌ Camera not ready")
            return
        }
        print("🔄 Switching camera")
        switchCameraButton.tap()
    }
    
    func dismiss() {
        if dismissButton.waitForExistence(timeout: 2) {
            dismissButton.tap()
        }
    }
}
