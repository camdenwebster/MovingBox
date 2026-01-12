//
//  BatchItemCreationTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 9/25/25.
//

import SwiftData
import SwiftUI
import Testing

@testable import MovingBox

@Suite("Batch Item Creation Tests")
struct BatchItemCreationTests {

    // MARK: - Test Infrastructure

    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func createTestImages() -> [UIImage] {
        let image1 = UIImage(systemName: "photo") ?? UIImage()
        let image2 = UIImage(systemName: "camera") ?? UIImage()
        return [image1, image2]
    }

    @MainActor
    private func createTestLocation() -> InventoryLocation {
        return InventoryLocation(name: "Test Room", desc: "Test room description")
    }

    private func createTestDetectedItems() -> [DetectedInventoryItem] {
        return [
            DetectedInventoryItem(
                id: "item1",
                title: "MacBook Pro",
                description: "Apple laptop computer",
                category: "Electronics",
                make: "Apple",
                model: "MacBook Pro 14-inch",
                estimatedPrice: "$2499",
                confidence: 0.95
            ),
            DetectedInventoryItem(
                id: "item2",
                title: "iPhone",
                description: "Smartphone device",
                category: "Electronics",
                make: "Apple",
                model: "iPhone 15 Pro",
                estimatedPrice: "$999",
                confidence: 0.88
            ),
            DetectedInventoryItem(
                id: "item3",
                title: "iPad",
                description: "Tablet computer",
                category: "Electronics",
                make: "Apple",
                model: "iPad Pro",
                estimatedPrice: "$1099",
                confidence: 0.92
            ),
        ]
    }

    // MARK: - Data Model Tests

    @Test("DetectedInventoryItem initializes correctly")
    func testDetectedInventoryItemInitialization() async throws {
        let detectedItem = DetectedInventoryItem(
            id: "test-item",
            title: "Test Item",
            description: "Test description",
            category: "Test Category",
            make: "Test Make",
            model: "Test Model",
            estimatedPrice: "$100",
            confidence: 0.85
        )

        #expect(detectedItem.id == "test-item")
        #expect(detectedItem.title == "Test Item")
        #expect(detectedItem.description == "Test description")
        #expect(detectedItem.category == "Test Category")
        #expect(detectedItem.make == "Test Make")
        #expect(detectedItem.model == "Test Model")
        #expect(detectedItem.estimatedPrice == "$100")
        #expect(detectedItem.confidence == 0.85)
    }

    @Test("MultiItemAnalysisResponse handles empty items")
    func testEmptyMultiItemAnalysisResponse() async throws {
        let emptyResponse = MultiItemAnalysisResponse(
            items: [],
            detectedCount: 0,
            analysisType: "multi_item",
            confidence: 0.0
        )

        #expect(emptyResponse.safeItems.isEmpty)
        #expect(emptyResponse.detectedCount == 0)
        #expect(emptyResponse.analysisType == "multi_item")
        #expect(emptyResponse.confidence == 0.0)
    }

    @Test("MultiItemAnalysisResponse with multiple items")
    func testMultiItemAnalysisResponseWithItems() async throws {
        let detectedItems = createTestDetectedItems()
        let response = MultiItemAnalysisResponse(
            items: detectedItems,
            detectedCount: detectedItems.count,
            analysisType: "multi_item",
            confidence: 0.90
        )

        #expect(response.safeItems.count == 3)
        #expect(response.detectedCount == 3)
        #expect(response.confidence == 0.90)
        #expect(response.safeItems[0].title == "MacBook Pro")
        #expect(response.safeItems[1].title == "iPhone")
        #expect(response.safeItems[2].title == "iPad")
    }

    // MARK: - Batch Creation Tests

    @Test("Batch create inventory items from detected items")
    @MainActor
    func testBatchCreateInventoryItems() async throws {
        let container = try createTestContainer()
        let modelContext = container.mainContext
        let location = createTestLocation()
        let detectedItems = createTestDetectedItems()
        let images = createTestImages()

        // Insert test location
        modelContext.insert(location)
        try modelContext.save()

        // Create ViewModel for batch creation
        let viewModel = await ItemCreationFlowViewModel(
            captureMode: .multiItem,
            location: location,
            modelContext: modelContext
        )

        // Set up detected items for batch creation
        viewModel.multiItemAnalysisResponse = MultiItemAnalysisResponse(
            items: detectedItems,
            detectedCount: detectedItems.count,
            analysisType: "multi_item",
            confidence: 0.90
        )
        viewModel.selectedMultiItems = detectedItems
        viewModel.capturedImages = images

        // Perform batch creation
        let createdItems = try await viewModel.processSelectedMultiItems()

        // Verify results
        #expect(createdItems.count == 3)
        #expect(createdItems[0].title == "MacBook Pro")
        #expect(createdItems[0].make == "Apple")
        #expect(createdItems[0].model == "MacBook Pro 14-inch")
        #expect(createdItems[0].location?.name == "Test Room")

        #expect(createdItems[1].title == "iPhone")
        #expect(createdItems[1].make == "Apple")
        #expect(createdItems[1].model == "iPhone 15 Pro")

        #expect(createdItems[2].title == "iPad")
        #expect(createdItems[2].make == "Apple")
        #expect(createdItems[2].model == "iPad Pro")

        // Verify all items were saved to context
        let savedItems = try modelContext.fetch(FetchDescriptor<InventoryItem>())
        #expect(savedItems.count == 3)
    }

