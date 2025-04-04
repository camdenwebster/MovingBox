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
    
    // Menu
    let addItemMenu: XCUIElement
    
    // Alert elements
    let limitAlert: XCUIElement
    let upgradeButton: XCUIElement
    let cancelButton: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        
        // Initialize buttons
        self.addItemButton = app.buttons["addItem"]
        self.createManuallyButton = app.buttons["createManually"]
        self.createFromCameraButton = app.buttons["createFromCamera"]
        
        // Initialize menu
        self.addItemMenu = app.menus["Add Item"]
        
        // Initialize alert elements
        self.limitAlert = app.alerts["Upgrade to Pro"]
        self.upgradeButton = limitAlert.buttons["Upgrade"]
        self.cancelButton = limitAlert.buttons["Cancel"]
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
    
    func waitForLimitAlert() -> Bool {
        limitAlert.waitForExistence(timeout: 5)
    }
    
    func tapUpgradeInAlert() {
        upgradeButton.tap()
    }
    
    func tapCancelInAlert() {
        cancelButton.tap()
    }
    
    func waitForAddItemMenu() -> Bool {
        addItemMenu.waitForExistence(timeout: 5)
    }
    
    func tapFirstItem() {
        app.cells.firstMatch.tap()
    }
}
