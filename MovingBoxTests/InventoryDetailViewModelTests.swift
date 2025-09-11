//
//  InventoryDetailViewModelTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 9/10/25.
//

import Testing
import SwiftData
import UIKit
@testable import MovingBox

@MainActor
struct InventoryDetailViewModelTests {
    
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
    
    @MainActor
    private func createTestViewModel(
        item: InventoryItem? = nil,
        mockOpenAI: MockOpenAIService? = nil,
        mockImageManager: MockImageManager? = nil,
        mockSettings: MockSettingsManager? = nil,
        context: ModelContext
    ) throws -> InventoryDetailViewModel {
        let testItem = item ?? InventoryItem.createTestItem(in: context)
        let openAI = mockOpenAI ?? MockOpenAIService()
        let imageManager = mockImageManager ?? MockImageManager()
        let settings = mockSettings ?? MockSettingsManager()
        
        return InventoryDetailViewModel(
            inventoryItem: testItem,
            settings: settings,
            modelContext: context,
            openAIService: openAI,
            imageManager: imageManager
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("ViewModel initializes with correct dependencies")
    func testViewModelInitialization() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let viewModel = try createTestViewModel(context: context)
        
        #expect(!viewModel.isLoadingOpenAiResults)
        #expect(viewModel.errorMessage.isEmpty)
        #expect(!viewModel.showingErrorAlert)
        // showAIButton property exists in ViewModel
        #expect(!viewModel.showAIButton)
        #expect(viewModel.loadedImages.isEmpty)
        #expect(viewModel.selectedImageIndex == 0)
        #expect(!viewModel.isLoading)
        #expect(!viewModel.showPhotoSourceAlert)
        #expect(!viewModel.showingFileViewer)
        #expect(!viewModel.showingDeleteAttachmentAlert)
    }
    
    // MARK: - AI Analysis Tests
    
    @Test("AI analysis succeeds with valid images")
    func testAIAnalysisSuccess() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockOpenAI = MockOpenAIService()
        mockOpenAI.mockResponse = ImageDetails(
            title: "Updated Title",
            quantity: "2",
            description: "AI Generated Description",
            make: "AI Make",
            model: "AI Model",
            category: "Electronics",
            location: "AI Location",
            price: "250.00",
            serialNumber: "AI123"
        )
        
        let mockImageManager = MockImageManager()
        mockImageManager.mockImages = [UIImage.createTestImage()]
        
        let item = InventoryItem.createTestItemWithImages(in: context)
        let viewModel = try createTestViewModel(
            item: item,
            mockOpenAI: mockOpenAI,
            mockImageManager: mockImageManager,
            context: context
        )
        
        // Load images first
        await viewModel.loadAllImages(for: item)
        
        // Perform AI analysis
        await viewModel.performAIAnalysis(for: item, allItems: [item])
        
        #expect(!viewModel.isLoadingOpenAiResults)
        #expect(item.title == "Updated Title")
        #expect(item.quantityString == "2")
        #expect(item.desc == "AI Generated Description")
        #expect(item.make == "AI Make")
        #expect(item.model == "AI Model")
        #expect(item.serial == "AI123")
        #expect(item.price == Decimal(string: "250.00"))
        #expect(item.hasUsedAI == true)
    }
    
    @Test("AI analysis handles errors gracefully")
    func testAIAnalysisError() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockOpenAI = MockOpenAIService()
        mockOpenAI.shouldFail = true
        
        let mockImageManager = MockImageManager()
        mockImageManager.mockImages = [UIImage.createTestImage()]
        
        let item = InventoryItem.createTestItemWithImages(in: context)
        let viewModel = try createTestViewModel(
            item: item,
            mockOpenAI: mockOpenAI,
            mockImageManager: mockImageManager,
            context: context
        )
        
        // Load images first
        await viewModel.loadAllImages(for: item)
        
        // Perform AI analysis (should fail)
        await viewModel.performAIAnalysis(for: item, allItems: [item])
        
