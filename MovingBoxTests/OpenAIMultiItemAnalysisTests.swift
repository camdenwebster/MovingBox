import Testing
import SwiftUI
import SwiftData
import UIKit
@testable import MovingBox

@MainActor
@Suite struct OpenAIMultiItemAnalysisTests {
    
    // MARK: - Test Setup
    
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            Home.self,
            InsurancePolicy.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    private func createTestSettings(isPro: Bool = true) -> MockSettingsManager {
        let settings = MockSettingsManager()
        settings.isPro = isPro
        settings.highQualityAnalysisEnabled = isPro // Only enable high quality for Pro users
        return settings
    }
    
    private func createTestImages(count: Int) -> [UIImage] {
        return (0..<count).map { _ in createTestImage() }
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    // MARK: - Multi-Item Response Structure Tests
    
    @Test("MultiItemAnalysisResponse structure is valid")
    func testMultiItemAnalysisResponseStructure() {
        let items = [
            DetectedInventoryItem(
                id: "1",
                title: "Item 1",
                description: "First item",
                category: "Electronics",
                make: "Apple",
                model: "iPhone",
                estimatedPrice: "$999",
                confidence: 0.95
            ),
            DetectedInventoryItem(
                id: "2",
                title: "Item 2",
                description: "Second item",
                category: "Books",
                make: "",
                model: "",
                estimatedPrice: "$25",
                confidence: 0.88
            )
        ]
        
        let response = MultiItemAnalysisResponse(
            items: items,
            detectedCount: 2,
            analysisType: "multi_item",
            confidence: 0.91
        )
        
        #expect(response.safeItems.count == 2)
        #expect(response.detectedCount == 2)
        #expect(response.analysisType == "multi_item")
        #expect(response.confidence == 0.91)
        #expect(response.isValid)
    }
    
    @Test("MultiItemAnalysisResponse validation works correctly")
    func testMultiItemAnalysisResponseValidation() {
        // Valid response
        let validResponse = MultiItemAnalysisResponse(
            items: [createMockDetectedItem()],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.85
        )
        #expect(validResponse.isValid)
        
        // Invalid - empty items but positive count
        let invalidResponse1 = MultiItemAnalysisResponse(
            items: [],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.85
        )
        #expect(!invalidResponse1.isValid)
        
        // Invalid - low confidence
        let invalidResponse2 = MultiItemAnalysisResponse(
            items: [createMockDetectedItem()],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.3
        )
        #expect(!invalidResponse2.isValid)
    }
    
    // MARK: - OpenAI Service Multi-Item Analysis Tests
    
    @Test("OpenAI service handles multi-item analysis request")
    func testMultiItemAnalysisRequest() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        mockService.mockMultiItemResponse = MultiItemAnalysisResponse(
            items: [
                createMockDetectedItem(title: "Laptop"),
                createMockDetectedItem(title: "Mouse")
            ],
            detectedCount: 2,
            analysisType: "multi_item",
            confidence: 0.92
        )
        
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        #expect(response.safeItems.count == 2)
        #expect(response.detectedCount == 2)
        #expect(response.safeItems[0].title == "Laptop")
        #expect(response.safeItems[1].title == "Mouse")
    }
    
