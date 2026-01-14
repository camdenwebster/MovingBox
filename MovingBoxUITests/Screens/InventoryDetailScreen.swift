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

    // Text
    let photoCountText: XCUIElement

    // Buttons
    let analyzeWithAiButton: XCUIElement
    let sparklesButton: XCUIElement
    let editButton: XCUIElement
    let saveButton: XCUIElement
    let changePhotoButton: XCUIElement
    let tapToAddPhotoButton: XCUIElement
    let addPhotoThumbnailButton: XCUIElement
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
    let scanDocumentButton: XCUIElement
    let removePhotoButton: XCUIElement
    let cancelButton: XCUIElement

    init(app: XCUIApplication) {
        self.app = app

        // Initialize UI Text
        self.photoCountText = app.staticTexts["photoCountText"]

        // Initialize buttons
        self.analyzeWithAiButton = app.buttons["analyzeWithAi"]
        self.sparklesButton = app.buttons["sparkles"]
        self.editButton = app.buttons["edit"]
        self.saveButton = app.buttons["save"]
        self.changePhotoButton = app.buttons["changePhoto"]
        self.tapToAddPhotoButton = app.buttons["detailview-add-first-photo-button"]
        self.addPhotoThumbnailButton = app.buttons["add-photo-button"]
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
        self.takePhotoButton = app.sheets.buttons["takePhoto"].firstMatch
        self.chooseFromLibraryButton = app.sheets.buttons["chooseFromLibrary"].firstMatch
        self.scanDocumentButton = app.sheets.buttons["scanDocument"].firstMatch
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
        let photosApp = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow.photospicker")
        photosApp.activate()
        let firstPhoto = photosApp.scrollViews.firstMatch.images.firstMatch
        firstPhoto.tap()

        // Tap the Choose/Done button to confirm selection
        photosApp.buttons["Choose"].tap()
    }

    func saveItem() {
        guard saveButton.isEnabled else {
            return XCTFail("Save button was not enabled after fields were populated")
        }
        saveButton.tap()
    }

    func enterEditMode() {
        guard editButton.waitForExistence(timeout: 5) else {
            return XCTFail("Edit button was not hittable")
        }
        editButton.tap()
    }

    func fillInFields() {
        titleField.tap()
        titleField.typeText("iPad")
        serialField.tap()
        serialField.typeText("SN123456789")
        makeField.tap()
        makeField.typeText("Apple")
        modelField.tap()
        modelField.typeText("iPad (6th generation)")

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

    func waitForAIAnalysisToComplete(timeout: TimeInterval = 30.0) {
        // Wait for the progress view to appear (AI analysis started)
        let progressViewAppeared = analyzeWithAiButton.staticTexts["Analyze with AI"]
            .waitForNonExistence(timeout: 5.0)
        XCTAssertTrue(
            progressViewAppeared, "AI analysis should have started (progress view should appear)")

        // Wait for the progress view to disappear and "Analyze with AI" text to return (AI analysis completed)
        let analysisCompleted = analyzeWithAiButton.staticTexts["Analyze with AI"].waitForExistence(
            timeout: timeout)
        XCTAssertTrue(analysisCompleted, "AI analysis should complete within \(timeout) seconds")
    }

    func verifyPopulatedFields() {
        // Then: Fields should contain non-empty values
        XCTAssertFalse(
            (titleField.value as? String)?.isEmpty ?? true,
            "Title field should not be empty"
        )
        XCTAssertFalse(
            (makeField.value as? String)?.isEmpty ?? true,
            "Make field should not be empty"
        )
        XCTAssertFalse(
            (modelField.value as? String)?.isEmpty ?? true,
            "Model field should not be empty"
        )
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

    // MARK: - Photo Button Visibility Helpers

    func isAddFirstPhotoButtonVisible() -> Bool {
        return tapToAddPhotoButton.exists
    }

    func isAddAdditionalPhotoButtonVisible() -> Bool {
        return addPhotoThumbnailButton.exists
    }

    func waitForAddFirstPhotoButton(timeout: TimeInterval = 5) -> Bool {
        return tapToAddPhotoButton.waitForExistence(timeout: timeout)
    }

    func waitForAddAdditionalPhotoButton(timeout: TimeInterval = 5) -> Bool {
        return addPhotoThumbnailButton.waitForExistence(timeout: timeout)
    }

}
