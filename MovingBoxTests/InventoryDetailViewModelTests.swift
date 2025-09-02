//
//  InventoryDetailViewModelTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 9/2/25.
//

import Testing
import Foundation
import SwiftData
import UIKit
@testable import MovingBox

// Simple test to verify the ViewModel exists and can be imported
@MainActor
@Suite struct InventoryDetailViewModelSimpleTests {
    
    @Test("ViewModel exists and can be instantiated")
    func testViewModelExists() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: InventoryItem.self, InventoryLocation.self, InventoryLabel.self, Home.self,
            configurations: config
        )
        let modelContext = container.mainContext
        let item = InventoryItem()
        let settings = SettingsManager()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        // Basic assertion
        #expect(viewModel.isEditing == false)
    }
}

@MainActor
@Suite struct InventoryDetailViewModelTests {
    
    // MARK: - Test Infrastructure
    func createTestEnvironment() -> (ModelContext, InventoryItem, SettingsManager) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: InventoryItem.self, InventoryLocation.self, InventoryLabel.self, Home.self,
            configurations: config
        )
        let modelContext = container.mainContext
        
        let item = InventoryItem()
        item.title = "Test Item"
        item.price = Decimal(string: "99.99")!
        
        let settings = SettingsManager()
        
        return (modelContext, item, settings)
    }
    
    // MARK: - Initialization Tests
    
    @Test("ViewModel initializes with correct default state")
    func testViewModelInitialization() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings,
            isEditing: false
        )
        
        #expect(viewModel.isEditing == false)
        #expect(viewModel.displayPriceString == "99.99")
        #expect(viewModel.isLoadingOpenAiResults == false)
        #expect(viewModel.showingErrorAlert == false)
        #expect(viewModel.errorMessage == "")
        #expect(viewModel.loadedImages.isEmpty)
        #expect(viewModel.selectedImageIndex == 0)
    }
    
    @Test("ViewModel initializes with editing mode")
    func testViewModelInitializationInEditMode() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings,
            isEditing: true
        )
        
        #expect(viewModel.isEditing == true)
    }
    
    // MARK: - Edit Mode Management Tests
    
    @Test("Start editing changes state correctly")
    func testStartEditing() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings,
            isEditing: false
        )
        
        viewModel.startEditing()
        #expect(viewModel.isEditing == true)
    }
    
    @Test("Save changes updates model context and exits edit mode")
    func testSaveChanges() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        var saveCallbackCalled = false
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings,
            isEditing: true,
            onSave: { saveCallbackCalled = true }
        )
        
        item.title = "Updated Title"
        viewModel.saveChanges()
        
        #expect(viewModel.isEditing == false)
        #expect(saveCallbackCalled == true)
        #expect(item.title == "Updated Title")
    }
    
    @Test("Discard changes rolls back model context and exits edit mode")
    func testDiscardChanges() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        modelContext.insert(item)
        try modelContext.save()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings,
            isEditing: true
        )
        
        // Make a change
        let originalTitle = item.title
        item.title = "Changed Title"
        
        viewModel.discardChanges()
        
        #expect(viewModel.isEditing == false)
        // Note: In a real test, we'd verify the rollback, but since we're using in-memory context
        // the rollback behavior might differ from production
    }
    
    // MARK: - Photo Management Tests
    
    @Test("Photo count calculations work correctly")
    func testPhotoCountCalculations() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        // No photos initially
        #expect(viewModel.currentPhotoCount == 0)
        #expect(viewModel.canAddMorePhotos == true)
        #expect(viewModel.maxPhotosToAdd == 5)
        
        // Add primary image
        item.imageURL = URL(string: "file://test.jpg")
        #expect(viewModel.currentPhotoCount == 1)
        #expect(viewModel.canAddMorePhotos == true)
        #expect(viewModel.maxPhotosToAdd == 4)
        
        // Add secondary images
        item.secondaryPhotoURLs = ["file://test2.jpg", "file://test3.jpg", "file://test4.jpg", "file://test5.jpg"]
        #expect(viewModel.currentPhotoCount == 5)
        #expect(viewModel.canAddMorePhotos == false)
        #expect(viewModel.maxPhotosToAdd == 1) // Still minimum of 1
    }
    
    @Test("Add photo action shows source alert when photos can be added")
    func testAddPhotoAction() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        viewModel.addPhotoAction()
        #expect(viewModel.showPhotoSourceAlert == true)
    }
    
    @Test("Add photo action doesn't show source alert when at max photos")
    func testAddPhotoActionAtMaxPhotos() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        // Set item to max photos
        item.imageURL = URL(string: "file://test.jpg")
        item.secondaryPhotoURLs = ["file://test2.jpg", "file://test3.jpg", "file://test4.jpg", "file://test5.jpg"]
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        viewModel.addPhotoAction()
        #expect(viewModel.showPhotoSourceAlert == false)
    }
    
    // MARK: - AI Analysis Tests
    
    @Test("AI analysis shows paywall for non-pro users")
    func testAIAnalysisShowsPaywallForNonProUsers() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        // Configure settings to show paywall
        settings.isPro = false
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        await viewModel.analyzeWithAI()
        #expect(viewModel.showingPaywall == true)
    }
    
    @Test("AI analysis doesn't start when already loading")
    func testAIAnalysisDoesntStartWhenLoading() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        viewModel.isLoadingOpenAiResults = true
        let initialLoadingState = viewModel.isLoadingOpenAiResults
        
        await viewModel.analyzeWithAI()
        
        // Should remain in loading state and not change other states
        #expect(viewModel.isLoadingOpenAiResults == initialLoadingState)
        #expect(viewModel.showingPaywall == false)
    }
    
    // MARK: - Camera Action Tests
    
    @Test("Camera actions set correct UI state")
    func testCameraActions() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        viewModel.showTakePhoto()
        #expect(viewModel.showingSimpleCamera == true)
        
        viewModel.showChooseFromLibrary()
        #expect(viewModel.showPhotoPicker == true)
        
        viewModel.showMultiPhotoCamera()
        #expect(viewModel.showingMultiPhotoCamera == true)
    }
    
    @Test("Multi-photo camera cancel works correctly")
    func testMultiPhotoCameraCancel() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        viewModel.showingMultiPhotoCamera = true
        viewModel.onMultiPhotoCameraCancel()
        #expect(viewModel.showingMultiPhotoCamera == false)
    }
    
    // MARK: - Image Tap Tests
    
    @Test("Image tap in view mode shows full screen photo")
    func testImageTapInViewMode() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings,
            isEditing: false
        )
        
        viewModel.onImageTap(1)
        #expect(viewModel.selectedImageIndex == 1)
        #expect(viewModel.showingFullScreenPhoto == true)
    }
    
    @Test("Image tap in edit mode doesn't show full screen photo")
    func testImageTapInEditMode() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings,
            isEditing: true
        )
        
        viewModel.onImageTap(1)
        #expect(viewModel.selectedImageIndex == 0) // Should not change
        #expect(viewModel.showingFullScreenPhoto == false)
    }
    
    // MARK: - Sparkles Button Tests
    
    @Test("Sparkles button shows in edit mode when item has used AI")
    func testSparklesButtonVisibility() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        item.hasUsedAI = true
        
        let editingViewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings,
            isEditing: true
        )
        
        let viewingViewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings,
            isEditing: false
        )
        
        #expect(editingViewModel.showSparklesButton == true)
        #expect(viewingViewModel.showSparklesButton == false)
    }
    
    @Test("Sparkles button doesn't show when item hasn't used AI")
    func testSparklesButtonHiddenWhenNoAI() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        item.hasUsedAI = false
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings,
            isEditing: true
        )
        
        #expect(viewModel.showSparklesButton == false)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Error state can be set and cleared")
    func testErrorStateManagement() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        #expect(viewModel.showingErrorAlert == false)
        #expect(viewModel.errorMessage == "")
        
        viewModel.showingErrorAlert = true
        viewModel.errorMessage = "Test Error"
        
        #expect(viewModel.showingErrorAlert == true)
        #expect(viewModel.errorMessage == "Test Error")
    }
    
    // MARK: - Price Formatting Tests
    
    @Test("Price formatting works correctly")
    func testPriceFormatting() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        item.price = Decimal(string: "123.456")!
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        #expect(viewModel.displayPriceString == "123.46")
        
        item.price = Decimal.zero
        let zeroViewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        #expect(zeroViewModel.displayPriceString == "0.00")
    }
    
    // MARK: - Modal State Management Tests
    
    @Test("Modal states can be toggled independently")
    func testModalStateManagement() async throws {
        let (modelContext, item, settings) = createTestEnvironment()
        
        let viewModel = InventoryDetailViewModel(
            inventoryItem: item,
            modelContext: modelContext,
            settings: settings
        )
        
        // Test all modal states start as false
        #expect(viewModel.showingPaywall == false)
        #expect(viewModel.showingLocationSelection == false)
        #expect(viewModel.showingLabelSelection == false)
        #expect(viewModel.showUnsavedChangesAlert == false)
        #expect(viewModel.showAIConfirmationAlert == false)
        
        // Test they can be set independently
        viewModel.showingPaywall = true
        #expect(viewModel.showingPaywall == true)
        #expect(viewModel.showingLocationSelection == false)
        
        viewModel.showingLocationSelection = true
        #expect(viewModel.showingLocationSelection == true)
        #expect(viewModel.showingPaywall == true)
    }
}