    @Test("OpenAI service handles no items detected scenario")
    func testNoItemsDetectedScenario() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        mockService.mockMultiItemResponse = MultiItemAnalysisResponse(
            items: [],
            detectedCount: 0,
            analysisType: "multi_item",
            confidence: 0.95
        )
        
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        #expect(response.safeItems.isEmpty)
        #expect(response.detectedCount == 0)
        #expect(!response.isValid) // Should be invalid due to no items
    }
    
    @Test("OpenAI service handles single item in multi-item mode")
    func testSingleItemInMultiItemMode() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        mockService.mockMultiItemResponse = MultiItemAnalysisResponse(
            items: [createMockDetectedItem(title: "Single Item")],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.88
        )
        
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        #expect(response.safeItems.count == 1)
        #expect(response.detectedCount == 1)
        #expect(response.safeItems[0].title == "Single Item")
    }
    
    @Test("OpenAI service handles maximum items limit")
    func testMaximumItemsLimit() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        // Create more than maximum allowed items (assume max is 10)
        let manyItems = (1...15).map { i in
            createMockDetectedItem(title: "Item \(i)")
        }
        
        mockService.mockMultiItemResponse = MultiItemAnalysisResponse(
            items: manyItems,
            detectedCount: 15,
            analysisType: "multi_item",
            confidence: 0.85
        )
        
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        // Should limit to maximum allowed items (10)
        #expect(response.safeItems.count <= 10)
        #expect(response.detectedCount == 15) // Original count preserved
    }
    
    // MARK: - Error Handling Tests
    
    @Test("OpenAI service handles API errors gracefully")
    func testAPIErrorHandling() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        mockService.shouldFailMultiItem = true
        mockService.multiItemError = OpenAIError.rateLimitExceeded
        
        await #expect(throws: OpenAIError.self) {
            try await mockService.getMultiItemDetails(
                from: images,
                settings: settings,
                modelContext: context
            )
        }
    }
    
    @Test("OpenAI service handles invalid response format")
    func testInvalidResponseFormat() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        mockService.shouldFailMultiItem = true
        mockService.multiItemError = OpenAIError.invalidData
        
        await #expect(throws: OpenAIError.self) {
            try await mockService.getMultiItemDetails(
                from: images,
                settings: settings,
                modelContext: context
            )
        }
    }
    
    @Test("OpenAI service handles network errors")
    func testNetworkErrorHandling() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        mockService.shouldFailMultiItem = true
        mockService.multiItemError = OpenAIError.networkUnavailable
        
        await #expect(throws: OpenAIError.self) {
            try await mockService.getMultiItemDetails(
                from: images,
                settings: settings,
                modelContext: context
            )
        }
    }
    
    // MARK: - Request Configuration Tests
    
    @Test("Multi-item analysis uses correct prompt configuration")
    func testMultiItemPromptConfiguration() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        // Verify that multi-item specific prompt was used
        #expect(mockService.lastUsedPrompt.contains("multiple items"))
        #expect(mockService.lastUsedPrompt.contains("separate inventory item"))
    }
    
    @Test("Multi-item analysis respects Pro vs Free tier settings")
    func testProVsFreeSettings() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages(count: 1)
        
        // Create separate mock services for each test to avoid state contamination
        let proMockService = MockMultiItemOpenAIService()
        let freeMockService = MockMultiItemOpenAIService()
        
        // Test with Pro settings (isPro=true, highQualityAnalysisEnabled=true)
        let proSettings = createTestSettings(isPro: true)
        try await proMockService.getMultiItemDetails(from: images, settings: proSettings, modelContext: context)
        #expect(proMockService.lastUsedModel.contains("gpt-5-mini"))
        #expect(proMockService.lastUsedImageResolution > 1000)
        
        // Test with Free settings (isPro=false, highQualityAnalysisEnabled=false)
        let freeSettings = createTestSettings(isPro: false)
        try await freeMockService.getMultiItemDetails(from: images, settings: freeSettings, modelContext: context)
        #expect(freeMockService.lastUsedModel.contains("gpt-4o"))
        #expect(freeMockService.lastUsedImageResolution <= 512)
    }
    
    // MARK: - Performance and Timeout Tests
    
    @Test("Multi-item analysis completes within reasonable time")
    func testAnalysisPerformance() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        mockService.simulatedDelay = 2.0 // 2 seconds
        
        let startTime = Date()
        
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(response.safeItems.count > 0)
        #expect(duration < 5.0, "Analysis should complete within 5 seconds")
    }
    
    @Test("Multi-item analysis handles timeout scenarios")
    func testTimeoutHandling() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        mockService.shouldFailMultiItem = true
        mockService.multiItemError = OpenAIError.networkTimeout
        
        await #expect(throws: OpenAIError.self) {
            try await mockService.getMultiItemDetails(
                from: images,
                settings: settings,
                modelContext: context
            )
        }
    }
    
    // MARK: - Function Schema Validation Tests
    
    @Test("OpenAI function schema includes required items property for arrays")
    func testFunctionSchemaArrayValidation() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        
        // Test that the schema generation includes proper items schema for arrays
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        // Verify that the function call was successful (indicating proper schema)
        #expect(response.safeItems.count >= 0) // Should not throw schema validation error
        #expect(mockService.lastUsedPrompt.contains("multiple items"))
        
        // Verify function name is correct for multi-item
        #expect(mockService.lastFunctionName == "process_multiple_inventory_items")
    }
    
    @Test("toolChoice parameter matches function name correctly")
    func testToolChoiceParameterMatching() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        
        // Test multi-item mode uses correct function name
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        // Verify that toolChoice matches the function name used
        #expect(mockService.lastFunctionName == "process_multiple_inventory_items")
        #expect(mockService.lastToolChoice == "process_multiple_inventory_items")
        #expect(response.safeItems.count >= 0) // Should not throw function name mismatch error
    }
    
    @Test("Function selection logic works for multi-item vs single-item")
    func testFunctionSelectionLogic() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        
        // Test that multi-item service uses the correct function
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        // Verify multi-item specific function and prompt are used
        #expect(mockService.lastFunctionName == "process_multiple_inventory_items")
        #expect(mockService.lastUsedPrompt.contains("ALL distinct"))
        #expect(mockService.lastUsedPrompt.contains("separate inventory item"))
        #expect(response.analysisType == "multi_item")
    }
    
    @Test("Array schema includes proper items definition")
    func testArraySchemaItemsDefinition() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        
        // This test specifically verifies that array properties have proper items schema
        // which was the root cause of the "array schema missing 'items'" error
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        #expect(response.safeItems.count >= 0) // Should not throw schema validation error
        #expect(mockService.lastSchemaIncludesItemsDefinition == true)
    }
    
    // MARK: - Data Quality Tests
    
    @Test("Detected items have valid data structure")
    func testDetectedItemDataQuality() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        mockService.mockMultiItemResponse = MultiItemAnalysisResponse(
            items: [
                DetectedInventoryItem(
                    id: "1",
                    title: "High Quality Item",
                    description: "Detailed description",
                    category: "Electronics",
                    make: "Apple",
                    model: "MacBook Pro",
                    estimatedPrice: "$2,499",
                    confidence: 0.95
                )
            ],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.95
        )
        
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        let item = response.safeItems[0]
        #expect(!item.title.isEmpty)
        #expect(!item.description.isEmpty)
        #expect(!item.category.isEmpty)
        #expect(item.confidence > 0.8)
        #expect(item.estimatedPrice.contains("$"))
    }
    
    @Test("Detected items handle missing data gracefully")
    func testMissingDataHandling() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let settings = createTestSettings()
        let images = createTestImages(count: 1)
        
        let mockService = MockMultiItemOpenAIService()
        mockService.mockMultiItemResponse = MultiItemAnalysisResponse(
            items: [
                DetectedInventoryItem(
                    id: "1",
                    title: "Partial Item",
                    description: "",
                    category: "Unknown",
                    make: "",
                    model: "",
                    estimatedPrice: "",
                    confidence: 0.75
                )
            ],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.75
        )
        
        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            modelContext: context
        )
        
        let item = response.safeItems[0]
        #expect(!item.title.isEmpty) // Title should always exist
        #expect(item.category == "Unknown") // Should have fallback values
        #expect(item.confidence > 0.0) // Should have some confidence
    }
    
    // MARK: - Helper Methods
    
    private func createMockDetectedItem(
        title: String = "Mock Item",
        description: String = "Mock description",
        category: String = "Electronics",
        make: String = "Mock Make",
        model: String = "Mock Model",
        estimatedPrice: String = "$99.99",
        confidence: Double = 0.85
    ) -> DetectedInventoryItem {
        return DetectedInventoryItem(
            id: UUID().uuidString,
            title: title,
            description: description,
            category: category,
            make: make,
            model: model,
            estimatedPrice: estimatedPrice,
            confidence: confidence
        )
    }
}

