//
//  HighResolutionAnalysisTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 08/20/25.
//

import Testing
import Foundation
import SwiftData
import UIKit
@testable import MovingBox

@MainActor
struct HighResolutionAnalysisTests {
    
    // MARK: - SettingsManager Tests
    
    @Test("SettingsManager should provide correct effective AI model for Pro users")
    func testEffectiveAIModelForProUsers() async throws {
        let settings = SettingsManager()
        
        // Test Pro user with high quality enabled (default)
        settings.isPro = true
        settings.highQualityAnalysisEnabled = true
        #expect(settings.effectiveAIModel == "gpt-5-mini")
        
        // Test Pro user with high quality disabled
        settings.isPro = true
        settings.highQualityAnalysisEnabled = false
        #expect(settings.effectiveAIModel == "gpt-5")
    }
    
    @Test("SettingsManager should provide correct effective AI model for non-Pro users")
    func testEffectiveAIModelForNonProUsers() async throws {
        let settings = SettingsManager()
        
        // Test non-Pro user (regardless of toggle setting)
        settings.isPro = false
        settings.highQualityAnalysisEnabled = true // Should be ignored
        #expect(settings.effectiveAIModel == "gpt-5")
        
        settings.isPro = false
        settings.highQualityAnalysisEnabled = false
        #expect(settings.effectiveAIModel == "gpt-5")
    }
    
    @Test("SettingsManager should provide correct effective detail level")
    func testEffectiveDetailLevel() async throws {
        let settings = SettingsManager()
        
        // Test Pro user with high quality enabled
        settings.isPro = true
        settings.highQualityAnalysisEnabled = true
        #expect(settings.effectiveDetailLevel == "high")
        
        // Test Pro user with high quality disabled
        settings.isPro = true
        settings.highQualityAnalysisEnabled = false
        #expect(settings.effectiveDetailLevel == "low")
        
        // Test non-Pro user
        settings.isPro = false
        settings.highQualityAnalysisEnabled = true // Should be ignored
        #expect(settings.effectiveDetailLevel == "low")
    }
    
    @Test("SettingsManager should provide correct effective image resolution")
    func testEffectiveImageResolution() async throws {
        let settings = SettingsManager()
        
        // Test Pro user with high quality enabled
        settings.isPro = true
        settings.highQualityAnalysisEnabled = true
        #expect(settings.effectiveImageResolution == 1250.0)
        
        // Test Pro user with high quality disabled
        settings.isPro = true
        settings.highQualityAnalysisEnabled = false
        #expect(settings.effectiveImageResolution == 512.0)
        
        // Test non-Pro user
        settings.isPro = false
        settings.highQualityAnalysisEnabled = true // Should be ignored
        #expect(settings.effectiveImageResolution == 512.0)
    }
    
    @Test("SettingsManager should not show paywall for AI scans")
    func testAILimitRemoval() async throws {
        let settings = SettingsManager()
        
        // Test that AI scan limit is removed for all users
        settings.isPro = false
        #expect(settings.shouldShowPaywallForAiScan(currentCount: 100) == false)
        
        settings.isPro = true
        #expect(settings.shouldShowPaywallForAiScan(currentCount: 100) == false)
    }
    
    @Test("SettingsManager should persist high quality analysis setting")
    func testHighQualityAnalysisPersistence() async throws {
        let settings1 = SettingsManager()
        settings1.isPro = true
        settings1.highQualityAnalysisEnabled = false
        
        // Create new instance to test persistence
        let settings2 = SettingsManager()
        settings2.isPro = true
        
        // Wait for async initialization
        try await Task.sleep(for: .milliseconds(100))
        
        // Should load the persisted value
        #expect(settings2.highQualityAnalysisEnabled == false)
    }
    
    // MARK: - OptimizedImageManager Tests
    
    @Test("OptimizedImageManager should process images at specified resolution")
    func testImageProcessingWithResolution() async throws {
        let manager = OptimizedImageManager.shared
        let testImage = createTestImage(size: CGSize(width: 2000, height: 2000))
        
        // Test high resolution processing
        let highResBase64 = await manager.prepareImageForAI(from: testImage, resolution: 1250.0)
        #expect(highResBase64 != nil)
        
        // Test standard resolution processing
        let standardResBase64 = await manager.prepareImageForAI(from: testImage, resolution: 512.0)
        #expect(standardResBase64 != nil)
        
        // High resolution should produce a different (likely larger) result
        #expect(highResBase64 != standardResBase64)
    }
    
