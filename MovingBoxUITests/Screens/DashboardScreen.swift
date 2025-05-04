//
//  DashboardScreen.swift
//  MovingBox
//
//  Created by Camden Webster on 4/16/25.
//

import XCTest

class DashboardScreen {
    let app: XCUIApplication
    
    let statCardLabel: XCUIElement
    let statCardValue: XCUIElement
    
    init(app: XCUIApplication) {
        self.app = app
        self.statCardLabel = app.staticTexts["statCardLabel"]
        self.statCardValue = app.staticTexts["statCardValue"]
    }
    
    
    func testDataLoaded() -> Bool {
        var iterations = 0
        let expectedItemCount = 53
        guard let actualItemCount = Int(statCardValue.firstMatch.label) else {
            print("Error: actualItemCount is not a valid number.")
            return false
        }
        while actualItemCount >= expectedItemCount && iterations < 10 {
            sleep(1)
            iterations += 1
            print("Waiting for data to load...")
        }
        return actualItemCount >= expectedItemCount
    }
    
    
}
