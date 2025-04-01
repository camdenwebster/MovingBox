//
//  InventoryItemUITests.swift
//  MovingBox
//
//  Created by Camden Webster on 3/31/25.
//

import XCTest

final class InventoryItemUITests: XCTestCase {
    var app: XCUIApplication!
    var listScreen: InventoryListScreen!
    var detailScreen: InventoryDetailScreen!
    var cameraScreen: CameraScreen!
    var photoReviewScreen: PhotoReviewScreen!
    var tabBar: TabBar!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        
        // Initialize screen objects
        listScreen = InventoryListScreen(app: app)
        detailScreen = InventoryDetailScreen(app: app)
        cameraScreen = CameraScreen(app: app)
        photoReviewScreen = PhotoReviewScreen(app: app)
        tabBar = TabBar(app: app)
        
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        listScreen = nil
        detailScreen = nil
        cameraScreen = nil
        photoReviewScreen = nil
        tabBar = nil
    }

    func testAddItemFromPhotoViaListView() throws {
        // Given: User is on the All Items tab
        tabBar.tapAllItems()
        
        // When: User initiates adding an item from photo
        listScreen.tapAddItem()
        listScreen.tapCreateFromCamera()
        
        // And: User takes a photo using the camera
        XCTAssertTrue(cameraScreen.captureButton.waitForExistence(timeout: 5),
                     "Camera capture button should be visible")
        cameraScreen.takePhoto()
        
        // And: User accepts the photo in review
        XCTAssertTrue(photoReviewScreen.usePhotoButton.waitForExistence(timeout: 5),
                     "Use photo button should be visible")
        photoReviewScreen.acceptPhoto()
        
        // Then: Detail view should appear after AI analysis completes
        XCTAssertTrue(detailScreen.titleField.waitForExistence(timeout: 10),
                     "Detail view should appear after AI analysis")
        
        // And: Fields should be populated with AI analysis results
        verifyPopulatedFields()
        
        // When: User saves the item
        detailScreen.saveButton.tap()
        
        // Then: Detail view should switch to read mode
        XCTAssertTrue(detailScreen.editButton.waitForExistence(timeout: 5),
                     "Edit button should appear after saving")
        
        // When: User navigates back
        app.navigationBars.buttons.firstMatch.tap()
        
        // Then: Camera view should reappear
        XCTAssertTrue(cameraScreen.captureButton.waitForExistence(timeout: 5),
                     "Camera view should reappear after navigating back")
    }

    func testAddItemManuallyViaListViewFromCameraRoll() throws {
        // Given: User is on the All Items tab
        tabBar.tapAllItems()
        
        // When: User initiates adding an item manually
        listScreen.tapAddItem()
        listScreen.tapCreateManually()
        
        // Then: Detail view should appear
        XCTAssertTrue(detailScreen.tapToAddPhotoButton.waitForExistence(timeout: 5),
                     "Detail view should appear with add photo button")
        
        // When: User adds a photo from the library
        detailScreen.addPhotoFromLibrary()
        
        // And: User initiates AI analysis
        let analyzeButton = detailScreen.analyzeWithAiButton
        XCTAssertTrue(analyzeButton.waitForExistence(timeout: 5),
                     "AI analysis button should be visible")
        analyzeButton.tap()
        
        // Then: Detail view should be updated after AI analysis completes
        XCTAssertTrue(detailScreen.sparklesButton.waitForExistence(timeout: 10),
                     "Detail view should be updated after AI analysis")
        
        // And: Fields should be populated with AI analysis results
        verifyPopulatedFields()
        
        // And the "Analyze with AI" button should be gone
        XCTAssertFalse(analyzeButton.exists)
        
        // When: User saves the item
        if detailScreen.saveButton.isEnabled {
            detailScreen.saveButton.tap()
        } else {
            XCTFail("Save button was not enabled after fields were populated")
        }
        
        // Then: Detail view should switch to read mode
        XCTAssertTrue(detailScreen.editButton.waitForExistence(timeout: 5),
                     "Edit button should appear after saving")
        
        // When: User navigates back
        app.navigationBars.buttons.firstMatch.tap()
        
        // Then: The inventory list should be displayed
        XCTAssertTrue(listScreen.addItemButton.waitForExistence(timeout: 5),
                     "Inventory list view should reappear after navigating back")
    }

    func testAddItemViaTabBar() throws {
        // Given: User is in the app
        
        // And: User taps the Add Item tab
        tabBar.tapAddItem()
        
        // And: User takes a photo using the camera
        XCTAssertTrue(cameraScreen.captureButton.waitForExistence(timeout: 5),
                     "Camera capture button should be visible")
        cameraScreen.takePhoto()
        
        // And: User accepts the photo in review
        XCTAssertTrue(photoReviewScreen.usePhotoButton.waitForExistence(timeout: 5),
                     "Use photo button should be visible")
        photoReviewScreen.acceptPhoto()
        
        // Then: Detail view should appear after AI analysis completes
        XCTAssertTrue(detailScreen.titleField.waitForExistence(timeout: 10),
                     "Detail view should appear after AI analysis")
        
        // And: Fields should be populated with AI analysis results
        verifyPopulatedFields()
        
        // When: User saves the item
        detailScreen.saveButton.tap()
        
        // Then: Detail view should switch to read mode
        XCTAssertTrue(detailScreen.editButton.waitForExistence(timeout: 5),
                     "Edit button should appear after saving")
        
        // When: User navigates back
        app.navigationBars.buttons.firstMatch.tap()
        
        // Then: Camera view should reappear
        XCTAssertTrue(cameraScreen.captureButton.waitForExistence(timeout: 5),
                     "Camera view should reappear after navigating back")
    }
    
    // MARK: - Helper Methods
    
    private func verifyPopulatedFields() {
        // Given: Fields are visible and populated
        
        // Then: Fields should contain non-empty values
        XCTAssertFalse(
            (detailScreen.titleField.value as? String)?.isEmpty ?? true,
            "Title field should not be empty"
        )
        XCTAssertFalse(
            (detailScreen.makeField.value as? String)?.isEmpty ?? true,
            "Make field should not be empty"
        )
        XCTAssertFalse(
            (detailScreen.modelField.value as? String)?.isEmpty ?? true,
            "Model field should not be empty"
        )
    }
}