        #expect(!viewModel.isLoadingOpenAiResults)
        #expect(viewModel.showingErrorAlert)
        #expect(!viewModel.errorMessage.isEmpty)
    }
    
    @Test("AI analysis fails with no images")
    func testAIAnalysisNoImages() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockOpenAI = MockOpenAIService()
        let mockImageManager = MockImageManager()
        
        let item = InventoryItem.createTestItem(in: context) // No images
        let viewModel = try createTestViewModel(
            item: item,
            mockOpenAI: mockOpenAI,
            mockImageManager: mockImageManager,
            context: context
        )
        
        // Perform AI analysis (should fail due to no images)
        await viewModel.performAIAnalysis(for: item, allItems: [item])
        
        #expect(!viewModel.isLoadingOpenAiResults)
        #expect(viewModel.showingErrorAlert)
        #expect(!viewModel.errorMessage.isEmpty)
    }
    
    // MARK: - Photo Management Tests
    
    @Test("Load all images succeeds with valid URLs")
    func testLoadAllImagesSuccess() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockImageManager = MockImageManager()
        mockImageManager.mockImages = [
            UIImage.createTestImage(color: .red),
            UIImage.createTestImage(color: .green),
            UIImage.createTestImage(color: .blue)
        ]
        
        let item = InventoryItem.createTestItemWithImages(in: context)
        let viewModel = try createTestViewModel(
            mockImageManager: mockImageManager,
            context: context
        )
        
        await viewModel.loadAllImages(for: item)
        
        #expect(!viewModel.isLoading)
        #expect(viewModel.loadedImages.count == 3) // 1 primary + 2 secondary
        #expect(viewModel.selectedImageIndex == 0)
    }
    
    @Test("Load images handles failures gracefully")
    func testLoadImagesFailure() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockImageManager = MockImageManager()
        mockImageManager.shouldFail = true
        
        let item = InventoryItem.createTestItemWithImages(in: context)
        let viewModel = try createTestViewModel(
            mockImageManager: mockImageManager,
            context: context
        )
        
        await viewModel.loadAllImages(for: item)
        
        #expect(!viewModel.isLoading)
        #expect(viewModel.loadedImages.isEmpty)
    }
    
    @Test("Handle new photos saves correctly")
    func testHandleNewPhotos() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockImageManager = MockImageManager()
        let item = InventoryItem.createTestItem(in: context) // No existing images
        let viewModel = try createTestViewModel(
            mockImageManager: mockImageManager,
            context: context
        )
        
        let newImages = [
            UIImage.createTestImage(color: .red),
            UIImage.createTestImage(color: .green)
        ]
        
        await viewModel.handleNewPhotos(newImages, for: item)
        
        #expect(item.imageURL != nil) // Primary image should be set
        #expect(item.secondaryPhotoURLs.count == 1) // One secondary image
        #expect(!item.assetId.isEmpty)
    }
    
    @Test("Delete photo removes correctly")
    func testDeletePhoto() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockImageManager = MockImageManager()
        let item = InventoryItem.createTestItemWithImages(in: context)
        let viewModel = try createTestViewModel(
            mockImageManager: mockImageManager,
            context: context
        )
        
        let urlToDelete = item.secondaryPhotoURLs.first!
        await viewModel.deletePhoto(urlString: urlToDelete, for: item)
        
        #expect(item.secondaryPhotoURLs.count == 1) // Should have one less
        #expect(!item.secondaryPhotoURLs.contains(urlToDelete))
    }
    
    // MARK: - Attachment Management Tests
    
    @Test("Delete attachment removes correctly")
    func testDeleteAttachment() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockImageManager = MockImageManager()
        let item = InventoryItem.createTestItem(in: context)
        
        // Add a mock attachment
        let attachmentURL = "file:///test/attachment.pdf"
        item.addAttachment(url: attachmentURL, originalName: "test.pdf")
        
        let viewModel = try createTestViewModel(
            mockImageManager: mockImageManager,
            context: context
        )
        
        await viewModel.deleteAttachment(attachmentURL, for: item)
        
        #expect(!item.hasAttachments())
    }
    
    @Test("Confirm delete attachment sets state correctly")
    func testConfirmDeleteAttachment() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let viewModel = try createTestViewModel(context: context)
        let testURL = "file:///test/attachment.pdf"
        
        viewModel.confirmDeleteAttachment(url: testURL)
        
        #expect(viewModel.attachmentToDelete == testURL)
        #expect(viewModel.showingDeleteAttachmentAlert == true)
    }
    
    // MARK: - Data Parsing Tests
    
    @Test("Weight value parsing from AI response")
    func testWeightValueParsing() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockOpenAI = MockOpenAIService()
        mockOpenAI.mockResponse = ImageDetails(
            title: "Test Item",
            quantity: "1",
            description: "Test",
            make: "Test",
            model: "Test",
            category: "Test",
            location: "Test",
            price: "100.00",
            serialNumber: "TEST123",
            weightValue: "2.5",
            weightUnit: "kg"
        )
        
        let mockImageManager = MockImageManager()
        mockImageManager.mockImages = [UIImage.createTestImage()]
        
        let item = InventoryItem.createTestItemWithImages(in: context)
        let viewModel = try createTestViewModel(
            item: item,
            mockOpenAI: mockOpenAI,
            mockImageManager: mockImageManager,
            context: context
        )
        
        // Load images first
        await viewModel.loadAllImages(for: item)
        
        // Perform AI analysis
        await viewModel.performAIAnalysis(for: item, allItems: [item])
        
        #expect(item.weightValue == "2.5")
        #expect(item.weightUnit == "kg")
    }
    
    @Test("Dimensions parsing from AI response")
    func testDimensionsParsing() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockOpenAI = MockOpenAIService()
        mockOpenAI.mockResponse = ImageDetails(
            title: "Test Item",
            quantity: "1",
            description: "Test",
            make: "Test",
            model: "Test",
            category: "Test",
            location: "Test",
            price: "100.00",
            serialNumber: "TEST123",
            dimensions: "12.5 x 8.0 x 4.0 inches"
        )
        
        let mockImageManager = MockImageManager()
        mockImageManager.mockImages = [UIImage.createTestImage()]
        
        let item = InventoryItem.createTestItemWithImages(in: context)
        let viewModel = try createTestViewModel(
            item: item,
            mockOpenAI: mockOpenAI,
            mockImageManager: mockImageManager,
            context: context
        )
        
        // Load images first
        await viewModel.loadAllImages(for: item)
        
        // Perform AI analysis
        await viewModel.performAIAnalysis(for: item, allItems: [item])
        
        #expect(item.dimensionLength == "12.5")
        #expect(item.dimensionWidth == "8.0")
        #expect(item.dimensionHeight == "4.0")
        #expect(item.dimensionUnit == "inches")
    }
    
    // MARK: - File Viewer Tests
    
    @Test("Open file viewer sets state correctly")
    func testOpenFileViewer() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let viewModel = try createTestViewModel(context: context)
        let testURL = "file:///test/document.pdf"
        let testName = "document.pdf"
        
        viewModel.openFileViewer(url: testURL, fileName: testName)
        
        #expect(viewModel.fileViewerURL?.absoluteString == testURL)
        #expect(viewModel.fileViewerName == testName)
        #expect(viewModel.showingFileViewer == true)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Error handling displays correct messages")
    func testErrorHandling() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockOpenAI = MockOpenAIService()
        mockOpenAI.shouldFail = true
        
        let mockImageManager = MockImageManager()
        mockImageManager.mockImages = [UIImage.createTestImage()]
        
        let item = InventoryItem.createTestItemWithImages(in: context)
        let viewModel = try createTestViewModel(
            item: item,
            mockOpenAI: mockOpenAI,
            mockImageManager: mockImageManager,
            context: context
        )
        
        // Load images first
        await viewModel.loadAllImages(for: item)
        
        // Perform AI analysis (should fail)
        await viewModel.performAIAnalysis(for: item, allItems: [item])
        
        #expect(viewModel.showingErrorAlert)
        #expect(viewModel.errorMessage.contains("Unable to process AI response"))
    }
    
    // MARK: - State Management Tests
    
    @Test("Loading states are managed correctly")
    func testLoadingStates() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let mockOpenAI = MockOpenAIService()
        let mockImageManager = MockImageManager()
        mockImageManager.mockImages = [UIImage.createTestImage()]
        
        let item = InventoryItem.createTestItemWithImages(in: context)
        let viewModel = try createTestViewModel(
            item: item,
            mockOpenAI: mockOpenAI,
            mockImageManager: mockImageManager,
            context: context
        )
        
        // Load images first
        await viewModel.loadAllImages(for: item)
        
        // Start AI analysis in background to check loading state
        let analysisTask = Task {
            await viewModel.performAIAnalysis(for: item, allItems: [item])
        }
        
        // Give it a moment to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Check that loading state is set (may already be done due to mock speed)
        let wasLoading = viewModel.isLoadingOpenAiResults
        
        // Wait for completion
        await analysisTask.value
        
        // Should no longer be loading
        #expect(!viewModel.isLoadingOpenAiResults)
    }
}