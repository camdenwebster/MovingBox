//
//  ItemCreationFlowTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 9/19/25.
//

import SQLiteData
import SwiftUI
import Testing
import UIKit

@testable import MovingBox

@MainActor
@Suite struct ItemCreationFlowTests {

    // MARK: - Test Setup

    /// Creates an in-memory SQLite database with all migrations applied.
    private func createTestDatabase() throws -> DatabaseQueue {
        try makeInMemoryDatabase()
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

    private func createMockMultiItemAnalysisResponse(itemCount: Int = 3) -> MultiItemAnalysisResponse {
        let items = (1...itemCount).map { i in
            DetectedInventoryItem(
                id: "item-\(i)",
                title: "Test Item \(i)",
                description: "Description for test item \(i)",
                category: "Electronics",
                make: "Test Make",
                model: "Test Model",
                estimatedPrice: "$\(i * 100).00",
                confidence: 0.85
            )
        }

        return MultiItemAnalysisResponse(
            items: items,
            detectedCount: itemCount,
            analysisType: "multi_item",
            confidence: 0.88
        )
    }

    // MARK: - Enhanced ItemCreationStep Tests

    @Test("Enhanced ItemCreationStep includes multiItemSelection")
    func testEnhancedItemCreationStep() {
        let allSteps = ItemCreationStep.allCases

        #expect(allSteps.contains(.camera))
        #expect(allSteps.contains(.analyzing))
        #expect(allSteps.contains(.multiItemSelection))
        #expect(allSteps.contains(.details))
        #expect(allSteps.count == 4)
    }

    @Test("ItemCreationStep provides correct display names")
    func testItemCreationStepDisplayNames() {
        #expect(ItemCreationStep.camera.displayName == "Camera")
        #expect(ItemCreationStep.analyzing.displayName == "Analyzing")
        #expect(ItemCreationStep.multiItemSelection.displayName == "Select Items")
        #expect(ItemCreationStep.details.displayName == "Details")
    }

    @Test("ItemCreationStep navigation flow is correct")
    func testItemCreationStepNavigationFlow() {
        // Test single item flow
        let singleItemFlow = ItemCreationStep.getNavigationFlow(for: .singleItem)
        #expect(singleItemFlow == [.camera, .analyzing, .details])

        // Test multi-item flow
        let multiItemFlow = ItemCreationStep.getNavigationFlow(for: .multiItem)
        #expect(multiItemFlow == [.camera, .analyzing, .multiItemSelection, .details])
    }

    // MARK: - ItemCreationFlowViewModel Tests

    @Test("ItemCreationFlowViewModel initializes correctly for single item")
    func testViewModelInitializationSingleItem() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .singleItem,
            locationID: nil
        )

