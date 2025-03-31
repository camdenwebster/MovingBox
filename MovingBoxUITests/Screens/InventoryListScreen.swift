//
//  InventoryListScreen.swift
//  MovingBox
//
//  Created by Camden Webster on 3/31/25.
//

import Foundation
import XCTest

class InventoryListScreen {
    
    // Main app
    let app: XCUIApplication
    
    // Buttons
    let addItemButton: XCUIElement
    let createManuallyButton: XCUIElement
    let createFromCameraButton: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        self.addItemButton = app.buttons["addItem"]
        self.createManuallyButton = app.buttons["createManually"]
        self.createFromCameraButton = app.buttons["createFromCamera"]
    }
    
    func tapAddItem() {
        addItemButton.tap()
    }
    
    func tapCreateManually() {
        createManuallyButton.tap()
    }
    
    func tapCreateFromCamera() {
        createFromCameraButton.tap()
    }
}
