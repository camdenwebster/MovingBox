//
//  TelemetryManager.swift
//  MovingBox
//
//  Created by Camden Webster on 3/17/25.
//

import Foundation
import TelemetryDeck

/// Centralized manager for tracking app analytics via TelemetryDeck
class TelemetryManager {
    static let shared = TelemetryManager()
    
    private init() {}
    
    // MARK: - Inventory Items
    
    func trackInventoryItemAdded(name: String) {
        TelemetryManager.signal("inventory-item-added")
    }
    
    func trackInventoryItemDeleted() {
        TelemetryManager.signal("inventory-item-deleted")
    }
    
    func trackCameraAnalysisUsed() {
        TelemetryManager.signal("camera-analysis-used")
    }
    
    func trackPhotoAnalysisUsed() {
        TelemetryManager.signal("photo-analysis-used")
    }
    
    /// Track detailed AI analysis with metadata
    func trackAIAnalysis(itemId: String, isPro: Bool, model: String, resolution: CGFloat, detailLevel: String, imageCount: Int, success: Bool) {
        TelemetryManager.signal("ai-analysis-detailed", with: [
            "item_id": itemId,
            "user_type": isPro ? "pro" : "free",
            "model": model,
            "resolution": String(format: "%.0f", resolution),
            "detail_level": detailLevel,
            "image_count": String(imageCount),
            "success": success ? "true" : "false"
        ])
    }
    
    /// Track analysis attempts per item to detect multiple tries
    func trackItemAnalysisAttempt(itemId: String) {
        TelemetryManager.signal("item-analysis-attempt", with: [
            "item_id": itemId
        ])
    }
    
    /// Track high quality analysis toggle usage
    func trackHighQualityToggleChanged(enabled: Bool, isPro: Bool) {
        TelemetryManager.signal("high-quality-toggle-changed", with: [
            "enabled": enabled ? "true" : "false",
            "user_type": isPro ? "pro" : "free"
        ])
    }
    
    // MARK: - Settings
    
    func trackLocationCreated(name: String) {
        TelemetryManager.signal("location-created")
    }
    
    func trackLocationDeleted() {
        TelemetryManager.signal("location-deleted")
    }
    
    func trackLabelCreated(name: String) {
        TelemetryManager.signal("label-created")
    }
    
    func trackLabelDeleted() {
        TelemetryManager.signal("label-deleted")
    }
    
    // MARK: - Navigation
    
    func trackTabSelected(tab: String) {
        TelemetryManager.signal("tab-selected", with: [
            "tab": tab
        ])
    }
    
    // MARK: - Helper
    
    private static func signal(_ name: String, with additionalInfo: [String: String] = [:]) {
        TelemetryDeck.signal(name, parameters: additionalInfo)
    }
    
}
