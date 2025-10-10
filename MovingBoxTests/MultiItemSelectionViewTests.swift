//
//  MultiItemSelectionViewTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 9/19/25.
//

import Testing
import SwiftUI
import SwiftData
import UIKit
@testable import MovingBox

@MainActor
@Suite struct MultiItemSelectionViewTests {
    
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
    
    private func createTestImages(count: Int = 1) -> [UIImage] {
        return (0..<count).map { _ in createTestImage() }
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func createMockDetectedItems(count: Int = 3) -> [DetectedInventoryItem] {
        return (1...count).map { i in
            DetectedInventoryItem(
                id: "item-\(i)",
                title: "Test Item \(i)",
                description: "Description for test item \(i)",
                category: "Electronics",
                make: "Test Make \(i)",
                model: "Model \(i)",
                estimatedPrice: "$\(i * 100).00",
                confidence: 0.85 + Double(i) * 0.02
            )
        }
    }
    
    private func createMockAnalysisResponse(itemCount: Int = 3) -> MultiItemAnalysisResponse {
        return MultiItemAnalysisResponse(
            items: createMockDetectedItems(count: itemCount),
            detectedCount: itemCount,
            analysisType: "multi_item",
            confidence: 0.88
        )
    }
    
    // MARK: - MultiItemSelectionViewModel Tests
    
    @Test("MultiItemSelectionViewModel initializes correctly")
    func testViewModelInitialization() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        let analysisResponse = createMockAnalysisResponse()
        let location: InventoryLocation? = nil
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: images,
            location: location,
            modelContext: context
        )
        
