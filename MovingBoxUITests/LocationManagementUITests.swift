//
//  LocationManagementUITests.swift
//  MovingBoxUITests
//
//  Created by Claude on 1/29/26.
//

import XCTest

final class LocationManagementUITests: XCTestCase {
    var app: XCUIApplication!
    var dashboardScreen: DashboardScreen!
    var locationScreen: LocationScreen!
    var navigationHelper: NavigationHelper!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        dashboardScreen = DashboardScreen(app: app)
        locationScreen = LocationScreen(app: app)
        navigationHelper = NavigationHelper(app: app)

        app.launchArguments = [
            "Use-Test-Data", "Disable-Animations", "Skip-Onboarding", "Disable-Persistence",
        ]
        app.launch()

        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard should be visible")
    }

    override func tearDownWithError() throws {
        app = nil
        dashboardScreen = nil
        locationScreen = nil
        navigationHelper = nil
    }

    // MARK: - Location Creation Tests

    func testCreateNewLocationWithSymbol() throws {
        // Given: Navigate to Locations from dashboard
        dashboardScreen.tapLocations()
        XCTAssertTrue(
            locationScreen.waitForLocationsList(), "Locations list should be displayed")

        // When: Create a new location with a symbol
        let locationName = "Test Room \(UUID().uuidString.prefix(8))"
        locationScreen.createLocation(name: locationName, symbol: "sofa.fill")

        // Then: Should return to locations list and the new location should exist
        XCTAssertTrue(
            locationScreen.waitForLocationsList(),
            "Should return to locations list after creating location")
        XCTAssertTrue(
            locationScreen.waitForLocationToExist(named: locationName, timeout: 5),
            "New location '\(locationName)' should appear in the locations list")
    }
}