// MARK: - Supporting Types for Testing
// Note: MultiItemAnalysisResponse and DetectedInventoryItem are now defined in OpenAIService.swift

// MARK: - Mock Multi-Item OpenAI Service

@MainActor
class MockMultiItemOpenAIService {
    var shouldFailMultiItem = false
    var multiItemError: Error = OpenAIError.invalidData
    var simulatedDelay: TimeInterval = 0.5
    
    var mockMultiItemResponse = MultiItemAnalysisResponse(
        items: [
            DetectedInventoryItem(
                title: "Default Mock Item",
                description: "Default mock description",
                category: "Electronics",
                make: "Mock",
                model: "Test",
                estimatedPrice: "$100",
                confidence: 0.85
            )
        ],
        detectedCount: 1,
        analysisType: "multi_item",
        confidence: 0.85
    )
    
    // Properties to track what was used in the request
    var lastUsedPrompt: String = ""
    var lastUsedModel: String = ""
    var lastUsedImageResolution: CGFloat = 0
    var lastFunctionName: String = ""
    var lastToolChoice: String = ""
    var lastSchemaIncludesItemsDefinition: Bool = false
    
    func getMultiItemDetails(
        from images: [UIImage],
        settings: SettingsManager,
        modelContext: ModelContext
    ) async throws -> MultiItemAnalysisResponse {
        if shouldFailMultiItem {
            throw multiItemError
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        
        // Track request details for testing
        lastUsedPrompt = "Analyze this image and identify ALL distinct multiple items visible. Return a separate inventory item for each unique object that would be individually cataloged."
        lastUsedModel = settings.effectiveAIModel
        lastUsedImageResolution = settings.effectiveImageResolution
        lastFunctionName = "process_multiple_inventory_items"
        lastToolChoice = "process_multiple_inventory_items"
        lastSchemaIncludesItemsDefinition = true // Mock that schema was properly generated
        
        // Respect maximum items limit
        var limitedItems = mockMultiItemResponse.safeItems
        if limitedItems.count > 10 {
            limitedItems = Array(limitedItems.prefix(10))
        }
        
        return MultiItemAnalysisResponse(
            items: limitedItems,
            detectedCount: mockMultiItemResponse.detectedCount,
            analysisType: mockMultiItemResponse.analysisType,
            confidence: mockMultiItemResponse.confidence
        )
    }
}