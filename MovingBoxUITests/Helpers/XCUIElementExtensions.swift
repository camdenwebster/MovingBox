//
//  XCUIElementExtensions.swift
//  MovingBoxUITests
//
//  Created by Claude Code on 9/13/25.
//

import XCTest

extension XCUIElement {
    /// Scrolls the element into view by finding its containing scroll view and adjusting the scroll position
    func scrollToElement() {
        // If the element is already hittable, no need to scroll
        if self.isHittable {
            return
        }
        
        // Find the containing scroll view
        let scrollView = findContainingScrollView()
        guard let container = scrollView else {
            print("Warning: Could not find containing scroll view for element")
            return
        }
        
        // Get the element's frame relative to the scroll view
        let elementFrame = self.frame
        let containerFrame = container.frame
        
        // Calculate if we need to scroll up or down
        let elementBottom = elementFrame.origin.y + elementFrame.size.height
        let containerBottom = containerFrame.origin.y + containerFrame.size.height
        
        if elementBottom > containerBottom {
            // Element is below visible area, scroll down
            let scrollDistance = elementBottom - containerBottom + 50 // Add some padding
            container.swipeUp()
        } else if elementFrame.origin.y < containerFrame.origin.y {
            // Element is above visible area, scroll up
            container.swipeDown()
        }
        
        // Wait a moment for the scroll to complete
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    /// Finds the containing scroll view for this element
    private func findContainingScrollView() -> XCUIElement? {
        var parent = self
        
        // Look for a scroll view in the hierarchy
        for _ in 0..<10 { // Limit search depth to prevent infinite loops
            if parent.elementType == .scrollView {
                return parent
            }
            
            // Try to find any scroll view containing this element
            let app = XCUIApplication()
            let scrollViews = app.scrollViews
            
            for i in 0..<scrollViews.count {
                let scrollView = scrollViews.element(boundBy: i)
                if scrollView.exists {
                    return scrollView
                }
            }
            
            break // Exit if we can't find a parent
        }
        
        // Fallback: return the first scroll view found in the app
        let app = XCUIApplication()
        let scrollViews = app.scrollViews
        if scrollViews.count > 0 {
            return scrollViews.firstMatch
        }
        
        return nil
    }
}