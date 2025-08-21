//
//  HighResolutionAnalysisTests.swift
//  MovingBoxTests
//
//  Unit tests for high resolution image analysis feature for Pro users
//

import Testing
import Foundation
import SwiftData
import UIKit
@testable import MovingBox

@Suite("High Resolution Analysis Tests")
struct HighResolutionAnalysisTests {
    
    @Test("Settings Manager - High Quality Toggle Defaults")
    func testSettingsManagerHighQualityDefaults() async throws {
        await MainActor.run {
            // Clear any existing preferences to test clean defaults
            UserDefaults.standard.removeObject(forKey: "highQualityAnalysisEnabled")
            UserDefaults.standard.removeObject(forKey: "isPro")
            
            let settingsManager = SettingsManager()
            
            // Test the effective settings behavior regardless of Pro status
            let effectiveModel = settingsManager.effectiveAIModel
            let effectiveResolution = settingsManager.effectiveImageResolution
            let effectiveDetail = settingsManager.effectiveDetailLevel
            
            // These should always be valid values
            #expect(!effectiveModel.isEmpty, "Effective AI model should never be empty")
            #expect(effectiveResolution > 0, "Effective image resolution should be positive")
            #expect(!effectiveDetail.isEmpty, "Effective detail level should never be empty")
            #expect(["low", "high"].contains(effectiveDetail), "Detail level should be valid value")
            
            // Test the relationship between settings
            let currentProStatus = settingsManager.isPro
            let currentHighQualityEnabled = settingsManager.highQualityAnalysisEnabled
            
            if currentProStatus && currentHighQualityEnabled {
                #expect(effectiveModel == "gpt-5-mini", "Pro users with high quality should use gpt-5-mini")
                #expect(effectiveResolution == 1250.0, "Pro users with high quality should use 1250px resolution")
                #expect(effectiveDetail == "high", "Pro users with high quality should use high detail")
            } else {
                #expect(effectiveModel == "gpt-4o", "Standard users should use gpt-4o")
                #expect(effectiveResolution == 512.0, "Standard users should use 512px resolution")
                #expect(effectiveDetail == "low", "Standard users should use low detail")
            }
            
            // Test toggle availability
            if currentProStatus {
                #expect(settingsManager.isHighQualityToggleAvailable == true, "Pro users should have toggle available")
            } else {
                #expect(settingsManager.isHighQualityToggleAvailable == false, "Non-Pro users should not have toggle available")
            }
        }
    }
    
    @Test("Settings Manager - Effective AI Model Selection")
    func testEffectiveAIModelSelection() async throws {
        await MainActor.run {
            let settingsManager = SettingsManager()
            
            if settingsManager.isPro && settingsManager.highQualityAnalysisEnabled {
                #expect(settingsManager.effectiveAIModel == "gpt-5-mini", "Pro users with high quality enabled should use gpt-5-mini")
            } else {
                #expect(settingsManager.effectiveAIModel == "gpt-4o", "Standard users or Pro users with high quality disabled should use gpt-4o")
            }
        }
    }
    
    @Test("Settings Manager - Effective Image Resolution")
    func testEffectiveImageResolution() async throws {
        await MainActor.run {
            let settingsManager = SettingsManager()
            
            if settingsManager.isPro && settingsManager.highQualityAnalysisEnabled {
                #expect(settingsManager.effectiveImageResolution == 1250.0, "Pro users with high quality should use 1250px resolution")
            } else {
                #expect(settingsManager.effectiveImageResolution == 512.0, "Standard users should use 512px resolution")
            }
        }
    }
    
    @Test("Settings Manager - Effective Detail Level")
    func testEffectiveDetailLevel() async throws {
        await MainActor.run {
            let settingsManager = SettingsManager()
            
            if settingsManager.isPro && settingsManager.highQualityAnalysisEnabled {
                #expect(settingsManager.effectiveDetailLevel == "high", "Pro users with high quality should use high detail")
            } else {
                #expect(settingsManager.effectiveDetailLevel == "low", "Standard users should use low detail")
            }
        }
    }
    
    @Test("Settings Manager - High Quality Toggle Availability")
    func testHighQualityToggleAvailability() async throws {
        await MainActor.run {
            let settingsManager = SettingsManager()
            
            if settingsManager.isPro {
                #expect(settingsManager.isHighQualityToggleAvailable == true, "Pro users should have toggle available")
            } else {
                #expect(settingsManager.isHighQualityToggleAvailable == false, "Non-Pro users should not have toggle available")
            }
        }
    }
    
