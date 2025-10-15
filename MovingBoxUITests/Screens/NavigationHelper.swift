//
//  NavigationHelper.swift
//  MovingBox
//
//  Created by Claude on 8/20/25.
//

import Foundation
import XCTest

/// Navigation helper for the new button-based navigation system
/// Replaces TabBar navigation with Dashboard-centric navigation
class NavigationHelper {
    let app: XCUIApplication
    let dashboardScreen: DashboardScreen
    
    init(app: XCUIApplication) {
        self.app = app
        self.dashboardScreen = DashboardScreen(app: app)
    }
    
    // MARK: - Core Navigation Methods
    
    /// Ensure app is launched with expected launch arguments
    func launchWithArguments(_ launchArguments: [String]) {
        app.launchArguments = launchArguments
        app.launch()
        guard dashboardScreen.isDisplayed() else {
            return XCTFail("Dashboard not loaded")
        }
    }
    
    /// Navigate to All Items view from dashboard
    func navigateToAllItems() {
        // If we're already on dashboard, use the button
        if dashboardScreen.allInventoryButton.exists {
            dashboardScreen.tapAllInventory()
        } else {
            // Navigate back to dashboard first, then to all items
            navigateBackToDashboard()
            dashboardScreen.tapAllInventory()
        }
    }
    
    /// Navigate to Settings from dashboard
    func navigateToSettings() {
        // If we're already on dashboard, use the button
        if dashboardScreen.settingsButton.exists {
            dashboardScreen.tapSettings()
        } else {
            // Navigate back to dashboard first, then to settings
            navigateBackToDashboard()
            dashboardScreen.tapSettings()
        }
    }
    
    /// Start item creation flow (camera) from dashboard
    func navigateToAddItem() {
        // If we're on dashboard, use the toolbar button
        if dashboardScreen.addItemFromCameraButton.exists {
            dashboardScreen.tapAddItemFromCamera()
        } else if dashboardScreen.emptyStateAddItemButton.exists {
            // Use empty state button if available
            dashboardScreen.tapEmptyStateAddItem()
        } else {
            // Navigate back to dashboard first, then add item
            navigateBackToDashboard()
            dashboardScreen.tapAddItemFromCamera()
        }
    }
    
    func navigateToAnExistingItem() {
        // Check if the Use-Test-Data launchargument is enabled
        if app.launchArguments.contains("Use-Test-Data") {
            dashboardScreen.tapFirstRecentItem()
        } else {
            XCTFail("Test data is not loaded, cannot test navigation to an existing item")
        }
    }
    
    /// Navigate to dashboard (root view)
    func navigateToDashboard() {
        navigateBackToDashboard()
    }
    
    /// Navigate back to dashboard by tapping back buttons or using navigation
    func navigateBackToDashboard() {
        var attempts = 0
        let maxAttempts = 5
        
        while !isDashboardVisible() && attempts < maxAttempts {
            if let backButton = findBackButton() {
                backButton.tap()
            } else {
                break
            }
            attempts += 1
            sleep(1) // Wait for navigation
        }
    }
    
    // MARK: - Helper Methods
    
    private func isDashboardVisible() -> Bool {
        return dashboardScreen.addItemFromCameraButton.exists ||
               dashboardScreen.allInventoryButton.exists ||
               app.staticTexts["Dashboard"].exists
    }
    
    private func findBackButton() -> XCUIElement? {
        // Look for common back button patterns
        let backButtons = [
            app.navigationBars.buttons.element(boundBy: 0), // First nav bar button (usually back)
            app.buttons["Back"],
            app.buttons.matching(NSPredicate(format: "label LIKE '*Back*'")).firstMatch
        ]
        
        for button in backButtons {
            if button.exists && button.isEnabled {
                return button
            }
        }
        
        return nil
    }
}

// MARK: - Legacy TabBar Compatibility

/// Provides legacy TabBar interface for existing tests
/// Maps old tab navigation to new button-based navigation
class TabBarCompat {
    private let navigationHelper: NavigationHelper
    
    init(app: XCUIApplication) {
        self.navigationHelper = NavigationHelper(app: app)
    }
    
    func tapDashboard() {
        navigationHelper.navigateToDashboard()
    }
    
    func tapAllItems() {
        navigationHelper.navigateToAllItems()
    }
    
    func tapAddItem() {
        navigationHelper.navigateToAddItem()
    }
    
    func tapSettings() {
        navigationHelper.navigateToSettings()
    }
    
    func tapLocations() {
        // Locations are accessed through settings now
        navigationHelper.navigateToSettings()
        // Add specific logic here if locations have a direct route
    }
}
