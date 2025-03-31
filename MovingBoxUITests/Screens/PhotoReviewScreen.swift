import XCTest

class PhotoReviewScreen {
    let app: XCUIApplication
    
    // Review controls
    let usePhotoButton: XCUIElement
    let retakeButton: XCUIElement
    let cancelButton: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        
        // Initialize review controls
        self.usePhotoButton = app.buttons["usePhoto"]
        self.retakeButton = app.buttons["retakePhoto"]
        self.cancelButton = app.buttons["cancelPhotoReview"]
    }
    
    func acceptPhoto() {
        usePhotoButton.tap()
    }
    
    func retakePhoto() {
        retakeButton.tap()
    }
    
    func cancel() {
        cancelButton.tap()
    }
}