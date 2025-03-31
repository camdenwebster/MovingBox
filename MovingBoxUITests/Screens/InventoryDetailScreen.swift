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
    
    // Text Fields
    let titleField: XCUIElement
    let serialField: XCUIElement
    let makeField: XCUIElement
    let modelField: XCUIElement
    
    // Toggles
    
    // Steppers
    
    init(app: XCUIApplication) {
        self.app = app
        
        // Initialize buttons
        self.analyzeWithAiButton = app.buttons["analyzeWithAi"]
        self.sparklesButton = app.buttons["sparkles"]
        self.editButton = app.buttons["edit"]
        self.saveButton = app.buttons["save"]
        self.changePhotoButton = app.buttons["changePhoto"]
        self.tapToAddPhotoButton = app.buttons["tapToAddPhoto"]
        
        // Initialize text fields
        self.titleField = app.textFields["titleField"]
        self.serialField = app.textFields["serialField"]
        self.makeField = app.textFields["makeField"]
        self.modelField = app.textFields["modelField"]
    }
    
    func addPhoto(photoExists: Bool, useCamera: Bool) {
        let button = photoExists ? changePhotoButton : tapToAddPhotoButton
        button.tap()
        
        if useCamera {
            app.sheets.buttons["Take Photo"].tap()
        } else {
            app.sheets.buttons["Choose from Library"].tap()
        }
    }
}
