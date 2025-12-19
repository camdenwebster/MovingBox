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
    var settingsScreen: SettingsScreen!
    var multiItemSelectionScreen: MultiItemSelectionScreen!
    
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
        settingsScreen = SettingsScreen(app: app)
        multiItemSelectionScreen = MultiItemSelectionScreen(app: app)
        
        navigationHelper = NavigationHelper(app: app)
        
        setupSnapshot(app)
        
        app.launchArguments.append("Use-Test-Data")
        app.launch()
        XCTAssertTrue(dashboardScreen.testDataLoaded())
    }
    
    override func tearDownWithError() throws {
        dashboardScreen = nil
        listScreen = nil
        detailScreen = nil
        cameraScreen = nil
        settingsScreen = nil
        multiItemSelectionScreen = nil
        navigationHelper = nil
    }
    
    func testDashboardSnapshot() throws {
        // Given MovingBox has data in the inventory
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
        
        snapshot("01_InventoryItemBeforeAnalysis")
        
        // And: user fills in fields
        detailScreen.fillInFields()
        
        // Then: Detail view should be updated after AI analysis completes
        detailScreen.saveItem()
        snapshot("01_InventoryItemAfterAnalysis")
    }
    
    func testSyncAndDataScreen() throws {
        dashboardScreen.tapSettings()
        settingsScreen.tapSyncAndData()
        snapshot("01_SyncAndDataSettings")
    }
    
    func testMultiItemSelectionSnapshot() throws {
        // Given: User is on dashboard with Pro access
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
        
        // When: User taps Add Item button to open camera
        dashboardScreen.addItemFromCameraButton.tap()
        
        guard cameraScreen.waitForCamera(timeout: 5) else {
            XCTFail("Camera should open")
            return
        }
        
        // And: User switches to Multi mode via segmented control
        let modePicker = app.segmentedControls.firstMatch
        if modePicker.waitForExistence(timeout: 5) {
            let multiButton = modePicker.buttons["Multi"]
            if multiButton.exists {
                multiButton.tap()
            }
        }
        
        // And: User captures a photo
        cameraScreen.captureButton.tap()
        
        // And: User taps chevron to continue to analysis
        let previewOverlay = app.otherElements["multiItemPreviewOverlay"]
        if previewOverlay.waitForExistence(timeout: 5) {
            cameraScreen.doneButton.tap()
        }
        
        // And: Analysis completes
        guard multiItemSelectionScreen.waitForAnalysisToComplete(timeout: 15) else {
            XCTFail("Analysis should complete and show selection view")
            return
        }
        
        // And: User selects some items (select first 2 if available)
        let itemCount = multiItemSelectionScreen.getItemCardCount()
        if itemCount > 0 {
            multiItemSelectionScreen.tapItemCard(at: 0)
        }
        if itemCount > 1 {
            multiItemSelectionScreen.scrollToItemCard(at: 1)
            multiItemSelectionScreen.tapItemCard(at: 1)
        }
        
        // Wait a moment for selection animation to complete
        sleep(1)
        
        // Then: Take snapshot of multi-item selection view
        snapshot("02_MultiItemSelection")
    }

}

