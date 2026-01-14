//
//  SyncDataScreen.swift
//  MovingBox
//
//  Created by Claude on 8/21/25.
//

import XCTest

class SyncDataScreen {
    let app: XCUIApplication

    // Sync and Data screen elements
    let deleteAllDataButton: XCUIElement

    init(app: XCUIApplication) {
        self.app = app

        // Sync and Data screen elements
        self.deleteAllDataButton = app.staticTexts["Delete All Data"]
    }

    // MARK: - Actions

    func tapDeleteAllData() {
        deleteAllDataButton.tap()
    }

    // MARK: - Verification

    func isDisplayed() -> Bool {
        return app.staticTexts["Sync and Data"].waitForExistence(timeout: 5)
            || deleteAllDataButton.waitForExistence(timeout: 5)
    }

    func waitForScreen() -> Bool {
        return isDisplayed()
    }
}
