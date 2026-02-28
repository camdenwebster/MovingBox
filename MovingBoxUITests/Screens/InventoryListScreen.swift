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

    // Navigation
    let allItemsNavigationTitle: XCUIElement

    // Buttons
    let createManuallyButton: XCUIElement
    let createFromCameraButton: XCUIElement

    // Menu
    let toolbarMenu: XCUIElement

    // Alert elements
    let limitAlert: XCUIElement
    let upgradeButton: XCUIElement
    let cancelButton: XCUIElement

    // Selection mode elements
    let optionsButton: XCUIElement
    let selectItemsButton: XCUIElement
    let selectionDoneButton: XCUIElement
    let actionsButton: XCUIElement
    let deleteSelectedButton: XCUIElement
    let deleteConfirmationAlert: XCUIElement
    let deleteButton: XCUIElement
    let alertCancelButton: XCUIElement

    init(app: XCUIApplication) {
        self.app = app

        // Initialize navigation
        self.allItemsNavigationTitle = app.navigationBars.staticTexts["All Items"]

        // Initialize buttons
        self.createManuallyButton = app.buttons["createManually"]
        self.createFromCameraButton = app.buttons["createFromCamera"]

        // Initialize menu
        self.toolbarMenu = app.buttons["toolbarMenu"]

        // Initialize alert elements
        self.limitAlert = app.alerts["Upgrade to Pro"]
        self.upgradeButton = limitAlert.buttons["Upgrade"]
        self.cancelButton = limitAlert.buttons["Cancel"]

        // Initialize selection mode elements
        self.optionsButton = app.buttons["Options"]
        self.selectItemsButton = app.buttons["Select Items"]
        self.selectionDoneButton = app.buttons["Done"]
        self.actionsButton = app.buttons["Actions"]
        self.deleteSelectedButton = app.buttons["deleteSelected"]
        self.deleteConfirmationAlert = app.alerts["Delete Items"]
        self.deleteButton = self.deleteConfirmationAlert.buttons.matching(identifier: "alertDelete").firstMatch
        self.alertCancelButton = self.deleteConfirmationAlert.buttons["Cancel"]
    }

    func tapAddItem() {
        createFromCameraButton.tap()
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

    func waitForToolbarMenu() -> Bool {
        toolbarMenu.waitForExistence(timeout: 5)
    }

    func openToolbarMenu() {
        toolbarMenu.tap()
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
        selectionDoneButton.tap()
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
        deleteSelectedButton.tap()
        // Alert appears after this - confirmDeletion() will tap the alert button
    }

    func confirmDeletion() {
        XCTAssertTrue(
            deleteButton.waitForExistence(timeout: 5),
            "Delete confirmation button should be visible"
        )
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

    func waitForItemCount(_ expectedCount: Int, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if getItemCount() == expectedCount {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return getItemCount() == expectedCount
    }

    func isItem(named itemName: String, at index: Int) -> Bool {
        let cell = app.cells.element(boundBy: index)
        guard cell.exists else { return false }
        return cell.staticTexts[itemName].exists
    }

    func waitForItem(named itemName: String, at index: Int, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isItem(named: itemName, at: index) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return isItem(named: itemName, at: index)
    }

    func waitForItemsToLoad() -> Bool {
        app.cells.firstMatch.waitForExistence(timeout: 10)
    }

    func isSelectionModeActive() -> Bool {
        return selectionDoneButton.exists
    }

    func isDisplayed() -> Bool {
        return allItemsNavigationTitle.waitForExistence(timeout: 10)
            || app.navigationBars["All Items"].waitForExistence(timeout: 10)
            || app.cells.firstMatch.waitForExistence(timeout: 10)
    }

    func hasItems() -> Bool {
        return app.cells.count > 0
    }
}
