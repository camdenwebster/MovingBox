//
//  InventoryItemUITests.swift
//  MovingBox
//
//  Created by Camden Webster on 3/31/25.
//

import XCTest

@MainActor
final class InventoryItemUITests: XCTestCase {
    var listScreen: InventoryListScreen!
    var detailScreen: InventoryDetailScreen!
    var cameraScreen: CameraScreen!
    var dashboardScreen: DashboardScreen!
    var navigationHelper: NavigationHelper!
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "Is-Pro",
            "Skip-Onboarding",
            "Disable-Persistence",
            "UI-Testing-Mock-Camera",
            "Use-Test-Data"  // Added to populate inventory for testing
        ]
        
        // Initialize screen objects
        listScreen = InventoryListScreen(app: app)
        detailScreen = InventoryDetailScreen(app: app)
        cameraScreen = CameraScreen(app: app, testCase: self)
        dashboardScreen = DashboardScreen(app: app)
        navigationHelper = NavigationHelper(app: app)
        
        setupSnapshot(app)
        
        app.launch()
    }

    override func tearDownWithError() throws {
        listScreen = nil
        detailScreen = nil
        cameraScreen = nil
        dashboardScreen = nil
        navigationHelper = nil
    }

    func testAddItemFromPhotoViaListView() throws {
        // Given: User navigates to the All Items view
        navigationHelper.navigateToAllItems()
        
        // When: User initiates adding an item from photo
        listScreen.tapAddItem()
        listScreen.tapCreateFromCamera()
        
        // Then: Camera should be ready
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera should be ready after permissions")
        
        // When: User takes a photo
        cameraScreen.takePhoto()
        
        // Then: Detail view should appear after AI analysis completes
        XCTAssertTrue(detailScreen.titleField.waitForExistence(timeout: 10),
                     "Detail view should appear after AI analysis")
        
        // And: Fields should be populated with AI analysis results
        verifyPopulatedFields()
        
        // When: User saves the item
        detailScreen.saveButton.tap()
        
        // Then: Camera should be ready for the next photo
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera should be ready after permissions")
    }

    func testAddItemManuallyViaListViewFromCameraRoll() throws {
        // Given: User navigates to the All Items view
        navigationHelper.navigateToAllItems()

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
        
        // Then: The inventory list should be displayed
        XCTAssertTrue(listScreen.addItemButton.waitForExistence(timeout: 5),
                     "Inventory list view should reappear after navigating back")
    }

    func testAddItemViaDashboard() throws {
        // Given: User is on the dashboard
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
        
        // When: User taps the add item button from dashboard
        dashboardScreen.tapAddItemFromCamera()
        
        // Then: Camera should be ready
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera should be ready after permissions")
        
        // When: User takes a photo
        cameraScreen.takePhoto()
        
        // Then: Detail view should appear after AI analysis completes
        XCTAssertTrue(detailScreen.titleField.waitForExistence(timeout: 10),
                     "Detail view should appear after AI analysis")
        
        // And: Fields should be populated with AI analysis results
        verifyPopulatedFields()
        
        // When: User saves the item
        detailScreen.saveButton.tap()
        
        // Then: Camera view should reappear and be ready
        XCTAssertTrue(cameraScreen.waitForCamera(),
                     "Camera view should reappear and be ready after navigating back")
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
