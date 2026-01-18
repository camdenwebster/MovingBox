//
//  LabelScreen.swift
//  MovingBoxUITests
//
//  Created by Claude Code on 1/17/26.
//

import XCTest

class LabelScreen {
    let app: XCUIApplication

    // Labels List Screen Elements
    let labelsList: XCUIElement
    let addLabelButton: XCUIElement
    let editButton: XCUIElement

    // Edit Label Screen Elements
    let labelNameField: XCUIElement
    let saveButton: XCUIElement
    let editSaveButton: XCUIElement

    init(app: XCUIApplication) {
        self.app = app

        // Labels List Screen
        self.labelsList = app.collectionViews["labels-list"]
        self.addLabelButton = app.buttons["labels-add-button"]
        self.editButton = app.buttons["labels-edit-button"]

        // Edit Label Screen
        self.labelNameField = app.textFields["label-name-field"]
        self.saveButton = app.buttons["label-save-button"]
        self.editSaveButton = app.buttons["label-edit-save-button"]
    }

    // MARK: - Navigation Actions

    func tapAddLabel() {
        addLabelButton.tap()
    }

    func tapEdit() {
        editButton.tap()
    }

    func selectLabel(named name: String) {
        app.buttons["label-row-\(name)"].tap()
    }

    // MARK: - Edit Label Actions

    func enterLabelName(_ name: String) {
        labelNameField.tap()
        labelNameField.typeText(name)
    }

    func clearAndEnterLabelName(_ name: String) {
        labelNameField.tap()
        // Select all and delete
        labelNameField.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
            app.keys["delete"].tap()
        }
        labelNameField.typeText(name)
    }

    func tapSave() {
        saveButton.tap()
    }

    func tapEditSave() {
        editSaveButton.tap()
    }

    func createLabel(name: String) {
        tapAddLabel()
        XCTAssertTrue(waitForEditLabelScreen(), "Edit label screen should be displayed")
        enterLabelName(name)
        tapSave()
    }

    // MARK: - Delete Actions

    func deleteLabel(named name: String) {
        // Enter edit mode
        tapEdit()
        // Find the delete button for this label
        let labelRow = app.buttons["label-row-\(name)"]
        // Swipe to reveal delete
        labelRow.swipeLeft()
        // Tap delete button
        app.buttons["Delete"].tap()
    }

    func swipeToDeleteLabel(named name: String) {
        let labelRow = app.buttons["label-row-\(name)"]
        labelRow.swipeLeft()
        app.buttons["Delete"].tap()
    }

    // MARK: - Verification Methods

    func isLabelsListDisplayed() -> Bool {
        return app.navigationBars["Labels"].waitForExistence(timeout: 5)
    }

    func waitForLabelsList() -> Bool {
        return isLabelsListDisplayed()
    }

    func isEditLabelScreenDisplayed() -> Bool {
        return app.navigationBars["New Label"].waitForExistence(timeout: 5)
            || labelNameField.waitForExistence(timeout: 5)
    }

    func waitForEditLabelScreen() -> Bool {
        return isEditLabelScreenDisplayed()
    }

    func labelExists(named name: String) -> Bool {
        return app.buttons["label-row-\(name)"].exists
            || app.staticTexts[name].exists
    }

    func waitForLabelToExist(named name: String, timeout: TimeInterval = 5) -> Bool {
        let labelRow = app.buttons["label-row-\(name)"]
        let staticText = app.staticTexts[name]
        return labelRow.waitForExistence(timeout: timeout) || staticText.waitForExistence(timeout: timeout)
    }

    func waitForLabelToDisappear(named name: String, timeout: TimeInterval = 5) -> Bool {
        let labelRow = app.buttons["label-row-\(name)"]
        // Wait for the element to no longer exist
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if !labelRow.exists {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return !labelRow.exists
    }

    func isSaveButtonEnabled() -> Bool {
        return saveButton.isEnabled
    }

    func getLabelCount() -> Int {
        return app.cells.count
    }

    func getLabelNames() -> [String] {
        var names: [String] = []
        let cells = app.cells.allElementsBoundByIndex
        for cell in cells {
            let labels = cell.staticTexts.allElementsBoundByIndex
            // Skip the emoji, get the name (usually second static text)
            if labels.count > 1 {
                names.append(labels[1].label)
            } else if let firstLabel = labels.first {
                names.append(firstLabel.label)
            }
        }
        return names
    }
}
