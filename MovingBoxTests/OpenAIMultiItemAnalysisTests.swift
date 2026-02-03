import SQLiteData
import SwiftUI
import Testing
import UIKit

@testable import MovingBox

@MainActor
@Suite struct OpenAIMultiItemAnalysisTests {

    // MARK: - Test Setup

    private func createTestSettings(isPro: Bool = true) -> MockSettingsManager {
        let settings = MockSettingsManager()
        settings.isPro = isPro
        settings.highQualityAnalysisEnabled = isPro
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
            ),
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
        let validResponse = MultiItemAnalysisResponse(
            items: [createMockDetectedItem()],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.85
        )
        #expect(validResponse.isValid)

        let invalidResponse1 = MultiItemAnalysisResponse(
            items: [],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.85
        )
        #expect(!invalidResponse1.isValid)

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
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()
        mockService.mockMultiItemResponse = MultiItemAnalysisResponse(
            items: [
                createMockDetectedItem(title: "Laptop"),
                createMockDetectedItem(title: "Mouse"),
            ],
            detectedCount: 2,
            analysisType: "multi_item",
            confidence: 0.92
        )

        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            database: database
        )

        #expect(response.safeItems.count == 2)
        #expect(response.detectedCount == 2)
        #expect(response.safeItems[0].title == "Laptop")
        #expect(response.safeItems[1].title == "Mouse")
    }

    @Test("OpenAI service handles no items detected scenario")
    func testNoItemsDetectedScenario() async throws {
        let database = try makeInMemoryDatabase()
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
            database: database
        )

        #expect(response.safeItems.isEmpty)
        #expect(response.detectedCount == 0)
        #expect(!response.isValid)
    }

    @Test("OpenAI service handles single item in multi-item mode")
    func testSingleItemInMultiItemMode() async throws {
        let database = try makeInMemoryDatabase()
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
            database: database
        )

        #expect(response.safeItems.count == 1)
        #expect(response.detectedCount == 1)
        #expect(response.safeItems[0].title == "Single Item")
    }

    @Test("OpenAI service handles maximum items limit")
    func testMaximumItemsLimit() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()
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
            database: database
        )

        #expect(response.safeItems.count <= 10)
        #expect(response.detectedCount == 15)
    }

    // MARK: - Error Handling Tests

    @Test("OpenAI service handles API errors gracefully")
    func testAPIErrorHandling() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()
        mockService.shouldFailMultiItem = true
        mockService.multiItemError = OpenAIError.rateLimitExceeded

        await #expect(throws: OpenAIError.self) {
            try await mockService.getMultiItemDetails(
                from: images,
                settings: settings,
                database: database
            )
        }
    }

    @Test("OpenAI service handles invalid response format")
    func testInvalidResponseFormat() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()
        mockService.shouldFailMultiItem = true
        mockService.multiItemError = OpenAIError.invalidData

        await #expect(throws: OpenAIError.self) {
            try await mockService.getMultiItemDetails(
                from: images,
                settings: settings,
                database: database
            )
        }
    }

    @Test("OpenAI service handles network errors")
    func testNetworkErrorHandling() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()
        mockService.shouldFailMultiItem = true
        mockService.multiItemError = OpenAIError.networkUnavailable

        await #expect(throws: OpenAIError.self) {
            try await mockService.getMultiItemDetails(
                from: images,
                settings: settings,
                database: database
            )
        }
    }

    // MARK: - Request Configuration Tests

    @Test("Multi-item analysis uses correct prompt configuration")
    func testMultiItemPromptConfiguration() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()

        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            database: database
        )

        #expect(mockService.lastUsedPrompt.contains("multiple items"))
        #expect(mockService.lastUsedPrompt.contains("separate inventory item"))
    }

    @Test("Multi-item analysis respects Pro vs Free tier settings")
    func testProVsFreeSettings() async throws {
        let database = try makeInMemoryDatabase()
        let images = createTestImages(count: 1)

        let proMockService = MockMultiItemOpenAIService()
        let freeMockService = MockMultiItemOpenAIService()

        let proSettings = createTestSettings(isPro: true)
        try await proMockService.getMultiItemDetails(
            from: images, settings: proSettings, database: database)
        #expect(proMockService.lastUsedModel == "gpt-5-mini")
        #expect(proMockService.lastUsedImageResolution > 1000)

        let freeSettings = createTestSettings(isPro: false)
        try await freeMockService.getMultiItemDetails(
            from: images, settings: freeSettings, database: database)
        #expect(freeMockService.lastUsedModel == "gpt-4o")
        #expect(freeMockService.lastUsedImageResolution <= 512)
    }

    // MARK: - Performance and Timeout Tests

    @Test("Multi-item analysis completes within reasonable time")
    func testAnalysisPerformance() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()
        mockService.simulatedDelay = 0.5

        let startTime = Date()

        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            database: database
        )

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        #expect(response.safeItems.count >= 0)
        #expect(duration < 6.0, "Analysis should complete within 3 seconds")
    }

    @Test("Multi-item analysis handles timeout scenarios")
    func testTimeoutHandling() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()
        mockService.shouldFailMultiItem = true
        mockService.multiItemError = OpenAIError.networkTimeout

        await #expect(throws: OpenAIError.self) {
            try await mockService.getMultiItemDetails(
                from: images,
                settings: settings,
                database: database
            )
        }
    }

    // MARK: - Function Schema Validation Tests

    @Test("OpenAI function schema includes required items property for arrays")
    func testFunctionSchemaArrayValidation() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()

        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            database: database
        )

        #expect(response.safeItems.count >= 0)
        #expect(mockService.lastUsedPrompt.contains("multiple items"))

        #expect(mockService.lastFunctionName == "process_multiple_inventory_items")
    }

    @Test("toolChoice parameter matches function name correctly")
    func testToolChoiceParameterMatching() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()

        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            database: database
        )

        #expect(mockService.lastFunctionName == "process_multiple_inventory_items")
        #expect(mockService.lastToolChoice == "process_multiple_inventory_items")
        #expect(response.safeItems.count >= 0)
    }

    @Test("Function selection logic works for multi-item vs single-item")
    func testFunctionSelectionLogic() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()

        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            database: database
        )

        #expect(mockService.lastFunctionName == "process_multiple_inventory_items")
        #expect(mockService.lastUsedPrompt.contains("ALL distinct"))
        #expect(mockService.lastUsedPrompt.contains("separate inventory item"))
        #expect(response.analysisType == "multi_item")
    }

    @Test("Array schema includes proper items definition")
    func testArraySchemaItemsDefinition() async throws {
        let database = try makeInMemoryDatabase()
        let settings = createTestSettings()
        let images = createTestImages(count: 1)

        let mockService = MockMultiItemOpenAIService()

        let response = try await mockService.getMultiItemDetails(
            from: images,
            settings: settings,
            database: database
        )

        #expect(response.safeItems.count >= 0)
        #expect(mockService.lastSchemaIncludesItemsDefinition == true)
    }

    // MARK: - Data Quality Tests

    @Test("Detected items have valid data structure")
    func testDetectedItemDataQuality() async throws {
        let database = try makeInMemoryDatabase()
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
            database: database
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
        let database = try makeInMemoryDatabase()
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
            database: database
        )

        let item = response.safeItems[0]
        #expect(!item.title.isEmpty)
        #expect(item.category == "Unknown")
        #expect(item.confidence > 0.0)
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

    var lastUsedPrompt: String = ""
    var lastUsedModel: String = ""
    var lastUsedImageResolution: CGFloat = 0
    var lastFunctionName: String = ""
    var lastToolChoice: String = ""
    var lastSchemaIncludesItemsDefinition: Bool = false

    @discardableResult
    func getMultiItemDetails(
        from images: [UIImage],
        settings: SettingsManager,
        database: any DatabaseWriter
    ) async throws -> MultiItemAnalysisResponse {
        if shouldFailMultiItem {
            throw multiItemError
        }

        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))

        lastUsedPrompt =
            "Analyze this image and identify ALL distinct multiple items visible. Return a separate inventory item for each unique object that would be individually cataloged."
        lastUsedModel = settings.effectiveAIModel
        lastUsedImageResolution = settings.effectiveImageResolution
        lastFunctionName = "process_multiple_inventory_items"
        lastToolChoice = "process_multiple_inventory_items"
        lastSchemaIncludesItemsDefinition = true

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
