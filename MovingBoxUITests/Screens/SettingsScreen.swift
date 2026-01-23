//
//  SettingsScreen.swift
//  MovingBox
//
//  Created by Camden Webster on 4/22/25.
//

import XCTest

class SettingsScreen {
    let app: XCUIApplication

    // Common settings elements
    let aboutButton: XCUIElement
    let privacyPolicyButton: XCUIElement
    let termsOfServiceButton: XCUIElement
    let exportDataButton: XCUIElement
    let deleteAllDataButton: XCUIElement
    let subscriptionButton: XCUIElement
    let syncAndDataButton: XCUIElement
    let manageHomesButton: XCUIElement
    let labelsButton: XCUIElement
    let insurancePoliciesButton: XCUIElement

    init(app: XCUIApplication) {
        self.app = app

        // Settings screen elements
        self.aboutButton = app.buttons["settings-about-button"]
        self.privacyPolicyButton = app.buttons["settings-privacy-policy-button"]
        self.termsOfServiceButton = app.buttons["settings-terms-button"]
        self.exportDataButton = app.buttons["settings-export-data-button"]
        self.deleteAllDataButton = app.buttons["settings-delete-all-data-button"]
        self.subscriptionButton = app.buttons["settings-subscription-button"]
        self.syncAndDataButton = app.buttons["syncDataLink"]
        self.manageHomesButton = app.buttons["Manage Homes"]
        self.labelsButton = app.buttons["settings-labels-button"]
        self.insurancePoliciesButton = app.buttons["settings-insurance-button"]
    }

    // MARK: - Actions

    func tapAbout() {
        aboutButton.tap()
    }

    func tapPrivacyPolicy() {
        privacyPolicyButton.tap()
    }

    func tapTermsOfService() {
        termsOfServiceButton.tap()
    }

    func tapExportData() {
        exportDataButton.tap()
    }

    func tapDeleteAllData() {
        deleteAllDataButton.tap()
    }

    func tapSubscription() {
        subscriptionButton.tap()
    }

    func tapSyncAndData() {
        syncAndDataButton.tap()
    }

    func tapManageHomes() {
        manageHomesButton.tap()
    }

    func tapLabels() {
        labelsButton.tap()
    }

    func tapInsurancePolicies() {
        insurancePoliciesButton.tap()
    }

    // MARK: - Verification

    func isDisplayed() -> Bool {
        return app.navigationBars["Settings"].exists || app.staticTexts["Settings"].exists
            || aboutButton.waitForExistence(timeout: 5)
    }

    func waitForSettingsScreen() -> Bool {
        return isDisplayed()
    }
}
