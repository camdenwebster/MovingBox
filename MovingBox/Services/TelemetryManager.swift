//
//  TelemetryManager.swift
//  MovingBox
//
//  Created by Camden Webster on 3/17/25.
//

import Foundation
import TelemetryDeck
import UIKit
import CryptoKit

/// Centralized manager for tracking app analytics via TelemetryDeck
/// Marked as @unchecked Sendable because:
/// - All methods call thread-safe TelemetryDeck APIs
/// - No mutable state is modified after initialization
/// - Safe to access from any thread/actor
final class TelemetryManager: @unchecked Sendable {
    static let shared = TelemetryManager()

    private init() {}

    // MARK: - RevenueCat Integration

    /// Returns the hashed user identifier that TelemetryDeck uses
    /// This matches the identifier that TelemetryDeck sends to its servers
    /// for RevenueCat integration purposes
    var hashedDefaultUser: String {
        // TelemetryDeck uses the device's identifierForVendor by default
        // and hashes it with SHA256
        let defaultIdentifier = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        return sha256Hash(defaultIdentifier)
    }

    /// Hash a string using SHA256, matching TelemetryDeck's approach
    private func sha256Hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
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
    
    func trackCaptureModeSelected(mode: String, imageCount: Int, isProUser: Bool) {
        TelemetryManager.signal("Inventory.Analysis.captureModeSelected", with: [
            "mode": mode,
            "image_count": String(imageCount),
            "is_pro_user": isProUser ? "true" : "false"
        ])
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
    
    // MARK: - Data Export/Import
    
    func trackPhotoCopyFailures(failureCount: Int, totalPhotos: Int, failureRate: Double) {
        TelemetryManager.signal("photo-copy-failures", with: [
            "failure_count": String(failureCount),
            "total_photos": String(totalPhotos),
            "failure_rate": String(format: "%.2f", failureRate)
        ])
    }
    
    func trackExportBatchSize(batchSize: Int, deviceMemoryGB: Double, itemCount: Int) {
        TelemetryManager.signal("export-batch-size-used", with: [
            "batch_size": String(batchSize),
            "device_memory_gb": String(format: "%.1f", deviceMemoryGB),
            "item_count": String(itemCount)
        ])
    }

    // MARK: - Helper

    private static func signal(_ name: String, with additionalInfo: [String: String] = [:]) {
        TelemetryDeck.signal(name, parameters: additionalInfo)
    }

}
