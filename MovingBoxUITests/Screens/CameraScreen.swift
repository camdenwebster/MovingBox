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
    
    func waitForCamera() -> Bool {
        // Trigger the permission dialog if needed
        app.tap()
        
        // Wait for capture button to be available
        return captureButton.waitForExistence(timeout: 5)
    }
    
    func takePhoto() {
        guard waitForCamera() else {
            print("❌ Camera not ready")
            return
        }
        print("📸 Taking photo")
        captureButton.tap()
    }
    
    func switchCamera() {
        guard waitForCamera() else {
            print("❌ Camera not ready")
            return
        }
        print("🔄 Switching camera")
        switchCameraButton.tap()
    }
    
    func dismiss() {
        dismissButton.tap()
    }
}
