//
//  TabBar.swift
//  MovingBox
//
//  Created by Camden Webster on 3/31/25.
//

import Foundation
import XCTest

class TabBar {
    let app: XCUIApplication
    
    // Tab bar items
    let dashboardTab: XCUIElement
    let locationsTab: XCUIElement
    let addItemTab: XCUIElement
    let allItemsTab: XCUIElement
    let settingsTab: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        
        // Check if device is iPad
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // Initialize tab bar items using appropriate query based on device type
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
        dashboardTab.tap()
    }
    
    func tapLocations() {
        locationsTab.tap()
    }
    
    func tapAddItem() {
        addItemTab.tap()
    }
    
    func tapAllItems() {
        allItemsTab.tap()
    }
    
    func tapSettings() {
        settingsTab.tap()
    }
}
