import XCTest

final class ImportExportUITests: XCTestCase {
    var dashboardScreen: DashboardScreen!
    var importExportScreen: ImportExportScreen!
    var navigationHelper: NavigationHelper!
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "Is-Pro",
            "Skip-Onboarding",
            "Disable-Persistence",
            "UI-Testing-Mock-Camera",
            "Use-Test-Data"
        ]
        
        // Initialize screen objects
        dashboardScreen = DashboardScreen(app: app)
        importExportScreen = ImportExportScreen(app: app)
        navigationHelper = NavigationHelper(app: app)
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        dashboardScreen = nil
        importExportScreen = nil
        navigationHelper = nil
    }
    
    func testImportExportFlow() throws {
        let app = XCUIApplication()
        app.activate()
        // Verify initial item count
        guard dashboardScreen.statCardLabel.waitForExistence(timeout: 10) else {
            XCTFail("Dashboard did not load before timeout")
            return
        }
        XCTAssertTrue(dashboardScreen.testDataLoaded(),
                     "Dashboard should show initial test data")
        
        // Navigate to Import/Export settings
        navigationHelper.navigateToSettings()
        app.buttons["importExportLink"].tap()
        
        // Export inventory
        importExportScreen.exportButton.tap()
        
        // Save to Files (simulated)
        let sharingUIServiceApp = XCUIApplication(bundleIdentifier: "com.apple.SharingUIService")
        sharingUIServiceApp.otherElements.element(boundBy: 27).tap()
        app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].tap()
        
        // Import the exported inventory
        importExportScreen.importButton.tap()
        app.cells.images.firstMatch.tap()
        
        // TODO: Re-try this test once this but is resolved: https://developer.apple.com/forums/thread/763549
        app.otherElements.matching(identifier: "Horizontal scroll bar, 1 page").element(boundBy: 1).tap()
        
        // Handle system file picker (simulated)
//        let filesApp = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
////        filesApp.files.firstMatch.tap()
        
        // Wait for import to complete
        XCTAssertTrue(importExportScreen.waitForImportCompletion(),
                     "Import success alert should appear")
        importExportScreen.dismissSuccessAlert()
        
        // Navigate back to dashboard
        app.navigationBars.buttons.firstMatch.tap() // Back to Settings
        app.navigationBars.buttons.firstMatch.tap() // Back to dashboard
        
        // Verify doubled item count
        XCTAssertEqual(dashboardScreen.statCardValue.label, "106",
                      "Inventory count should be doubled after import")
    }
}
