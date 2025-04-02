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
        self.captureButton = app.buttons["capturePhoto"]
        self.switchCameraButton = app.buttons["switchCamera"]
        self.dismissButton = app.buttons["dismissCamera"]
        
        // Set up interruption monitor for camera permissions
        addCameraPermissionsHandler()
    }
    
    // Camera permissions handler
    private func addCameraPermissionsHandler() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        testCase.addUIInterruptionMonitor(withDescription: "Camera Authorization Alert") { alert in
            let allowButton = alert.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
                return true
            }
            return false
        }
    }
    
    func takePhoto() {
        // Handle potential system alert by interacting with app
        app.tap() // Trigger interruption handler if alert exists
        captureButton.tap()
    }
    
    func switchCamera() {
        // Handle potential system alert by interacting with app
        app.tap() // Trigger interruption handler if alert exists
        switchCameraButton.tap()
    }
    
    func dismiss() {
        dismissButton.tap()
    }
}
