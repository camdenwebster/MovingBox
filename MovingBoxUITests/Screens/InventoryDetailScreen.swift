//
//  InventoryDetailScreen.swift
//  MovingBox
//
//  Created by Camden Webster on 3/31/25.
//

import Foundation
import XCTest

class InventoryDetailScreen {
    
    // Main app
    let app: XCUIApplication
    
    // Buttons
    let analyzeWithAiButton: XCUIElement
    let sparklesButton: XCUIElement
    let editButton: XCUIElement
    let saveButton: XCUIElement
    let changePhotoButton: XCUIElement
    let tapToAddPhotoButton: XCUIElement
    let addLabelButton: XCUIElement
    let addLocationButton: XCUIElement
    
    // Text Fields
    let titleField: XCUIElement
    let serialField: XCUIElement
    let makeField: XCUIElement
    let modelField: XCUIElement
    
    // Toggles
    let insuredToggle: XCUIElement
    
    // Pickers
    let locationPicker: XCUIElement
    let labelPicker: XCUIElement
    
    // Confirmation dialog buttons
    let takePhotoButton: XCUIElement
    let chooseFromLibraryButton: XCUIElement
    let removePhotoButton: XCUIElement
    let cancelButton: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        
        // Initialize buttons
        self.analyzeWithAiButton = app.buttons["analyzeWithAi"]
        self.sparklesButton = app.buttons["sparkles"]
        self.editButton = app.buttons["edit"]
        self.saveButton = app.buttons["save"]
        self.changePhotoButton = app.buttons["changePhoto"]
        self.tapToAddPhotoButton = app.buttons["detailview-add-first-photo-button"]
        self.addLabelButton = app.buttons["addNewLabel"]
        self.addLocationButton = app.buttons["addNewLocation"]
        
        // Initialize text fields
        self.titleField = app.textFields["titleField"]
        self.serialField = app.textFields["serialField"]
        self.makeField = app.textFields["makeField"]
        self.modelField = app.textFields["modelField"]
        
        // Initialize toggles
        self.insuredToggle = app.switches["insuredToggle"]
        
        // Initialize pickers
        self.locationPicker = app.pickers["locationPicker"]
        self.labelPicker = app.pickers["labelPicker"]
        
        // Initialize confirmation dialog buttons
        self.takePhotoButton = app.sheets.buttons["takePhoto"]
        self.chooseFromLibraryButton = app.sheets.buttons["chooseFromLibrary"]
        self.removePhotoButton = app.sheets.buttons["removePhoto"]
        self.cancelButton = app.sheets.buttons["cancel"]
    }
    
    func takePhotoWithCamera() {
        // Open the confirmation dialog to add a photo
        tapToAddPhotoButton.tap()
        
        // Handle the confirmation dialog to use camera or library
        takePhotoButton.tap()
    }
    
    func addPhotoFromLibrary() {
        // Open the confirmation dialog to add a photo
        tapToAddPhotoButton.tap()
        
        // Handle the confirmation dialog to use camera or library
        chooseFromLibraryButton.tap()
        
        // Handle photo library selection
        let photoLibrary = app.otherElements["photos_layout"]
        XCTAssertTrue(photoLibrary.waitForExistence(timeout: 20), "Photo library did not appear after 20 seconds")
        photoLibrary.images.firstMatch.tap()
    }
    
    func updatePhotoFromLibrary() {
        changePhotoButton.tap()
        chooseFromLibraryButton.tap()
            
        // Handle photo library selection
        let photosApp = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        let firstPhoto = photosApp.scrollViews.firstMatch.images.firstMatch
        firstPhoto.tap()
        
        // Tap the Choose/Done button to confirm selection
        photosApp.buttons["Choose"].tap()
    }
    
    func removePhoto() {
        changePhotoButton.tap()
        removePhotoButton.tap()
    }
    
    func tapAnalyzeWithAI() {
        analyzeWithAiButton.tap()
    }
    
    func tapSparkles() {
        sparklesButton.tap()
    }
}
