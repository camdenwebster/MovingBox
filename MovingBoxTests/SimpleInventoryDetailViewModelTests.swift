//
//  SimpleInventoryDetailViewModelTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 9/10/25.
//

import Testing
import SwiftData
import UIKit
@testable import MovingBox

@MainActor
struct SimpleInventoryDetailViewModelTests {
    
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
    
    private func createSimpleViewModel(context: ModelContext) -> InventoryDetailViewModel {
        let item = InventoryItem()
        item.title = "Test Item"
        item.desc = "Test Description"
        item.price = Decimal(100.0)
        context.insert(item)
        
        let mockOpenAI = MockOpenAIService()
        let mockImageManager = MockImageManager()
        let mockSettings = MockSettingsManager()
        
        return InventoryDetailViewModel(
            inventoryItem: item,
            settings: mockSettings,
            modelContext: context,
            openAIService: mockOpenAI,
            imageManager: mockImageManager
        )
    }
    
    // MARK: - Basic Tests
    
    @Test("ViewModel can be created successfully")
    func testViewModelCreation() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let viewModel = createSimpleViewModel(context: context)
        
        // Test that basic properties are initialized correctly
        #expect(!viewModel.isLoadingOpenAiResults)
        #expect(viewModel.errorMessage.isEmpty)
        #expect(!viewModel.showingErrorAlert)
        #expect(viewModel.loadedImages.isEmpty)
        #expect(viewModel.selectedImageIndex == 0)
        #expect(!viewModel.isLoading)
    }
    
    @Test("ViewModel manages loading state correctly")
    func testLoadingState() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let viewModel = createSimpleViewModel(context: context)
        
        // Initially not loading
        #expect(!viewModel.isLoadingOpenAiResults)
        
        // Can set loading state
        viewModel.isLoadingOpenAiResults = true
        #expect(viewModel.isLoadingOpenAiResults)
        
        // Can reset loading state
        viewModel.isLoadingOpenAiResults = false
        #expect(!viewModel.isLoadingOpenAiResults)
    }
    
    @Test("ViewModel manages error state correctly")
    func testErrorState() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let viewModel = createSimpleViewModel(context: context)
        
        // Initially no error
        #expect(viewModel.errorMessage.isEmpty)
        #expect(!viewModel.showingErrorAlert)
        
        // Can set error state
        viewModel.errorMessage = "Test Error"
        viewModel.showingErrorAlert = true
        
        #expect(viewModel.errorMessage == "Test Error")
        #expect(viewModel.showingErrorAlert)
    }
    
    @Test("ViewModel manages photo state correctly")
    func testPhotoState() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let viewModel = createSimpleViewModel(context: context)
        
        // Initially no images
        #expect(viewModel.loadedImages.isEmpty)
        #expect(viewModel.selectedImageIndex == 0)
        
        // Can add images
        let testImage = UIImage.createTestImage()
        viewModel.loadedImages = [testImage]
        
        #expect(viewModel.loadedImages.count == 1)
        
        // Selected index stays valid
        #expect(viewModel.selectedImageIndex == 0)
    }
    
    @Test("ViewModel manages file viewer state correctly")
    func testFileViewerState() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let viewModel = createSimpleViewModel(context: context)
        
        // Initially not showing file viewer
        #expect(!viewModel.showingFileViewer)
        #expect(viewModel.fileViewerURL == nil)
        #expect(viewModel.fileViewerName == nil)
        
        // Test open file viewer method
        viewModel.openFileViewer(url: "file:///test/document.pdf", fileName: "test.pdf")
        
        #expect(viewModel.showingFileViewer)
        #expect(viewModel.fileViewerURL?.absoluteString == "file:///test/document.pdf")
        #expect(viewModel.fileViewerName == "test.pdf")
    }
    
    @Test("ViewModel manages attachment deletion state correctly")
    func testAttachmentDeletionState() async throws {
        let container = try createTestContainer()
        let context = container.mainContext
        
        let viewModel = createSimpleViewModel(context: context)
        
        // Initially not showing delete alert
        #expect(!viewModel.showingDeleteAttachmentAlert)
        #expect(viewModel.attachmentToDelete == nil)
        
        // Test confirm delete attachment method
        viewModel.confirmDeleteAttachment(url: "file:///test/attachment.pdf")
        
        #expect(viewModel.showingDeleteAttachmentAlert)
        #expect(viewModel.attachmentToDelete == "file:///test/attachment.pdf")
    }
    
    @Test("Mock services work correctly")
    func testMockServices() async throws {
        let mockOpenAI = MockOpenAIService()
        let mockImageManager = MockImageManager()
        let mockSettings = MockSettingsManager()
        
        // Test MockOpenAIService
        #expect(!mockOpenAI.shouldFail)
        #expect(mockOpenAI.mockResponse.title == "Test Item")
        
        // Test MockImageManager
        #expect(!mockImageManager.shouldFail)
        #expect(mockImageManager.mockImages.isEmpty)
        #expect(mockImageManager.mockURLs.isEmpty)
        
        // Test MockSettingsManager
        #expect(!mockSettings.isPro)
        #expect(!mockSettings.highQualityAnalysisEnabled)
        #expect(mockSettings.maxTokens == 1000)
    }
}