import XCTest

class CameraScreen {
    let app: XCUIApplication
    let testCase: XCTestCase
    
    // Camera controls (based on MultiPhotoCameraViewComponents identifiers)
    let captureButton: XCUIElement        // Shutter button (cameraShutterButton)
    let dismissButton: XCUIElement        // Close button (cameraCloseButton)
    let doneButton: XCUIElement          // Chevron/Continue button
    let retakeButton: XCUIElement        // Retake button in multi-item mode
    let photoCountLabel: XCUIElement     // Photo counter (cameraPhotoCount)
    let modePicker: XCUIElement          // Segmented control for Single/Multi mode
    
    // Multi-item preview overlay
    let previewRetakeButton: XCUIElement
    
    // Camera control buttons (no explicit identifiers, use accessibility labels)
    var flashButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Flash'")).firstMatch
    }
    
    var switchCameraButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Flip camera'")).firstMatch
    }
    
    var photoPickerButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Choose from library'")).firstMatch
    }

    // Zoom controls (use accessibility labels)
    var zoomButtons: [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'zoom'")).allElementsBoundByIndex
    }
    
    init(app: XCUIApplication, testCase: XCTestCase) {
        self.app = app
        self.testCase = testCase
        
        // Initialize camera controls based on actual accessibility identifiers
        self.captureButton = app.buttons["cameraShutterButton"]
        self.dismissButton = app.buttons["cameraCloseButton"]
        self.retakeButton = app.buttons["cameraRetakeButton"]
        self.photoCountLabel = app.staticTexts["cameraPhotoCount"]
        self.modePicker = app.segmentedControls["cameraModePicker"].firstMatch
        
        // Done button
        self.doneButton = app.buttons["continueToAnalysis"]
        
        // Multi-item preview overlay
        self.previewRetakeButton = app.buttons["multiItemRetakeButton"]
        
        // Set up interruption monitor for camera permissions
        addCameraPermissionsHandler()
    }
    
    // MARK: - Camera Permissions
    
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
    
    // MARK: - Wait Methods
    
    func waitForCamera(timeout: TimeInterval = 5) -> Bool {
        app.tap()
        
        let startTime = Date()
        let checkInterval: TimeInterval = 1.0
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Check for any camera UI element to verify camera is ready
            if captureButton.exists || dismissButton.exists || modePicker.exists {
                return true
            }
            
            Thread.sleep(forTimeInterval: checkInterval)
        }
        
        return false
    }
    
    func waitForPreviewOverlay(timeout: TimeInterval = 5) -> Bool {
        return previewRetakeButton.waitForExistence(timeout: timeout)
    }
    
    // MARK: - Photo Capture Methods
    
    func takePhoto(timeout: TimeInterval = 5) {
        guard waitForCamera(timeout: timeout) else {
            XCTFail("❌ Camera not ready")
            return
        }
        print("📸 Taking photo")
        
        if captureButton.waitForExistence(timeout: 2) {
            captureButton.tap()
        }
    }
    
    func finishCapture() {
        if doneButton.waitForExistence(timeout: 2) {
            print("✅ Tapping done/continue button")
            doneButton.tap()
        }
    }
    
    func retake() {
        if retakeButton.waitForExistence(timeout: 2) {
            print("🔄 Tapping retake button")
            retakeButton.tap()
        }
    }
    
    // MARK: - Mode Switching
    
    func switchToMode(_ mode: String) {
        guard modePicker.waitForExistence(timeout: 3) else {
            XCTFail("❌ Mode picker not found")
            return
        }
        
        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.waitForExistence(timeout: 2) {
            let modeButton = segmentedControl.buttons[mode]
            if modeButton.exists {
                print("🔄 Switching to \(mode) mode")
                modeButton.tap()
            }
        }
    }
    
    func switchToSingleMode() {
        switchToMode("Single")
    }
    
    func switchToMultiMode() {
        switchToMode("Multi")
    }
    
    // MARK: - Camera Controls
    
    func toggleFlash() {
        if flashButton.waitForExistence(timeout: 2) {
            print("⚡ Toggling flash")
            flashButton.tap()
        }
    }
    
    func switchCamera() {
        if switchCameraButton.waitForExistence(timeout: 2) {
            print("🔄 Switching camera")
            switchCameraButton.tap()
        }
    }
    
    func openPhotoLibrary() {
        if photoPickerButton.waitForExistence(timeout: 2) {
            print("📷 Opening photo library")
            photoPickerButton.tap()
        }
    }
    
    func dismiss() {
        if dismissButton.waitForExistence(timeout: 2) {
            print("❌ Dismissing camera")
            dismissButton.tap()
        }
    }
    
    // MARK: - Photo Counter
    
    func getPhotoCount() -> String? {
        if photoCountLabel.waitForExistence(timeout: 2) {
            return photoCountLabel.label
        }
        return nil
    }
    
    // MARK: - Zoom Controls
    
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
        for button in zoomButtonsArray {
            if button.label.contains(factor) {
                print("🔍 Tapping \(factor) zoom button")
                button.tap()
                return true
            }
        }

        print("❌ Zoom button with factor \(factor) not found")
        return false
    }

    func getAvailableZoomFactors() -> [String] {
        return zoomButtons.map { $0.label }
    }
    
    // MARK: - Multi-Item Preview
    
    func isPreviewOverlayVisible() -> Bool {
        return previewRetakeButton.exists
    }
    
    func tapPreviewRetake() {
        if previewRetakeButton.waitForExistence(timeout: 2) {
            print("🔄 Tapping preview retake button")
            previewRetakeButton.tap()
        }
    }
    
    // MARK: - Validation Helpers
    
    func isCameraReady() -> Bool {
        return captureButton.exists || modePicker.exists
    }
    
    func isMultiModeSelected() -> Bool {
        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.waitForExistence(timeout: 2) {
            let multiButton = segmentedControl.buttons["Multi"]
            return multiButton.exists && multiButton.isSelected
        }
        return false
    }
    
    func isSingleModeSelected() -> Bool {
        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.waitForExistence(timeout: 2) {
            let singleButton = segmentedControl.buttons["Single"]
            return singleButton.exists && singleButton.isSelected
        }
        return false
    }
}
