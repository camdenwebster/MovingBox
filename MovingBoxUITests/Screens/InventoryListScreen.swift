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
    
    // Selection mode elements
    let optionsButton: XCUIElement
    let selectItemsButton: XCUIElement
    let cancelSelectionButton: XCUIElement
    let actionsButton: XCUIElement
    let deleteSelectedButton: XCUIElement
    let deleteConfirmationAlert: XCUIElement
    let deleteButton: XCUIElement
    let alertCancelButton: XCUIElement
    
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
        
        // Initialize selection mode elements
        self.optionsButton = app.buttons["Options"]
        self.selectItemsButton = app.buttons["Select Items"]
        self.cancelSelectionButton = app.buttons["Cancel"]
        self.actionsButton = app.buttons["Actions"]
        self.deleteSelectedButton = app.buttons.matching(identifier: "Delete Selected").firstMatch
        self.deleteConfirmationAlert = app.alerts["Delete Items"]
        self.deleteButton = app.buttons["Delete"]
        self.alertCancelButton = app.buttons["Cancel"]
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
    
    // MARK: - Selection Mode Methods
    func enterSelectionMode() {
        optionsButton.tap()
        selectItemsButton.tap()
    }
    
    func exitSelectionMode() {
        cancelSelectionButton.tap()
    }
    
    func selectItem(at index: Int) {
        let items = app.cells
        if index < items.count {
            items.element(boundBy: index).tap()
        }
    }
    
    func selectMultipleItems(indices: [Int]) {
        for index in indices {
            selectItem(at: index)
        }
    }
    
    func deleteSelectedItems() {
        actionsButton.tap()
        deleteSelectedButton.tap()
    }
    
    func confirmDeletion() {
        deleteButton.tap()
    }
    
    func cancelDeletion() {
        alertCancelButton.tap()
    }
    
    func waitForDeleteConfirmationAlert() -> Bool {
        deleteConfirmationAlert.waitForExistence(timeout: 5)
    }
    
    func getItemCount() -> Int {
        return app.cells.count
    }
    
    func waitForItemsToLoad() -> Bool {
        app.cells.firstMatch.waitForExistence(timeout: 10)
    }
    
    func isSelectionModeActive() -> Bool {
        return cancelSelectionButton.exists
    }
}
