//
//  FastlaneSnapshots.swift
//  MovingBox
//
//  Created by Camden Webster on 4/19/25.
//

import XCTest

@MainActor
final class FastlaneSnapshots: XCTestCase {
    var dashboardScreen: DashboardScreen!
    var listScreen: InventoryListScreen!
    var detailScreen: InventoryDetailScreen!
    var cameraScreen: CameraScreen!
    var navigationHelper: NavigationHelper!
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "Is-Pro",
            "Skip-Onboarding",
            "Disable-Persistence",
            "UI-Testing-Mock-Camera"
        ]
        
        // Initialize screen objects
        dashboardScreen = DashboardScreen(app: app)
        listScreen = InventoryListScreen(app: app)
        detailScreen = InventoryDetailScreen(app: app)
        cameraScreen = CameraScreen(app: app, testCase: self)
        navigationHelper = NavigationHelper(app: app)
        
        setupSnapshot(app)
        
        app.launchArguments.append("Use-Test-Data")
        app.launch()
        XCTAssertTrue(dashboardScreen.testDataLoaded())
    }
    
    override func tearDownWithError() throws {
        listScreen = nil
        detailScreen = nil
        cameraScreen = nil
    }
    
    func testDashboardSnapshot() throws {
        // Given MovingBox has data in the inventory
        app.launchArguments.append("Use-Test-Data")
        app.launch()
        
        // When the user launches the app
        // Then the dashboard should display the correct elements with the data
        snapshot("01_Dashboard")
    }
    
    func testLocationsSnapshot() throws {
        // Given MovingBox has data in the inventory
        // And the app is launched
        // And the test data is loaded
        // When the user taps the "Locations" link on the dashboard
        dashboardScreen.tapLocations()
        // Then the user should be brought to the Locations list view
        snapshot("01_Locations")
    }
    
    func testItemListViewSnapshot() throws {
        // Given MovingBox has data in the inventory
        // And the app is launched
        // And the test data is loaded
        // When the user navigates to the Inventory List
        navigationHelper.navigateToAllItems()
        // Then the dashboard should display the correct elements with the data
        snapshot("01_InventoryItemList")
    }
    
    func testItemDetailViewSnapshots() throws {
        // Given MovingBox has data in the inventory
        // And the app is launched
        // And the test data is loaded
        // And the user is on the main inventory list
        navigationHelper.navigateToAllItems()
        
        // When: User initiates adding an item manually
        listScreen.openToolbarMenu()
        listScreen.tapCreateManually()
        
        // When: User adds a photo from the camera
        guard detailScreen.tapToAddPhotoButton.waitForExistence(timeout: 5) else {
            XCTFail("Detail screen was not displayed in time")
            return
        }
        
        detailScreen.takePhotoWithCamera()
        cameraScreen.takePhoto()
        
        // And: User initiates AI analysis
        let analyzeButton = detailScreen.analyzeWithAiButton
        XCTAssertTrue(analyzeButton.waitForExistence(timeout: 5),
                      "AI analysis button should be visible")
        snapshot("01_InventoryItemBeforeAnalysis")
        analyzeButton.tap()
        
        // Then: Detail view should be updated after AI analysis completes
        XCTAssertTrue(detailScreen.sparklesButton.waitForExistence(timeout: 10),
                      "Detail view should be updated after AI analysis")
        snapshot("01_InventoryItemAfterAnalysis")
    }
}
