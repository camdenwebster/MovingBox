//
//  DashboardUITests.swift
//  MovingBox
//
//  Created by Camden Webster on 4/19/25.
//

import XCTest

@MainActor
final class DashboardUITests: XCTestCase {
    var listScreen: InventoryListScreen!
    var detailScreen: InventoryDetailScreen!
    var cameraScreen: CameraScreen!
    var tabBar: TabBar!
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
        listScreen = InventoryListScreen(app: app)
        detailScreen = InventoryDetailScreen(app: app)
        cameraScreen = CameraScreen(app: app, testCase: self)
        tabBar = TabBar(app: app)
        
        setupSnapshot(app)
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        listScreen = nil
        detailScreen = nil
        cameraScreen = nil
        tabBar = nil
    }
    
    func testDashboardElementsExistWithTestData() throws {
        // Given MovingBox has data in the inventory
        app.launchArguments.append("Use-Test-Data")
        // When the user launches the app
        // Then the dashboard should display the correct elements with the data
        sleep(5)
        snapshot("01_Dashboard")
    }
}
