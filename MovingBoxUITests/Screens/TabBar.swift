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
        
        // Initialize tab bar items using accessibility identifiers
        self.dashboardTab = app.tabBars.buttons["Dashboard"]
        self.locationsTab = app.tabBars.buttons["Locations"]
        self.addItemTab = app.tabBars.buttons["Add Item"]
        self.allItemsTab = app.tabBars.buttons["All Items"]
        self.settingsTab = app.tabBars.buttons["Settings"]
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