        #expect(viewModel.captureMode == .singleItem)
        #expect(viewModel.currentStep == .camera)
        #expect(viewModel.navigationFlow == [.camera, .analyzing, .details])
        #expect(viewModel.capturedImages.isEmpty)
        #expect(viewModel.createdItems.isEmpty)
        #expect(!viewModel.processingImage)
        #expect(!viewModel.analysisComplete)
    }

    @Test("ItemCreationFlowViewModel initializes correctly for multi-item")
    func testViewModelInitializationMultiItem() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil
        )

        #expect(viewModel.captureMode == .multiItem)
        #expect(viewModel.currentStep == .camera)
        #expect(viewModel.navigationFlow == [.camera, .analyzing, .multiItemSelection, .details])
        #expect(viewModel.multiItemAnalysisResponse == nil)
    }

    @Test("ViewModel navigates correctly through single item flow")
    func testSingleItemFlowNavigation() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .singleItem,
            locationID: nil
        )

        // Test initial state
        #expect(viewModel.currentStep == .camera)
        #expect(viewModel.canGoToNextStep == false)  // No images captured yet
        #expect(viewModel.canGoToPreviousStep == false)

        // Simulate image capture
        viewModel.capturedImages = createTestImages(count: 2)
        #expect(viewModel.canGoToNextStep == true)

        // Move to analyzing
        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .analyzing)
        #expect(viewModel.canGoToPreviousStep == true)

        // Simulate analysis complete with a created item
        viewModel.analysisComplete = true
        viewModel.createdItems = [SQLiteInventoryItem(id: UUID(), assetId: UUID().uuidString)]
        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .details)
        #expect(viewModel.canGoToNextStep == false)  // Final step
    }

    @Test("ViewModel navigates correctly through multi-item flow")
    func testMultiItemFlowNavigation() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil
        )

        // Test initial state
        #expect(viewModel.currentStep == .camera)

        // Simulate image capture (single image for multi-item)
        viewModel.capturedImages = createTestImages(count: 1)
        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .analyzing)

        // Simulate multi-item analysis complete
        let mockResponse = createMockMultiItemAnalysisResponse()
        viewModel.multiItemAnalysisResponse = mockResponse
        viewModel.analysisComplete = true
        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .multiItemSelection)

        // Simulate item selection complete -- createdItems must be non-empty
        viewModel.selectedMultiItems = [mockResponse.safeItems[0], mockResponse.safeItems[1]]
        viewModel.createdItems = [
            SQLiteInventoryItem(id: UUID(), assetId: UUID().uuidString),
            SQLiteInventoryItem(id: UUID(), assetId: UUID().uuidString),
        ]
        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .details)
    }

    @Test("ViewModel handles step transitions with validation")
    func testStepTransitionValidation() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .singleItem,
            locationID: nil
        )

        // Cannot go to next step without images
        #expect(viewModel.canGoToNextStep == false)
        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .camera)  // Should remain at camera

        // Cannot go to details without analysis complete
        viewModel.capturedImages = createTestImages(count: 1)
        viewModel.goToNextStep()  // Go to analyzing
        #expect(viewModel.currentStep == .analyzing)

        viewModel.goToNextStep()  // Try to go to details
        #expect(viewModel.currentStep == .analyzing)  // Should remain at analyzing

        // Can go to details after analysis complete (with created item)
        viewModel.analysisComplete = true
        viewModel.createdItems = [SQLiteInventoryItem(id: UUID(), assetId: UUID().uuidString)]
        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .details)
    }

    @Test("ViewModel handles multi-item selection validation")
    func testMultiItemSelectionValidation() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil
        )

        // Navigate to multi-item selection
        viewModel.capturedImages = createTestImages(count: 1)
        viewModel.goToNextStep()  // analyzing

        let mockResponse = createMockMultiItemAnalysisResponse()
        viewModel.multiItemAnalysisResponse = mockResponse
        viewModel.analysisComplete = true
        viewModel.goToNextStep()  // multiItemSelection

        #expect(viewModel.currentStep == .multiItemSelection)
        #expect(viewModel.canGoToNextStep == false)  // No created items yet

        // Cannot proceed without created items
        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .multiItemSelection)

        // Can proceed with created items
        viewModel.selectedMultiItems = [mockResponse.safeItems[0]]
        viewModel.createdItems = [SQLiteInventoryItem(id: UUID(), assetId: UUID().uuidString)]
        #expect(viewModel.canGoToNextStep == true)

        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .details)
    }

    @Test("ViewModel handles backward navigation correctly")
    func testBackwardNavigation() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil
        )

        // Navigate to details
        viewModel.capturedImages = createTestImages(count: 1)
        viewModel.goToNextStep()  // analyzing

        let mockResponse = createMockMultiItemAnalysisResponse()
        viewModel.multiItemAnalysisResponse = mockResponse
        viewModel.analysisComplete = true
        viewModel.goToNextStep()  // multiItemSelection

        viewModel.selectedMultiItems = [mockResponse.safeItems[0]]
        viewModel.createdItems = [SQLiteInventoryItem(id: UUID(), assetId: UUID().uuidString)]
        viewModel.goToNextStep()  // details

        // Test backward navigation
        #expect(viewModel.currentStep == .details)
        #expect(viewModel.canGoToPreviousStep == true)

        viewModel.goToPreviousStep()
        #expect(viewModel.currentStep == .multiItemSelection)

        viewModel.goToPreviousStep()
        #expect(viewModel.currentStep == .analyzing)

        viewModel.goToPreviousStep()
        #expect(viewModel.currentStep == .camera)
        #expect(viewModel.canGoToPreviousStep == false)
    }

    // MARK: - Analysis Flow Tests

    @Test("ViewModel performs single item analysis correctly")
    func testSingleItemAnalysis() async throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let mockOpenAIService = MockOpenAIService()
        let mockSettings = MockSettingsManager()

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .singleItem,
            locationID: nil,
            openAIService: mockOpenAIService
        )
        viewModel.updateSettingsManager(mockSettings)

        // Set up for analysis: create an item in the database and set createdItems
        viewModel.capturedImages = createTestImages(count: 2)
        let testItemID = UUID()
        let testItem = SQLiteInventoryItem(
            id: testItemID,
            title: "Test Item",
            quantityString: "1",
            quantityInt: 1,
            desc: "Test Description",
            assetId: testItemID.uuidString
        )
        try await db.write { database in
            try SQLiteInventoryItem.insert { testItem }.execute(database)
        }
        viewModel.createdItems = [testItem]

        // Test analysis
        await viewModel.performAnalysis()

        #expect(viewModel.analysisComplete == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ViewModel performs multi-item analysis correctly")
    func testMultiItemAnalysis() async throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let mockOpenAIService = MockOpenAIService()
        let mockSettings = MockSettingsManager()

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil,
            openAIService: mockOpenAIService
        )
        viewModel.updateSettingsManager(mockSettings)

        // Set up mock response
        let mockResponse = createMockMultiItemAnalysisResponse()
        mockOpenAIService.mockMultiItemResponse = mockResponse

        // Set up for analysis
        viewModel.capturedImages = createTestImages(count: 1)

        // Test multi-item analysis
        await viewModel.performMultiItemAnalysis()

        #expect(viewModel.multiItemAnalysisResponse?.safeItems.count == 3)
        #expect(viewModel.analysisComplete == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ViewModel handles analysis errors gracefully")
    func testAnalysisErrorHandling() async throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let mockOpenAIService = MockOpenAIService()
        mockOpenAIService.shouldFailMultiItem = true
        let mockSettings = MockSettingsManager()

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil,
            openAIService: mockOpenAIService
        )
        viewModel.updateSettingsManager(mockSettings)

        viewModel.capturedImages = createTestImages(count: 1)

        // Test error handling
        await viewModel.performMultiItemAnalysis()

        #expect(viewModel.analysisComplete == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.multiItemAnalysisResponse == nil)
    }

    // MARK: - Item Creation Tests

    @Test("ViewModel creates single item correctly")
    func testSingleItemCreation() async throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .singleItem,
            locationID: nil
        )

        viewModel.capturedImages = createTestImages(count: 1)

        let createdItem = try await viewModel.createSingleInventoryItem()

        #expect(createdItem != nil)
        #expect(createdItem!.quantityInt == 1)
        #expect(viewModel.createdItems.isEmpty == false || createdItem != nil)
    }

    @Test("ViewModel processes multi-item selection correctly")
    func testMultiItemProcessing() async throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil
        )

        let mockResponse = createMockMultiItemAnalysisResponse()
        viewModel.multiItemAnalysisResponse = mockResponse
        viewModel.selectedMultiItems = [mockResponse.safeItems[0], mockResponse.safeItems[1]]
        viewModel.capturedImages = createTestImages(count: 1)

        let createdItems = try await viewModel.processSelectedMultiItems()

        #expect(createdItems.count == 2)
        #expect(viewModel.createdItems.count == 2)

        // Verify item properties
        let firstItem = createdItems[0]
        #expect(firstItem.title == "Test Item 1")
        #expect(firstItem.make == "Test Make")
    }

    // MARK: - State Management Tests

    @Test("ViewModel resets state correctly")
    func testStateReset() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil
        )

        // Set some state
        viewModel.capturedImages = createTestImages(count: 1)
        viewModel.analysisComplete = true
        viewModel.processingImage = true
        viewModel.errorMessage = "Test error"

        // Reset state
        viewModel.resetState()

        #expect(viewModel.currentStep == .camera)
        #expect(viewModel.capturedImages.isEmpty)
        #expect(viewModel.analysisComplete == false)
        #expect(viewModel.processingImage == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.multiItemAnalysisResponse == nil)
        #expect(viewModel.selectedMultiItems.isEmpty)
        #expect(viewModel.createdItems.isEmpty)
    }

    @Test("ViewModel handles step progression validation")
    func testStepProgressionValidation() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil
        )

        // Test progression requirements
        #expect(viewModel.isReadyForNextStep == false)  // No images

        viewModel.capturedImages = createTestImages(count: 1)
        #expect(viewModel.isReadyForNextStep == true)  // Has images

        viewModel.goToNextStep()  // analyzing
        #expect(viewModel.isReadyForNextStep == false)  // Analysis not complete

        viewModel.analysisComplete = true
        viewModel.multiItemAnalysisResponse = createMockMultiItemAnalysisResponse()
        #expect(viewModel.isReadyForNextStep == true)  // Analysis complete

        viewModel.goToNextStep()  // multiItemSelection
        #expect(viewModel.isReadyForNextStep == false)  // No created items yet

        // In multi-item selection, isReadyForNextStep checks !createdItems.isEmpty
        viewModel.selectedMultiItems = [viewModel.multiItemAnalysisResponse!.safeItems[0]]
        viewModel.createdItems = [SQLiteInventoryItem(id: UUID(), assetId: UUID().uuidString)]
        #expect(viewModel.isReadyForNextStep == true)  // Items created
    }

    // MARK: - Edge Cases and Error Handling

    @Test("ViewModel handles empty multi-item response")
    func testEmptyMultiItemResponse() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil
        )

        // Navigate to analyzing first
        viewModel.capturedImages = createTestImages(count: 1)
        viewModel.goToNextStep()  // camera -> analyzing

        let emptyResponse = MultiItemAnalysisResponse(
            items: [],
            detectedCount: 0,
            analysisType: "multi_item",
            confidence: 0.5
        )

        viewModel.multiItemAnalysisResponse = emptyResponse
        viewModel.analysisComplete = true

        // Should be able to proceed (analyzing is ready when analysisComplete && response != nil)
        #expect(viewModel.canGoToNextStep == true)

        viewModel.goToNextStep()
        #expect(viewModel.currentStep == .multiItemSelection)
    }

    @Test("ViewModel handles maximum items correctly")
    func testMaximumItemsHandling() throws {
        let db = try createTestDatabase()
        try prepareDependencies { $0.defaultDatabase = db }

        let viewModel = ItemCreationFlowViewModel(
            captureMode: .multiItem,
            locationID: nil
        )

        // Create response with many items
        let manyItemsResponse = createMockMultiItemAnalysisResponse(itemCount: 15)
        viewModel.multiItemAnalysisResponse = manyItemsResponse

        // Should handle large number of items gracefully
        #expect(viewModel.multiItemAnalysisResponse?.safeItems.count == 15)

        // Select all items
        viewModel.selectedMultiItems = manyItemsResponse.safeItems
        #expect(viewModel.selectedMultiItems.count == 15)
    }
}
