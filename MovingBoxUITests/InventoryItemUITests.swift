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
        app.launchEnvironment = [ "AIPROXY_DEVICE_CHECK_BYPASS": "f3543606-afa8-4394-99a9-74bd9a2421a2"]
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
        XCTAssertTrue(dashboardScreen.allInventoryButton.waitForExistence(timeout: 15), "App did not launch in time")
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
        XCTAssertTrue(detailScreen.titleField.waitForExistence(timeout: 20),
                     "Detail view should appear after AI analysis")
        
        // And: Fields should be populated with AI analysis results
        detailScreen.verifyPopulatedFields()
        
        // When: User saves the item
        detailScreen.saveButton.tap()
        
        // Then: Camera Add Flow sheet should be closed
        XCTAssertTrue(detailScreen.titleField.waitForNonExistence(timeout: 5),
                     "Camera should be ready after permissions")
    }

    func testAddItemManuallyViaListViewFromCameraRoll() throws {
        // Given: User navigates to the All Items view
        navigationHelper.navigateToAllItems()

        // When: User initiates adding an item manually
        listScreen.openToolbarMenu()
        listScreen.tapCreateManually()
        
        // Then: Detail view should appear
        XCTAssertTrue(detailScreen.tapToAddPhotoButton.waitForExistence(timeout: 5),
                     "Detail view should appear with add photo button")
        
        // When: User adds a photo from the library
        detailScreen.addPhotoFromLibrary()
        
        // And: User initiates AI analysis
        XCTAssertTrue(detailScreen.analyzeWithAiButton.waitForExistence(timeout: 5),
                     "AI analysis button should be visible")
        detailScreen.tapAnalyzeWithAI()
        
        // Then: Detail view should be updated after AI analysis completes
        detailScreen.waitForAIAnalysisToComplete()
        
        // And: Fields should be populated with AI analysis results
        detailScreen.verifyPopulatedFields()
        
        // When: User saves the item
        detailScreen.saveItem()
        
        // Then: The inventory list should be displayed
        XCTAssertTrue(listScreen.createFromCameraButton.waitForExistence(timeout: 5),
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
        detailScreen.verifyPopulatedFields()
        
        // When: User saves the item
        detailScreen.saveButton.tap()
        
        // Then: Camera Add Flow sheet should be closed
        XCTAssertTrue(detailScreen.titleField.waitForNonExistence(timeout: 5),
                     "Camera should be ready after permissions")
    }
}