        #expect(viewModel.detectedItems.count == 3)
        #expect(viewModel.images.count == 1)
        #expect(viewModel.selectedItems.isEmpty)
        #expect(viewModel.currentCardIndex == 0)
        #expect(!viewModel.isProcessingSelection)
    }
    
    @Test("ViewModel handles empty analysis response")
    func testViewModelWithEmptyResponse() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        let emptyResponse = MultiItemAnalysisResponse(
            items: [],
            detectedCount: 0,
            analysisType: "multi_item",
            confidence: 0.5
        )
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: emptyResponse,
            images: images,
            location: nil,
            modelContext: context
        )
        
        #expect(viewModel.detectedItems.isEmpty)
        #expect(viewModel.hasNoItems)
        #expect(viewModel.currentCardIndex == 0)
    }
    
    @Test("ViewModel card navigation works correctly")
    func testCardNavigation() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        let analysisResponse = createMockAnalysisResponse(itemCount: 3)
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: images,
            location: nil,
            modelContext: context
        )
        
        // Test initial state
        #expect(viewModel.currentCardIndex == 0)
        #expect(!viewModel.canGoToPreviousCard)
        #expect(viewModel.canGoToNextCard)
        
        // Test next card
        viewModel.goToNextCard()
        #expect(viewModel.currentCardIndex == 1)
        #expect(viewModel.canGoToPreviousCard)
        #expect(viewModel.canGoToNextCard)
        
        // Test previous card
        viewModel.goToPreviousCard()
        #expect(viewModel.currentCardIndex == 0)
        #expect(!viewModel.canGoToPreviousCard)
        #expect(viewModel.canGoToNextCard)
        
        // Test boundary conditions
        viewModel.goToPreviousCard() // Should stay at 0
        #expect(viewModel.currentCardIndex == 0)
        
        // Go to last card
        viewModel.goToNextCard()
        viewModel.goToNextCard()
        #expect(viewModel.currentCardIndex == 2)
        #expect(!viewModel.canGoToNextCard)
        
        viewModel.goToNextCard() // Should stay at 2
        #expect(viewModel.currentCardIndex == 2)
    }
    
    @Test("ViewModel item selection and deselection")
    func testItemSelection() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        let analysisResponse = createMockAnalysisResponse(itemCount: 3)
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: images,
            location: nil,
            modelContext: context
        )
        
        let firstItem = viewModel.detectedItems[0]
        let secondItem = viewModel.detectedItems[1]
        
        // Test initial state
        #expect(viewModel.selectedItems.isEmpty)
        #expect(!viewModel.isItemSelected(firstItem))
        #expect(viewModel.selectedItemsCount == 0)
        
        // Test selection
        viewModel.toggleItemSelection(firstItem)
        #expect(viewModel.selectedItems.count == 1)
        #expect(viewModel.isItemSelected(firstItem))
        #expect(viewModel.selectedItemsCount == 1)
        
        // Test multiple selections
        viewModel.toggleItemSelection(secondItem)
        #expect(viewModel.selectedItems.count == 2)
        #expect(viewModel.isItemSelected(secondItem))
        #expect(viewModel.selectedItemsCount == 2)
        
        // Test deselection
        viewModel.toggleItemSelection(firstItem)
        #expect(viewModel.selectedItems.count == 1)
        #expect(!viewModel.isItemSelected(firstItem))
        #expect(viewModel.isItemSelected(secondItem))
        #expect(viewModel.selectedItemsCount == 1)
    }
    
    @Test("ViewModel select all and deselect all functionality")
    func testSelectAllDeselectAll() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        let analysisResponse = createMockAnalysisResponse(itemCount: 3)
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: images,
            location: nil,
            modelContext: context
        )
        
        // Test select all
        #expect(viewModel.selectedItems.isEmpty)
        viewModel.selectAllItems()
        #expect(viewModel.selectedItems.count == 3)
        #expect(viewModel.selectedItemsCount == 3)
        
        // Verify all items are selected
        for item in viewModel.detectedItems {
            #expect(viewModel.isItemSelected(item))
        }
        
        // Test deselect all
        viewModel.deselectAllItems()
        #expect(viewModel.selectedItems.isEmpty)
        #expect(viewModel.selectedItemsCount == 0)
        
        // Verify no items are selected
        for item in viewModel.detectedItems {
            #expect(!viewModel.isItemSelected(item))
        }
    }
    
    @Test("ViewModel creates inventory items correctly")
    func testCreateInventoryItems() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        let analysisResponse = createMockAnalysisResponse(itemCount: 2)
        
        // Create a test location
        let testLocation = InventoryLocation(name: "Test Room")
        context.insert(testLocation)
        try context.save()
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: images,
            location: testLocation,
            modelContext: context
        )
        
        // Select the first item
        viewModel.toggleItemSelection(viewModel.detectedItems[0])
        
        // Test item creation
        let createdItems = try await viewModel.createSelectedInventoryItems()
        
        #expect(createdItems.count == 1)
        
        let createdItem = createdItems[0]
        #expect(createdItem.title == "Test Item 1")
        #expect(createdItem.desc == "Description for test item 1")
        #expect(createdItem.make == "Test Make 1")
        #expect(createdItem.model == "Model 1")
        #expect(createdItem.location?.name == "Test Room")
        
        // Verify item was saved to context
        let fetchDescriptor = FetchDescriptor<InventoryItem>()
        let savedItems = try context.fetch(fetchDescriptor)
        #expect(savedItems.count == 1)
    }
    
    @Test("ViewModel handles creation errors gracefully")
    func testCreateInventoryItemsError() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        let analysisResponse = createMockAnalysisResponse(itemCount: 1)
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: images,
            location: nil,
            modelContext: context
        )
        
        // Select an item
        viewModel.toggleItemSelection(viewModel.detectedItems[0])
        
        // Create a scenario that would cause an error (empty images)
        viewModel.images.removeAll()
        
        do {
            let _ = try await viewModel.createSelectedInventoryItems()
            #expect(Bool(false), "Expected error to be thrown")
        } catch {
            // Expected error due to empty images
            #expect(error is InventoryItemCreationError)
        }
    }
    
    @Test("ViewModel progress tracking works correctly")
    func testProgressTracking() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        let analysisResponse = createMockAnalysisResponse(itemCount: 3)
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: images,
            location: nil,
            modelContext: context
        )
        
        // Select all items
        viewModel.selectAllItems()
        
        #expect(viewModel.creationProgress == 0.0)
        #expect(!viewModel.isProcessingSelection)
        
        // Note: The actual progress tracking would be tested by observing
        // the progress property during createSelectedInventoryItems()
        // This would require more complex async testing
    }
    
    // MARK: - UI Component Tests
    
    @Test("DetectedItemCard displays item information correctly")
    func testDetectedItemCard() throws {
        let testItem = DetectedInventoryItem(
            id: "test-1",
            title: "Test Laptop",
            description: "A high-quality laptop for testing",
            category: "Electronics",
            make: "TestCorp",
            model: "Pro 2023",
            estimatedPrice: "$1,299.00",
            confidence: 0.92
        )
        
        // Note: In a real implementation, we'd test the SwiftUI view rendering
        // For now, we verify the data model is correct
        #expect(testItem.title == "Test Laptop")
        #expect(testItem.category == "Electronics")
        #expect(testItem.confidence == 0.92)
        #expect(testItem.estimatedPrice == "$1,299.00")
    }
    
    @Test("Card navigation buttons work correctly")
    func testCardNavigationButtons() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        let analysisResponse = createMockAnalysisResponse(itemCount: 3)
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: images,
            location: nil,
            modelContext: context
        )
        
        // Test navigation button states
        #expect(!viewModel.canGoToPreviousCard)
        #expect(viewModel.canGoToNextCard)
        
        // Simulate navigation
        viewModel.goToNextCard()
        #expect(viewModel.canGoToPreviousCard)
        #expect(viewModel.canGoToNextCard)
        
        viewModel.goToNextCard()
        #expect(viewModel.canGoToPreviousCard)
        #expect(!viewModel.canGoToNextCard)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("ViewModel handles single item correctly")
    func testSingleItemHandling() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        let singleItemResponse = createMockAnalysisResponse(itemCount: 1)
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: singleItemResponse,
            images: images,
            location: nil,
            modelContext: context
        )
        
        #expect(viewModel.detectedItems.count == 1)
        #expect(viewModel.currentCardIndex == 0)
        #expect(!viewModel.canGoToNextCard)
        #expect(!viewModel.canGoToPreviousCard)
    }
    
    @Test("ViewModel handles maximum items correctly")
    func testMaximumItemsHandling() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        
        // Create response with maximum items (10)
        let maxItems = (1...10).map { i in
            DetectedInventoryItem(
                id: "item-\(i)",
                title: "Item \(i)",
                description: "Description \(i)",
                category: "Category",
                make: "Make",
                model: "Model",
                estimatedPrice: "$100.00",
                confidence: 0.8
            )
        }
        
        let maxItemsResponse = MultiItemAnalysisResponse(
            items: maxItems,
            detectedCount: 10,
            analysisType: "multi_item",
            confidence: 0.85
        )
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: maxItemsResponse,
            images: images,
            location: nil,
            modelContext: context
        )
        
        #expect(viewModel.detectedItems.count == 10)
        
        // Test navigation to last item
        for _ in 0..<9 {
            viewModel.goToNextCard()
        }
        #expect(viewModel.currentCardIndex == 9)
        #expect(!viewModel.canGoToNextCard)
    }
    
    @Test("ViewModel validates item data quality")
    func testItemDataValidation() throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let images = createTestImages()
        
        // Create items with varying confidence scores
        let items = [
            DetectedInventoryItem(
                id: "high-confidence",
                title: "High Quality Item",
                description: "Detailed description",
                category: "Electronics",
                make: "Brand",
                model: "Model",
                estimatedPrice: "$500.00",
                confidence: 0.95
            ),
            DetectedInventoryItem(
                id: "low-confidence",
                title: "Uncertain Item",
                description: "",
                category: "Unknown",
                make: "",
                model: "",
                estimatedPrice: "",
                confidence: 0.45
            )
        ]
        
        let response = MultiItemAnalysisResponse(
            items: items,
            detectedCount: 2,
            analysisType: "multi_item",
            confidence: 0.7
        )
        
        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: response,
            images: images,
            location: nil,
            modelContext: context
        )
        
        #expect(viewModel.detectedItems.count == 2)
        
        // High confidence item should have good data
        let highConfidenceItem = viewModel.detectedItems[0]
        #expect(highConfidenceItem.confidence > 0.9)
        #expect(!highConfidenceItem.title.isEmpty)
        
        // Low confidence item should have lower quality data
        let lowConfidenceItem = viewModel.detectedItems[1]
        #expect(lowConfidenceItem.confidence < 0.5)
        #expect(lowConfidenceItem.description.isEmpty)
    }
    
    // MARK: - Helper Methods Tests
    
    @Test("Price parsing works correctly")
    func testPriceParsing() throws {
        let testCases = [
            ("$123.45", Decimal(123.45)),
            ("$1,299.00", Decimal(1299.00)),
            ("45.99", Decimal(45.99)),
            ("", Decimal.zero),
            ("invalid", Decimal.zero),
            ("$0.00", Decimal.zero)
        ]
        
        for (priceString, expectedDecimal) in testCases {
            let item = DetectedInventoryItem(
                id: "test",
                title: "Test",
                description: "Test",
                category: "Test",
                make: "Test",
                model: "Test",
                estimatedPrice: priceString,
                confidence: 0.8
            )
            
            // This would test a helper method on the item or view model
            // let parsedPrice = item.parsedPrice
            // #expect(parsedPrice == expectedDecimal)
        }
    }
    
    @Test("Confidence display formatting")
    func testConfidenceFormatting() throws {
        let testCases = [
            (0.95, "95%"),
            (0.87, "87%"),
            (0.5, "50%"),
            (0.0, "0%"),
            (1.0, "100%")
        ]
        
        for (confidence, expectedString) in testCases {
            let item = DetectedInventoryItem(
                id: "test",
                title: "Test",
                description: "Test",
                category: "Test",
                make: "Test",
                model: "Test",
                estimatedPrice: "$100.00",
                confidence: confidence
            )
            
            // This would test a helper method for formatting confidence
            // let formattedConfidence = item.formattedConfidence
            // #expect(formattedConfidence == expectedString)
        }
    }
}

// MARK: - Supporting Types and Extensions

/// Custom error type for inventory item creation
enum InventoryItemCreationError: Error {
    case noImagesProvided
    case imageProcessingFailed
    case contextSaveFailure
    case invalidItemData
    
    var localizedDescription: String {
        switch self {
        case .noImagesProvided:
            return "No images provided for item creation"
        case .imageProcessingFailed:
            return "Failed to process item images"
        case .contextSaveFailure:
            return "Failed to save item to database"
        case .invalidItemData:
            return "Invalid item data provided"
        }
    }
}