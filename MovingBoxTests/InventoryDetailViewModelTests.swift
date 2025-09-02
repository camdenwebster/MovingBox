//
//  InventoryDetailViewModelTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 9/2/25.
//

import Testing
import SwiftUI
import SwiftData
@testable import MovingBox

@MainActor
@Suite("InventoryDetailViewModel Tests")
struct InventoryDetailViewModelTests {
    
    private func makeTestContainer() -> ModelContainer {
        let schema = Schema([
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            Home.self,
            InsurancePolicy.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    @Test("ViewModel initializes with item properties")
    func testViewModelInitialization() async {
        let container = makeTestContainer()
        let item = InventoryItem(title: "Test Item", quantityString: "1", quantityInt: 1)
        let viewModel = InventoryDetailViewModel(item: item, modelContext: container.mainContext)
        
        #expect(viewModel.title == "Test Item")
        #expect(viewModel.quantity == 1)
        #expect(viewModel.isEditing == false)
    }
    
    @Test("Edit mode toggles correctly")
    func testEditModeToggle() async {
        let container = makeTestContainer()
        let item = InventoryItem(title: "Test Item", quantityString: "1", quantityInt: 1)
        let viewModel = InventoryDetailViewModel(item: item, modelContext: container.mainContext)
        
        #expect(viewModel.isEditing == false)
        
        viewModel.toggleEditMode()
        #expect(viewModel.isEditing == true)
        
        viewModel.toggleEditMode()
        #expect(viewModel.isEditing == false)
    }
    
    @Test("Save functionality updates model context")
    func testSaveUpdatesModel() async {
        let container = makeTestContainer()
        let item = InventoryItem(title: "Test Item", quantityString: "1", quantityInt: 1)
        container.mainContext.insert(item)
        
        let viewModel = InventoryDetailViewModel(item: item, modelContext: container.mainContext)
        viewModel.title = "Updated Title"
        
        viewModel.save()
        
        #expect(item.title == "Updated Title")
    }
    
    @Test("Photo count validation works correctly")
    func testPhotoCountValidation() async {
        let container = makeTestContainer()
        let item = InventoryItem(title: "Test Item", quantityString: "1", quantityInt: 1)
        let viewModel = InventoryDetailViewModel(item: item, modelContext: container.mainContext)
        
        #expect(viewModel.canAddMorePhotos == true)
        
        // Simulate having 5 photos (max limit)
        item.secondaryPhotoURLs = ["url1", "url2", "url3", "url4"]
        item.imageURL = URL(string: "http://example.com/image.jpg")
        
        #expect(viewModel.currentPhotoCount == 5)
        #expect(viewModel.canAddMorePhotos == false)
    }
    
    @Test("Price formatting works correctly")
    func testPriceFormatting() async {
        let container = makeTestContainer()
        let item = InventoryItem(title: "Test Item", quantityString: "1", quantityInt: 1)
        let viewModel = InventoryDetailViewModel(item: item, modelContext: container.mainContext)
        
        let price = Decimal(99.99)
        let formatted = viewModel.formatPrice(price)
        
        #expect(formatted == "99.99")
    }
    
    @Test("AI analysis availability check")
    func testAIAnalysisAvailability() async {
        let container = makeTestContainer()
        let item = InventoryItem(title: "Test Item", quantityString: "1", quantityInt: 1)
        let viewModel = InventoryDetailViewModel(item: item, modelContext: container.mainContext)
        
        // Should not show AI button without image
        #expect(viewModel.shouldShowAIButton == false)
        
        // Should show AI button with image and hasn't used AI
        item.imageURL = URL(string: "http://example.com/image.jpg")
        viewModel.isEditing = true
        #expect(viewModel.shouldShowAIButton == true)
        
        // Should not show AI button if already used AI
        item.hasUsedAI = true
        #expect(viewModel.shouldShowAIButton == false)
    }
    
    @Test("Error handling for AI analysis")
    func testAIAnalysisErrorHandling() async {
        let container = makeTestContainer()
        let item = InventoryItem(title: "Test Item", quantityString: "1", quantityInt: 1)
        let mockOpenAI = MockOpenAIService(shouldThrowError: true)
        let viewModel = InventoryDetailViewModel(item: item, modelContext: container.mainContext, openAIService: mockOpenAI)
        
        await viewModel.performAIAnalysis()
        
        #expect(viewModel.showingErrorAlert == true)
        #expect(!viewModel.errorMessage.isEmpty)
    }
    
    @Test("Successful AI analysis updates item properties")
    func testSuccessfulAIAnalysis() async {
        let container = makeTestContainer()
        let item = InventoryItem(title: "Test Item", quantityString: "1", quantityInt: 1)
        let mockImageDetails = ImageDetails(
            title: "AI Title",
            quantity: "2",
            description: "AI Description",
            make: "AI Make",
            model: "AI Model",
            category: "Electronics",
            location: "Office",
            price: "$199.99",
            serialNumber: "AI12345"
        )
        let mockOpenAI = MockOpenAIService(mockImageDetails: mockImageDetails)
        let viewModel = InventoryDetailViewModel(item: item, modelContext: container.mainContext, openAIService: mockOpenAI)
        
        await viewModel.performAIAnalysis()
        
        #expect(viewModel.title == "AI Title")
        #expect(viewModel.quantity == 2)
        #expect(viewModel.itemDescription == "AI Description")
        #expect(viewModel.make == "AI Make")
        #expect(viewModel.model == "AI Model")
        #expect(item.hasUsedAI == true)
    }
}

// MARK: - Mock Services for Testing

class MockOpenAIService: OpenAIServiceProtocol {
    let shouldThrowError: Bool
    let mockImageDetails: ImageDetails?
    
    init(shouldThrowError: Bool = false, mockImageDetails: ImageDetails? = nil) {
        self.shouldThrowError = shouldThrowError
        self.mockImageDetails = mockImageDetails
    }
    
    func getImageDetails() async throws -> ImageDetails {
        if shouldThrowError {
            throw OpenAIError.invalidResponse
        }
        return mockImageDetails ?? ImageDetails(title: "", quantity: "", description: "", make: "", model: "", category: "", location: "", price: "", serialNumber: "")
    }
}

// MARK: - OpenAI Service Protocol

protocol OpenAIServiceProtocol {
    func getImageDetails() async throws -> ImageDetails
}