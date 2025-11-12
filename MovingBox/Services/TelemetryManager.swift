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
        TelemetryManager.signal("Inventory.itemCreated")
    }
    
    func trackInventoryItemDeleted() {
        TelemetryManager.signal("Inventory.itemDeleted")
    }
    
    func trackCameraAnalysisUsed() {
        TelemetryManager.signal("Inventory.Analysis.cameraUsed")
    }
    
    func trackPhotoAnalysisUsed() {
        TelemetryManager.signal("Inventory.Analysis.photoUsed")
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
        TelemetryManager.signal("AIAnalysis.started", with: [
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
        TelemetryManager.signal("AIAnalysis.completed", with: [
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
        TelemetryManager.signal("AIAnalysis.tokenUsage", with: [
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
        TelemetryManager.signal("Settings.Analysis.highQualityToggled", with: [
            "enabled": enabled ? "true" : "false",
            "is_pro_user": isProUser ? "true" : "false"
        ])
    }
    
    func trackMultipleAnalysisAttempt(itemId: String, attemptNumber: Int) {
        TelemetryManager.signal("AIAnalysis.retryAttempt", with: [
            "item_id": itemId,
            "attempt_number": String(attemptNumber)
        ])
    }
    
    // MARK: - Onboarding

    func trackUsageSurveySelected(usages: String, count: Int) {
        TelemetryManager.signal("Onboarding.Survey.usageSelected", with: [
            "usages": usages,
            "count": String(count)
        ])
    }

    func trackUsageSurveySkipped() {
        TelemetryManager.signal("Onboarding.Survey.skipped")
    }

    // MARK: - Settings

    func trackLocationCreated(name: String) {
        TelemetryManager.signal("Settings.Location.created")
    }
    
    func trackLocationDeleted() {
        TelemetryManager.signal("Settings.Location.deleted")
    }
    
    func trackLabelCreated(name: String) {
        TelemetryManager.signal("Settings.Label.created")
    }
    
    func trackLabelDeleted() {
        TelemetryManager.signal("Settings.Label.deleted")
    }
    
    // MARK: - Navigation
    
    func trackTabSelected(tab: String) {
        TelemetryManager.signal("Navigation.tabSelected", with: [
            "tab": tab
        ])
    }

    // MARK: - App Store Review

    func trackAppReviewRequested() {
        TelemetryManager.signal("AppStore.reviewRequested")
    }

    // MARK: - Helper

    private static func signal(_ name: String, with additionalInfo: [String: String] = [:]) {
        TelemetryDeck.signal(name, parameters: additionalInfo)
    }

}
