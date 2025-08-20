//
//  TabBar.swift
//  MovingBox
//
//  Created by Camden Webster on 3/31/25.
//

import Foundation
import XCTest

/// Legacy TabBar class for backward compatibility
/// Now uses NavigationHelper to support the new button-based navigation
class TabBar {
    let app: XCUIApplication
    private let navigationHelper: NavigationHelper
    
    // Legacy tab bar items (kept for backward compatibility, but may not exist)
    let dashboardTab: XCUIElement
    let locationsTab: XCUIElement
    let addItemTab: XCUIElement
    let allItemsTab: XCUIElement
    let settingsTab: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        self.navigationHelper = NavigationHelper(app: app)
        
        // Check if device is iPad
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // Initialize legacy tab bar items (these may not exist in the new design)
        if isIPad {
            self.dashboardTab = app.buttons["Dashboard"]
            self.locationsTab = app.buttons["Locations"]
            self.addItemTab = app.buttons["Add Item"]
            self.allItemsTab = app.buttons["All Items"]
            self.settingsTab = app.buttons["Settings"]
        } else {
            self.dashboardTab = app.tabBars.buttons["Dashboard"]
            self.locationsTab = app.tabBars.buttons["Locations"]
            self.addItemTab = app.tabBars.buttons["Add Item"]
            self.allItemsTab = app.tabBars.buttons["All Items"]
            self.settingsTab = app.tabBars.buttons["Settings"]
        }
    }
    
    func tapDashboard() {
        // Try legacy first, fallback to new navigation
        if dashboardTab.exists {
            dashboardTab.tap()
        } else {
            navigationHelper.navigateToDashboard()
        }
    }
    
    func tapLocations() {
        // Try legacy first, fallback to new navigation
        if locationsTab.exists {
            locationsTab.tap()
        } else {
            navigationHelper.navigateToSettings()
            // TODO: Navigate to locations within settings if needed
        }
    }
    
    func tapAddItem() {
        // Try legacy first, fallback to new navigation
        if addItemTab.exists {
            addItemTab.tap()
        } else {
            navigationHelper.navigateToAddItem()
        }
    }
    
    func tapAllItems() {
        // Try legacy first, fallback to new navigation
        if allItemsTab.exists {
            allItemsTab.tap()
        } else {
            navigationHelper.navigateToAllItems()
        }
    }
    
    func tapSettings() {
        // Try legacy first, fallback to new navigation
        if settingsTab.exists {
            settingsTab.tap()
        } else {
            navigationHelper.navigateToSettings()
        }
    }
}