    @Test("Batch creation with empty selection")
    @MainActor
    func testBatchCreationWithEmptySelection() async throws {
        let container = try createTestContainer()
        let modelContext = container.mainContext
        let location = createTestLocation()

        let viewModel = await ItemCreationFlowViewModel(
            captureMode: .multiItem,
            location: location,
            modelContext: modelContext
        )

        // Empty selection should return empty array
        viewModel.selectedMultiItems = []
        viewModel.capturedImages = createTestImages()

        let createdItems = try await viewModel.processSelectedMultiItems()
        #expect(createdItems.isEmpty)
    }

    @Test("Batch creation without images fails")
    @MainActor
    func testBatchCreationWithoutImages() async throws {
        let container = try createTestContainer()
        let modelContext = container.mainContext
        let location = createTestLocation()
        let detectedItems = createTestDetectedItems()

        let viewModel = await ItemCreationFlowViewModel(
            captureMode: .multiItem,
            location: location,
            modelContext: modelContext
        )

        viewModel.selectedMultiItems = detectedItems
        viewModel.capturedImages = []  // No images

        // Should throw error for no images
        await #expect(throws: InventoryItemCreationError.noImagesProvided) {
            try await viewModel.processSelectedMultiItems()
        }
    }

    @Test("Price parsing from various formats")
    @MainActor
    func testPriceParsingFromDetectedItems() async throws {
        let testCases: [(input: String, expected: Decimal)] = [
            ("$100", 100),
            ("$1,299.99", 1299.99),
            ("€50.00", 50.00),
            ("£25.50", 25.50),
            ("1500", 1500),
            ("$", 0),
            ("", 0),
            ("invalid", 0),
            ("$2,999", 2999),
        ]

        // Create a single container and context for all test cases to avoid overhead
        let container = try createTestContainer()
        let modelContext = container.mainContext
        let location = createTestLocation()

        // Create one set of test images to reuse
        let testImages = createTestImages()

        // Test all cases in a single batch to avoid repeated async overhead
        for (input, expected) in testCases {
            let detectedItem = DetectedInventoryItem(
                id: "price-test-\(UUID().uuidString)",
                title: "Price Test Item",
                description: "Test item for price parsing",
                category: "Test Category",
                make: "Test",
                model: "Model",
                estimatedPrice: input,
                confidence: 0.85
            )

            let viewModel = await ItemCreationFlowViewModel(
                captureMode: .multiItem,
                location: location,
                modelContext: modelContext
            )

            viewModel.selectedMultiItems = [detectedItem]
            viewModel.capturedImages = testImages

            let createdItems = try await viewModel.processSelectedMultiItems()
            #expect(createdItems.count == 1, "Failed to create item for input: \(input)")
            let actualPrice = createdItems[0].price
            #expect(
                actualPrice == expected,
                "Failed for input: \(input), expected: \(expected), got: \(actualPrice)")

            // Clean up immediately after each test to keep memory usage low
            for item in createdItems {
                modelContext.delete(item)
            }
            try modelContext.save()
        }
    }

    @Test("Batch creation preserves item order")
    @MainActor
    func testBatchCreationPreservesOrder() async throws {
        let container = try createTestContainer()
        let modelContext = container.mainContext
        let location = createTestLocation()

        // Create items with specific order
        let orderedItems = [
            DetectedInventoryItem(
                id: "first", title: "First Item", description: "", category: "Test", make: "", model: "",
                estimatedPrice: "", confidence: 0.9),
            DetectedInventoryItem(
                id: "second", title: "Second Item", description: "", category: "Test", make: "", model: "",
                estimatedPrice: "", confidence: 0.8),
            DetectedInventoryItem(
                id: "third", title: "Third Item", description: "", category: "Test", make: "", model: "",
                estimatedPrice: "", confidence: 0.7),
        ]

        let viewModel = await ItemCreationFlowViewModel(
            captureMode: .multiItem,
            location: location,
            modelContext: modelContext
        )

        viewModel.selectedMultiItems = orderedItems
        viewModel.capturedImages = createTestImages()

        let createdItems = try await viewModel.processSelectedMultiItems()

        #expect(createdItems.count == 3)
        #expect(createdItems[0].title == "First Item")
        #expect(createdItems[1].title == "Second Item")
        #expect(createdItems[2].title == "Third Item")
    }

    @Test("Batch creation with confidence notes")
    @MainActor
    func testBatchCreationWithConfidenceNotes() async throws {
        let container = try createTestContainer()
        let modelContext = container.mainContext
        let location = createTestLocation()

        let highConfidenceItem = DetectedInventoryItem(
            id: "high-conf",
            title: "High Confidence Item",
            description: "Very clear item",
            category: "Electronics",
            make: "Apple",
            model: "MacBook",
            estimatedPrice: "$2000",
            confidence: 0.98
        )

        let lowConfidenceItem = DetectedInventoryItem(
            id: "low-conf",
            title: "Low Confidence Item",
            description: "Unclear item",
            category: "Unknown",
            make: "Unknown",
            model: "Unknown",
            estimatedPrice: "$100",
            confidence: 0.45
        )

        let viewModel = await ItemCreationFlowViewModel(
            captureMode: .multiItem,
            location: location,
            modelContext: modelContext
        )

        viewModel.selectedMultiItems = [highConfidenceItem, lowConfidenceItem]
        viewModel.capturedImages = createTestImages()

        let createdItems = try await viewModel.processSelectedMultiItems()

        #expect(createdItems.count == 2)
        #expect(createdItems[0].notes.contains("98% confidence"))
        #expect(createdItems[1].notes.contains("45% confidence"))
    }

    // MARK: - Integration Tests

    @Test("Full multi-item workflow integration")
    @MainActor
    func testFullMultiItemWorkflow() async throws {
        let container = try createTestContainer()
        let modelContext = container.mainContext
        let location = createTestLocation()
        let detectedItems = createTestDetectedItems()
        let images = createTestImages()

        // Insert test location
        modelContext.insert(location)
        try modelContext.save()

        // Create ViewModel
        let viewModel = await ItemCreationFlowViewModel(
            captureMode: .multiItem,
            location: location,
            modelContext: modelContext
        )

        // Step 1: Handle captured images
        await viewModel.handleCapturedImages(images)
        #expect(viewModel.capturedImages.count == 2)

        // Step 2: Simulate multi-item analysis completion
        viewModel.multiItemAnalysisResponse = MultiItemAnalysisResponse(
            items: detectedItems,
            detectedCount: detectedItems.count,
            analysisType: "multi_item",
            confidence: 0.90
        )
        viewModel.analysisComplete = true

        // Step 3: Navigate to selection step
        #expect(viewModel.isReadyForNextStep == true)
        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .multiItemSelection)

        // Step 4: Select items for creation
        viewModel.selectedMultiItems = Array(detectedItems.prefix(2))  // Select first 2 items
        #expect(viewModel.isReadyForNextStep == true)

        // Step 5: Process selected items
        let createdItems = try await viewModel.processSelectedMultiItems()
        #expect(createdItems.count == 2)
        #expect(!viewModel.createdItems.isEmpty)

        // Step 6: Navigate to details
        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .details)

        // Verify final state
        let savedItems = try modelContext.fetch(FetchDescriptor<InventoryItem>())
        #expect(savedItems.count == 2)
        #expect(savedItems.allSatisfy { $0.location?.name == "Test Room" })
    }

    @Test("Error handling in batch creation")
    @MainActor
    func testErrorHandlingInBatchCreation() async throws {
        let container = try createTestContainer()
        let modelContext = container.mainContext

        let viewModel = await ItemCreationFlowViewModel(
            captureMode: .multiItem,
            location: nil,  // No location
            modelContext: modelContext
        )

        let detectedItems = createTestDetectedItems()
        viewModel.selectedMultiItems = detectedItems
        viewModel.capturedImages = createTestImages()

        // Should handle missing location gracefully
        let createdItems = try await viewModel.processSelectedMultiItems()
        #expect(createdItems.count == 3)
        #expect(createdItems.allSatisfy { $0.location == nil })
    }

    @Test("Batch creation performance with many items")
    @MainActor
    func testBatchCreationPerformance() async throws {
        let container = try createTestContainer()
        let modelContext = container.mainContext
        let location = createTestLocation()

        // Create many detected items (simulate complex photo)
        let manyItems = (1...20).map { index in
            DetectedInventoryItem(
                id: "item-\(index)",
                title: "Item \(index)",
                description: "Test item number \(index)",
                category: "Category\(index % 3)",
                make: "Brand\(index % 5)",
                model: "Model\(index)",
                estimatedPrice: "$\(index * 10)",
                confidence: Double.random(in: 0.6...0.95)
            )
        }

        let viewModel = await ItemCreationFlowViewModel(
            captureMode: .multiItem,
            location: location,
            modelContext: modelContext
        )

        viewModel.selectedMultiItems = manyItems
        viewModel.capturedImages = createTestImages()

        // Measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let createdItems = try await viewModel.processSelectedMultiItems()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(createdItems.count == 20)
        #expect(timeElapsed < 5.0)  // Should complete within 5 seconds

        // Verify all items were saved
        let savedItems = try modelContext.fetch(FetchDescriptor<InventoryItem>())
        #expect(savedItems.count == 20)
    }
}