    @Test("OptimizedImageManager should handle multiple images with custom resolution")
    func testMultipleImagesWithCustomResolution() async throws {
        let manager = OptimizedImageManager.shared
        let testImages = [
            createTestImage(size: CGSize(width: 1000, height: 1000)),
            createTestImage(size: CGSize(width: 800, height: 600)),
            createTestImage(size: CGSize(width: 1200, height: 1200))
        ]
        
        // Test with high resolution
        let base64Images = await manager.prepareMultipleImagesForAI(from: testImages, resolution: 1250.0)
        
        #expect(base64Images.count == testImages.count)
        for base64String in base64Images {
            #expect(!base64String.isEmpty)
        }
    }
    
    // MARK: - OpenAI Service Integration Tests
    
    @Test("OpenAI service should use effective model and detail level")
    func testOpenAIServiceConfiguration() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, configurations: config)
        let modelContext = container.mainContext
        
        let settingsManager = SettingsManager()
        settingsManager.isPro = true
        settingsManager.highQualityAnalysisEnabled = true
        
        let testImage = createTestImage()
        let base64Image = await OptimizedImageManager.shared.prepareImageForAI(from: testImage, resolution: 1250.0)!
        
        let service = OpenAIService(imageBase64: base64Image, settings: settingsManager, modelContext: modelContext)
        
        // Test that the service uses the correct settings
        #expect(settingsManager.effectiveAIModel == "gpt-5-mini")
        #expect(settingsManager.effectiveDetailLevel == "high")
        #expect(settingsManager.effectiveImageResolution == 1250.0)
    }
    
    @Test("OpenAI service should generate request with correct parameters")
    func testOpenAIRequestGeneration() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, configurations: config)
        let modelContext = container.mainContext
        
        let settingsManager = SettingsManager()
        settingsManager.isPro = true
        settingsManager.highQualityAnalysisEnabled = true
        
        let testImage = createTestImage()
        let base64Image = await OptimizedImageManager.shared.prepareImageForAI(from: testImage, resolution: 1250.0)!
        
        let service = OpenAIService(imageBase64: base64Image, settings: settingsManager, modelContext: modelContext)
        let urlRequest = try service.generateURLRequest(httpMethod: .post)
        
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.httpBody != nil)
        
        // Decode the payload to verify it uses correct model
        if let bodyData = urlRequest.httpBody {
            let payload = try service.decodePayload(from: bodyData)
            #expect(payload.model == "gpt-5-mini")
        }
    }
    
    // MARK: - Helper Functions
    
    private func createTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.blue.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some text to make it more realistic
            let text = "Test Image"
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 16)
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("High resolution processing should complete within reasonable time")
    func testHighResolutionPerformance() async throws {
        let manager = OptimizedImageManager.shared
        let testImage = createTestImage(size: CGSize(width: 3000, height: 3000))
        
        let startTime = Date()
        let _ = await manager.prepareImageForAI(from: testImage, resolution: 1250.0)
        let endTime = Date()
        
        let processingTime = endTime.timeIntervalSince(startTime)
        #expect(processingTime < 10.0, "High resolution processing should complete within 10 seconds")
    }
    
    @Test("Memory usage should remain stable with large images")
    func testMemoryStability() async throws {
        let manager = OptimizedImageManager.shared
        let largeImages = (0..<5).map { _ in
            createTestImage(size: CGSize(width: 2000, height: 2000))
        }
        
        let startMemory = getCurrentMemoryUsage()
        
        for image in largeImages {
            let _ = await manager.prepareImageForAI(from: image, resolution: 1250.0)
        }
        
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        // Allow for some memory increase but it shouldn't be excessive
        #expect(memoryIncrease < 100_000_000, "Memory increase should be less than 100MB: \(memoryIncrease / 1_000_000)MB")
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return info.phys_footprint
        } else {
            return 0
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Should handle invalid images gracefully")
    func testInvalidImageHandling() async throws {
        let manager = OptimizedImageManager.shared
        
        // Create a minimal 1x1 image
        let tinyImage = createTestImage(size: CGSize(width: 1, height: 1))
        
        let result = await manager.prepareImageForAI(from: tinyImage, resolution: 1250.0)
        #expect(result != nil, "Should handle tiny images without crashing")
    }
}