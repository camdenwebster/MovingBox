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
    
    // MARK: - AI Analysis Detailed Tracking
    
    func trackAIAnalysisStarted(
        isProUser: Bool,
        useHighQuality: Bool,
        model: String,
        detailLevel: String,
        imageResolution: CGFloat,
        imageCount: Int,
        itemId: String? = nil
    ) {
        TelemetryManager.signal("ai-analysis-started", with: [
            "is_pro_user": isProUser ? "true" : "false",
            "use_high_quality": useHighQuality ? "true" : "false",
            "model": model,
            "detail_level": detailLevel,
            "image_resolution": String(Int(imageResolution)),
            "image_count": String(imageCount),
            "item_id": itemId ?? "unknown"
        ])
    }
    
    func trackAIAnalysisCompleted(
        isProUser: Bool,
        useHighQuality: Bool,
        model: String,
        detailLevel: String,
        imageResolution: CGFloat,
        imageCount: Int,
        responseTimeMs: Int,
        success: Bool,
        itemId: String? = nil
    ) {
        TelemetryManager.signal("ai-analysis-completed", with: [
            "is_pro_user": isProUser ? "true" : "false",
            "use_high_quality": useHighQuality ? "true" : "false",
            "model": model,
            "detail_level": detailLevel,
            "image_resolution": String(Int(imageResolution)),
            "image_count": String(imageCount),
            "response_time_ms": String(responseTimeMs),
            "success": success ? "true" : "false",
            "item_id": itemId ?? "unknown"
        ])
    }
    
    func trackAITokenUsage(
        totalTokens: Int,
        promptTokens: Int,
        completionTokens: Int,
        requestTimeSeconds: Double,
        imageCount: Int,
        isProUser: Bool,
        model: String
    ) {
        TelemetryManager.signal("ai-token-usage", with: [
            "total_tokens": String(totalTokens),
            "prompt_tokens": String(promptTokens),
            "completion_tokens": String(completionTokens),
            "request_time_seconds": String(format: "%.2f", requestTimeSeconds),
            "image_count": String(imageCount),
            "is_pro_user": isProUser ? "true" : "false",
            "model": model,
            "tokens_per_second": String(format: "%.1f", Double(totalTokens) / requestTimeSeconds),
            "is_multi_image": imageCount > 1 ? "true" : "false"
        ])
    }
    
    func trackHighQualityToggleUsed(enabled: Bool, isProUser: Bool) {
        TelemetryManager.signal("high-quality-toggle-used", with: [
            "enabled": enabled ? "true" : "false",
            "is_pro_user": isProUser ? "true" : "false"
        ])
    }
    
    func trackMultipleAnalysisAttempt(itemId: String, attemptNumber: Int) {
        TelemetryManager.signal("multiple-analysis-attempt", with: [
            "item_id": itemId,
            "attempt_number": String(attemptNumber)
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
