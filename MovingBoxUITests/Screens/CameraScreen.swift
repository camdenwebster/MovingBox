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

    // Zoom controls
    var zoomButtons: [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[cd] 'x'")).allElementsBoundByIndex.filter { button in
            let label = button.label
            return label.contains("x") && (label.contains("0.5") || label.contains("1") || label.contains("2") || label.contains("5"))
        }
    }
    
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
        
        let startTime = Date()
        let checkInterval: TimeInterval = 1.0
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Check all elements without waiting
            if doneButton.exists || captureButton.exists || takePhotoButton.exists {
                return true
            }
            
            // Wait for the check interval before trying again
            Thread.sleep(forTimeInterval: checkInterval)
        }
        
        return false
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

    func tapZoomButton(at index: Int) -> Bool {
        let buttons = zoomButtons
        guard index >= 0 && index < buttons.count else {
            print("❌ Zoom button index \(index) out of range (0-\(buttons.count - 1))")
            return false
        }

        if buttons[index].waitForExistence(timeout: 2) {
            print("🔍 Tapping zoom button at index \(index): \(buttons[index].label)")
            buttons[index].tap()
            return true
        }

        print("❌ Zoom button at index \(index) not found")
        return false
    }

    func tapZoomByFactor(_ factor: String) -> Bool {
        let zoomButtonsArray = zoomButtons
        for (index, button) in zoomButtonsArray.enumerated() {
            if button.label.contains(factor) {
                print("🔍 Tapping \(factor) zoom button")
                button.tap()
                return true
            }
        }

        print("❌ Zoom button with factor \(factor) not found")
        return false
    }

    func getCurrentZoomFactor() -> String? {
        let zoomButtonsArray = zoomButtons
        for button in zoomButtonsArray {
            // Check if button is highlighted (selected state)
            if button.label.contains("x") {
                // Could check if it has yellow color or selected state
                return button.label
            }
        }
        return nil
    }

    func getAvailableZoomFactors() -> [String] {
        return zoomButtons.map { $0.label }
    }
}