    @Test("Settings Manager - AI Scan Paywall Always Returns False")
    func testAIScanPaywallRemoval() async throws {
        await MainActor.run {
            let settingsManager = SettingsManager()
            
            // Test with various counts - should always return false now
            #expect(settingsManager.shouldShowPaywallForAiScan(currentCount: 0) == false)
            #expect(settingsManager.shouldShowPaywallForAiScan(currentCount: 25) == false)
            #expect(settingsManager.shouldShowPaywallForAiScan(currentCount: 50) == false)
            #expect(settingsManager.shouldShowPaywallForAiScan(currentCount: 100) == false)
        }
    }
    
    @Test("OptimizedImageManager - Dual Resolution Support")
    func testOptimizedImageManagerDualResolution() async throws {
        let imageManager = OptimizedImageManager.shared
        
        // Create a test image - use a larger synthetic image to ensure size differences
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 1000))
        let testImage = renderer.image { context in
            context.cgContext.setFillColor(UIColor.red.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 500, height: 500))
            context.cgContext.setFillColor(UIColor.blue.cgColor)
            context.cgContext.fill(CGRect(x: 500, y: 500, width: 500, height: 500))
        }
        
        // Test standard quality (512px max)
        let standardBase64 = await imageManager.prepareImageForAI(from: testImage, useHighQuality: false)
        #expect(standardBase64 != nil, "Standard quality image preparation should succeed")
        
        // Test high quality (1250px max)
        let highQualityBase64 = await imageManager.prepareImageForAI(from: testImage, useHighQuality: true)
        #expect(highQualityBase64 != nil, "High quality image preparation should succeed")
        
        // High quality should produce different (typically larger) result
        if let std = standardBase64, let hq = highQualityBase64 {
            #expect(std != hq, "Standard and high quality should produce different results")
        }
    }
    
    @Test("OptimizedImageManager - Multiple Images with Quality")
    func testMultipleImagesWithQuality() async throws {
        let imageManager = OptimizedImageManager.shared
        
        // Create synthetic test images with different content
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600))
        let testImages = [
            renderer.image { context in
                context.cgContext.setFillColor(UIColor.red.cgColor)
                context.cgContext.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
            },
            renderer.image { context in
                context.cgContext.setFillColor(UIColor.green.cgColor)
                context.cgContext.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
            },
            renderer.image { context in
                context.cgContext.setFillColor(UIColor.blue.cgColor)
                context.cgContext.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
            }
        ]
        
        // Test multiple image processing
        let results = await imageManager.prepareMultipleImagesForAI(from: testImages)
        #expect(results.count == testImages.count, "Should process all images")
        
        // Verify all results are valid base64 strings
        for result in results {
            #expect(!result.isEmpty, "Each result should be non-empty")
            #expect(Data(base64Encoded: result) != nil, "Each result should be valid base64")
        }
    }
    
    @Test("TelemetryManager - AI Analysis Tracking")
    func testTelemetryAnalysisTracking() async throws {
        let telemetryManager = TelemetryManager.shared
        
        // Test tracking analysis start (should not crash)
        telemetryManager.trackAIAnalysisStarted(
            isProUser: true,
            useHighQuality: true,
            model: "gpt-5-mini",
            detailLevel: "high",
            imageResolution: 1250.0,
            imageCount: 2
        )
        
        // Test tracking analysis completion (should not crash)
        telemetryManager.trackAIAnalysisCompleted(
            isProUser: true,
            useHighQuality: true,
            model: "gpt-5-mini",
            detailLevel: "high",
            imageResolution: 1250.0,
            imageCount: 2,
            responseTimeMs: 1500,
            success: true
        )
        
        // Test toggle tracking
        telemetryManager.trackHighQualityToggleUsed(enabled: true, isProUser: true)
        
        // Test multiple analysis attempt tracking
        telemetryManager.trackMultipleAnalysisAttempt(itemId: "test-item", attemptNumber: 2)
        
        // If we reach here without crashing, the tracking is working
        #expect(true, "All telemetry tracking calls should complete without error")
    }
    
    @Test("Settings Persistence")
    func testSettingsPersistence() async throws {
        await MainActor.run {
            let settingsManager = SettingsManager()
            
            // Test that high quality setting can be toggled
            let originalValue = settingsManager.highQualityAnalysisEnabled
            settingsManager.highQualityAnalysisEnabled = !originalValue
            
            // Value should be updated
            #expect(settingsManager.highQualityAnalysisEnabled == !originalValue, "High quality setting should toggle")
            
            // Restore original value
            settingsManager.highQualityAnalysisEnabled = originalValue
        }
    }
    
    @Test("Pro vs Non-Pro Behavior Differences")
    func testProVsNonProBehavior() async throws {
        await MainActor.run {
            let settingsManager = SettingsManager()
            
            if settingsManager.isPro {
                // Pro user tests - more rigorous assertions
                #expect(settingsManager.isHighQualityToggleAvailable == true, "Pro users should have access to high quality toggle")
                
                // Test with high quality enabled (default for Pro)
                if settingsManager.highQualityAnalysisEnabled {
                    #expect(settingsManager.effectiveImageResolution == 1250.0, "Pro users with high quality should get 1250px resolution")
                    #expect(settingsManager.effectiveAIModel == "gpt-5-mini", "Pro users with high quality should use gpt-5-mini model")
                    #expect(settingsManager.effectiveDetailLevel == "high", "Pro users with high quality should use high detail level")
                } else {
                    // Pro user with high quality disabled
                    #expect(settingsManager.effectiveImageResolution == 512.0, "Pro users with high quality disabled should get 512px resolution")
                    #expect(settingsManager.effectiveAIModel == "gpt-4o", "Pro users with high quality disabled should use gpt-4o model")
                    #expect(settingsManager.effectiveDetailLevel == "low", "Pro users with high quality disabled should use low detail level")
                }
            } else {
                // Non-Pro user tests
                #expect(settingsManager.isHighQualityToggleAvailable == false)
                #expect(settingsManager.effectiveImageResolution == 512.0)
                #expect(settingsManager.effectiveAIModel == "gpt-4o")
                #expect(settingsManager.effectiveDetailLevel == "low")
            }
        }
    }
    
    @Test("Settings Manager Reset Behavior")
    func testSettingsReset() async throws {
        await MainActor.run {
            let settingsManager = SettingsManager()
            
            // Modify some settings
            settingsManager.highQualityAnalysisEnabled = true
            settingsManager.aiModel = "test-model"
            
            // Reset to defaults
            settingsManager.resetToDefaults()
            
            // High quality should be disabled after reset
            #expect(settingsManager.highQualityAnalysisEnabled == false, "High quality should be disabled after reset")
            
            // Model should be back to default
            #expect(settingsManager.aiModel == "gpt-4o-mini", "AI model should be back to default")
        }
    }
    
    @Test("Image Quality Feature Integration")
    func testImageQualityFeatureIntegration() async throws {
        let imageManager = OptimizedImageManager.shared
        
        let (useHighQuality, shouldTest) = await MainActor.run {
            let settingsManager = SettingsManager()
            
            // Create test configuration for Pro user with high quality enabled
            if settingsManager.isPro {
                settingsManager.highQualityAnalysisEnabled = true
                
                // Test that effective settings are consistent
                #expect(settingsManager.effectiveImageResolution == 1250.0)
                #expect(settingsManager.effectiveAIModel == "gpt-5-mini")
                #expect(settingsManager.effectiveDetailLevel == "high")
                
                // Return settings for async image processing
                return (settingsManager.isPro && settingsManager.highQualityAnalysisEnabled, true)
            }
            return (false, false)
        }
        
        if shouldTest {
            // Test image processing with these settings
            let testImage = UIImage(systemName: "photo") ?? UIImage()
            let result = await imageManager.prepareImageForAI(from: testImage, useHighQuality: useHighQuality)
            #expect(result != nil, "High quality image processing should succeed for Pro users")
        }
    }
    
    @Test("Memory and Performance Considerations")
    func testMemoryAndPerformance() async throws {
        let imageManager = OptimizedImageManager.shared
        
        // Create a larger test image for memory testing
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        
        let startTime = Date()
        
        // Test high quality processing performance
        let result = await imageManager.prepareImageForAI(from: testImage, useHighQuality: true)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        #expect(result != nil, "High quality processing should complete")
        #expect(processingTime < 10.0, "High quality processing should complete within reasonable time")
    }
    
    @Test("Error Handling and Graceful Degradation")
    func testErrorHandlingAndGracefulDegradation() async throws {
        await MainActor.run {
            let settingsManager = SettingsManager()
            
            // Test that computed properties handle edge cases gracefully
            let model = settingsManager.effectiveAIModel
            let resolution = settingsManager.effectiveImageResolution
            let detail = settingsManager.effectiveDetailLevel
            
            #expect(!model.isEmpty, "Effective AI model should never be empty")
            #expect(resolution > 0, "Effective image resolution should be positive")
            #expect(!detail.isEmpty, "Effective detail level should never be empty")
            #expect(["low", "high"].contains(detail), "Detail level should be valid value")
        }
    }
}
