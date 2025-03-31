import XCTest

class CameraScreen {
    let app: XCUIApplication
    
    // Camera controls
    let captureButton: XCUIElement
    let switchCameraButton: XCUIElement
    let dismissButton: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        
        // Initialize camera controls
        self.captureButton = app.buttons["capturePhoto"]
        self.switchCameraButton = app.buttons["switchCamera"]
        self.dismissButton = app.buttons["dismissCamera"]
    }
    
    func takePhoto() {
        captureButton.tap()
    }
    
    func switchCamera() {
        switchCameraButton.tap()
    }
    
    func dismiss() {
        dismissButton.tap()
    }
}