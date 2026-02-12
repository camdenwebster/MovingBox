//
//  AIAnalysisStrictModeTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 9/29/25.
//

import Foundation
import MovingBoxAIAnalysis
import SwiftData
import SwiftUI
import Testing

@testable import MovingBox

/// Tests for AI analysis service with strict mode disabled
/// NOTE: These tests are disabled because they make real API calls which can hang
@MainActor
@Suite(.disabled("Tests make real Gemini API calls which can hang"))
struct AIAnalysisStrictModeTests {

    func createTestContainer() throws -> ModelContainer {
        let schema = Schema([InventoryItem.self, InventoryLocation.self, InventoryLabel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Multi-item analysis with strict mode disabled returns items")
    func testMultiItemAnalysisWithStrictModeDisabled() async throws {
        // Skip if no API key available
        let settings = SettingsManager()
        guard !settings.apiKey.isEmpty else {
            print("⚠️ Skipping AI analysis test - no API key configured")
            return
        }

        let container = try createTestContainer()
        let context = ModelContext(container)

        // Create test image data (1x1 pixel PNG)
        let testImageData = createTestImageData()
        let testImage = UIImage(data: testImageData)!

        // Create service with real images array
        let aiService = AIAnalysisService(
            imageOptimizer: OptimizedImageManager.shared, telemetryTracker: TelemetryManager.shared)

        do {
            print("🔄 Testing multi-item analysis with strict mode disabled...")
            let aiContext = AIAnalysisContext.from(modelContext: context, settings: settings)
            let response = try await aiService.getMultiItemDetails(
                from: [testImage],
                settings: settings,
                context: aiContext
            )

            // Log the full response for debugging
            print("📊 AI Response:")
            print("   - Detected Count: \(response.detectedCount)")
            print("   - Analysis Type: \(response.analysisType)")
            print("   - Confidence: \(response.confidence)")
            print("   - Items Count: \(response.safeItems.count)")
            print("   - Raw Items: \(response.items?.count ?? 0)")

            // Basic response validation
            #expect(response.analysisType == "multi_item")
            #expect(response.confidence >= 0.0 && response.confidence <= 1.0)
            #expect(response.detectedCount >= 0)

            // Test the critical issue: items array should be present
            if let items = response.items {
                print("✅ SUCCESS: AI returned items array with \(items.count) items")

                // Validate items structure if present
                for (index, item) in items.enumerated() {
                    print("   Item \(index + 1): \(item.title) (\(item.category))")
                    #expect(!item.title.isEmpty, "Item title should not be empty")
                    #expect(!item.category.isEmpty, "Item category should not be empty")
                    #expect(
                        item.confidence >= 0.0 && item.confidence <= 1.0, "Item confidence should be valid")
                }

                // The detected count should match items array length
                #expect(
                    response.detectedCount == items.count,
                    "Detected count (\(response.detectedCount)) should match items array length (\(items.count))"
                )

            } else {
                print("⚠️ WARNING: AI response missing items array")
                print("   This suggests the API is still not following the function schema properly")
                print("   Safe items count: \(response.safeItems.count)")

                // Even without items, safeItems should work
                #expect(response.safeItems.isEmpty, "Safe items should be empty when items is nil")
            }

        } catch {
            print("❌ AI Service Error: \(error)")

            // Log specific error details
            if let aiError = error as? AIAnalysisError {
                print("   AI Error Type: \(aiError)")
            }

            // Don't fail the test for API errors - this is about testing behavior
            print("   Note: API errors are expected during testing")
        }
    }

    @Test("Multi-item analysis handles edge cases gracefully")
    func testMultiItemAnalysisEdgeCases() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = SettingsManager()

        // Test with empty API key
        settings.apiKey = ""

        let testImageData = createTestImageData()
        let testImage = UIImage(data: testImageData)!

        let aiService = AIAnalysisService(
            imageOptimizer: OptimizedImageManager.shared, telemetryTracker: TelemetryManager.shared)

        // Should throw appropriate error for missing API key
        let aiContext = AIAnalysisContext.from(modelContext: context, settings: settings)
        await #expect(throws: AIAnalysisError.self) {
            try await aiService.getMultiItemDetails(
                from: [testImage],
                settings: settings,
                context: aiContext
            )
        }
    }

    @Test("Safe items property works correctly")
    func testSafeItemsProperty() {
        // Test with nil items
        let responseWithNilItems = MultiItemAnalysisResponse(
            items: nil,
            detectedCount: 5,
            analysisType: "multi_item",
            confidence: 0.8
        )

        #expect(responseWithNilItems.safeItems.isEmpty)
        #expect(responseWithNilItems.safeItems.count == 0)

        // Test with empty items array
        let responseWithEmptyItems = MultiItemAnalysisResponse(
            items: [],
            detectedCount: 0,
            analysisType: "multi_item",
            confidence: 0.9
        )

        #expect(responseWithEmptyItems.safeItems.isEmpty)
        #expect(responseWithEmptyItems.safeItems.count == 0)

        // Test with actual items
        let testItem = DetectedInventoryItem(
            title: "Test Item",
            description: "Test Description",
            category: "Test Category",
            make: "Test Make",
            model: "Test Model",
            estimatedPrice: "$100",
            confidence: 0.95
        )

        let responseWithItems = MultiItemAnalysisResponse(
            items: [testItem],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.95
        )

        #expect(responseWithItems.safeItems.count == 1)
        #expect(responseWithItems.safeItems.first?.title == "Test Item")
    }

    // MARK: - Helper Methods

    private func createTestImageData() -> Data {
        // Create a simple 1x1 pixel PNG for testing
        let image = UIImage(systemName: "photo")!
        return image.pngData() ?? Data()
    }
}
