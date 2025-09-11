import XCTest

class CameraScreen {
    let app: XCUIApplication
    let testCase: XCTestCase
    
    // Camera controls
    let captureButton: XCUIElement
    let takePhotoButton: XCUIElement
    let switchCameraButton: XCUIElement
    let dismissButton: XCUIElement
    let doneButton: XCUIElement
    let flashButton: XCUIElement
    let photoPickerButton: XCUIElement
    let photoCountLabel: XCUIElement
    
    init(app: XCUIApplication, testCase: XCTestCase) {
        self.app = app
        self.testCase = testCase
        
        // Initialize camera controls based on MultiPhotoCameraView structure
        self.captureButton = app.buttons["cameraShutterButton"]
        self.takePhotoButton = app.buttons["takePhotoButton"].firstMatch
        self.switchCameraButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'arrow.triangle.2.circlepath.camera'")).element
        self.dismissButton = app.buttons["cameraCloseButton"]
        self.doneButton = app.buttons["cameraDoneButton"]
        self.flashButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'bolt'")).element
        self.photoPickerButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'photo.on.rectangle'")).element
        self.photoCountLabel = app.staticTexts["cameraPhotoCount"]
        
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
        // In UI testing mode, we should see the mock tablet image
        let cameraReady = doneButton.waitForExistence(timeout: timeout) || captureButton.waitForExistence(timeout: timeout) || takePhotoButton.waitForExistence(timeout: timeout)
        
        return cameraReady
    }
    
    func takePhoto(timeout: TimeInterval = 5) {
        guard waitForCamera(timeout: timeout) else {
            XCTFail("❌ Camera not ready")
            return
        }
        print("📸 Taking photo")
        
        if captureButton.waitForExistence(timeout: 2) {
            captureButton.tap()
            doneButton.tap()
        } else {
            takePhotoButton.tap()
        }
    }
    
    func switchCamera(timeout: TimeInterval = 5) {
        guard waitForCamera(timeout: timeout) else {
            XCTFail("❌ Camera not ready")
            return
        }
        print("🔄 Switching camera")
        if switchCameraButton.waitForExistence(timeout: 2) {
            switchCameraButton.tap()
        }
    }
    
    func toggleFlash() {
        if flashButton.waitForExistence(timeout: 2) {
            flashButton.tap()
        }
    }
    
    func openPhotoLibrary() {
        if photoPickerButton.waitForExistence(timeout: 2) {
            photoPickerButton.tap()
        }
    }
    
    func getPhotoCount() -> String? {
        if photoCountLabel.waitForExistence(timeout: 2) {
            return photoCountLabel.label
        }
        return nil
    }
    
    func finishCapture() {
        if doneButton.waitForExistence(timeout: 2) {
            doneButton.tap()
        }
    }
    
    func dismiss() {
        if dismissButton.waitForExistence(timeout: 2) {
            dismissButton.tap()
        }
    }
}
