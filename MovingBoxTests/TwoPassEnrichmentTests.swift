//
//  TwoPassEnrichmentTests.swift
//  MovingBoxTests
//
//  Created by Codex on 2/4/26.
//

import MovingBoxAIAnalysis
import SQLiteData
import SwiftUI
import Testing
import UIKit

@testable import MovingBox

@MainActor
@Suite struct TwoPassEnrichmentTests {

    // MARK: - Helpers

    private func createTestDatabase() throws -> DatabaseQueue {
        try makeInMemoryDatabase()
    }

    private func createTestImage() -> UIImage {
        let size = CGSize(width: 80, height: 80)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func createMockDetectedItems(count: Int) -> [DetectedInventoryItem] {
        return (1...count).map { i in
            DetectedInventoryItem(
                id: "item-\(i)",
                title: "Pass1 Item \(i)",
                description: "Pass1 description \(i)",
                category: "Electronics",
                make: "Pass1 Make \(i)",
                model: "Pass1 Model \(i)",
                estimatedPrice: "$\(i * 100).00",
                confidence: 0.9
            )
        }
    }

    private func createMockAnalysisResponse(itemCount: Int) -> MultiItemAnalysisResponse {
        return MultiItemAnalysisResponse(
            items: createMockDetectedItems(count: itemCount),
            detectedCount: itemCount,
            analysisType: "multi_item",
            confidence: 0.9
        )
    }

    private func makeEnrichedDetails(title: String = "Enriched Item") -> ImageDetails {
        return ImageDetails(
            title: title,
            quantity: "1",
            description: "Enriched description",
            make: "Enriched Make",
            model: "Enriched Model",
            category: "Electronics",
            categories: ["Electronics"],
            location: "Office",
            price: "$123.45",
            serialNumber: "SN-123",
            condition: "New",
            color: "Black",
            dimensions: "12 x 8 x 4 inches",
            dimensionLength: "12",
            dimensionWidth: "8",
            dimensionHeight: "4",
            dimensionUnit: "inches",
            weightValue: "10",
            weightUnit: "lbs",
            purchaseLocation: "Test Store",
            replacementCost: "$200.00",
            depreciationRate: "10%",
            storageRequirements: "Keep dry",
            isFragile: "true"
        )
    }

    private func waitForEnrichment(_ viewModel: MultiItemSelectionViewModel) async {
        for _ in 0..<40 {
            if viewModel.enrichmentFinished {
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    @MainActor
    private final class CountingMockAIAnalysisService: MockAIAnalysisService {
        var analyzeItemCallCount = 0

        override func analyzeItem(
            from images: [UIImage],
            settings: AIAnalysisSettings,
            context: AIAnalysisContext
        ) async throws -> ImageDetails {
            analyzeItemCallCount += 1
            return try await super.analyzeItem(from: images, settings: settings, context: context)
        }
    }

    // MARK: - Tests

    @Test("Enrichment populates details for each item")
    func testEnrichmentPopulatesDetails() async throws {
        let database = try createTestDatabase()
        let analysisResponse = createMockAnalysisResponse(itemCount: 2)
        let mockService = MockAIAnalysisService()
        let settings = MockSettingsManager()

        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: [createTestImage()],
            location: nil,
            database: database,
            aiAnalysisService: mockService
        )

        for item in viewModel.detectedItems {
            viewModel.croppedPrimaryImages[item.id] = createTestImage()
        }

        viewModel.startEnrichment(settings: settings)
        await waitForEnrichment(viewModel)

        #expect(viewModel.enrichmentFinished)
        #expect(viewModel.enrichedDetails.count == 2)
        #expect(viewModel.enrichmentCompleted == 2)
    }

    @Test("Enrichment failure is non-fatal")
    func testEnrichmentFailureIsNonFatal() async throws {
        let database = try createTestDatabase()
        let analysisResponse = createMockAnalysisResponse(itemCount: 1)
        let mockService = MockAIAnalysisService()
        mockService.shouldFail = true
        let settings = MockSettingsManager()

        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: [createTestImage()],
            location: nil,
            database: database,
            aiAnalysisService: mockService
        )

        for item in viewModel.detectedItems {
            viewModel.croppedPrimaryImages[item.id] = createTestImage()
        }

        viewModel.startEnrichment(settings: settings)
        await waitForEnrichment(viewModel)

        #expect(viewModel.enrichmentFinished)
        #expect(viewModel.enrichedDetails.isEmpty)
        #expect(!viewModel.isEnriching)
    }

    @Test("createInventoryItem uses enriched details when available")
    func testCreateInventoryItemUsesEnrichedDetails() async throws {
        let database = try createTestDatabase()
        let analysisResponse = createMockAnalysisResponse(itemCount: 1)

        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: [createTestImage()],
            location: nil,
            database: database
        )

        guard let detectedItem = viewModel.detectedItems.first else {
            throw InventoryItemCreationError.invalidItemData
        }

        viewModel.enrichedDetails[detectedItem.id] = makeEnrichedDetails()
        viewModel.selectedItems = [detectedItem.id]

        let createdItems = try await viewModel.createSelectedInventoryItems()
        let createdItem = try #require(createdItems.first)

        #expect(createdItem.serial == "SN-123")
        #expect(createdItem.condition == "New")
        #expect(createdItem.dimensionLength == "12")
        #expect(createdItem.dimensionWidth == "8")
        #expect(createdItem.dimensionHeight == "4")
        #expect(createdItem.dimensionUnit == "inches")
        #expect(createdItem.hasUsedAI)
    }

    @Test("createInventoryItem falls back to pass 1 data when no enrichment")
    func testCreateInventoryItemFallbacksWithoutEnrichment() async throws {
        let database = try createTestDatabase()
        let analysisResponse = createMockAnalysisResponse(itemCount: 1)

        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: [createTestImage()],
            location: nil,
            database: database
        )

        guard let detectedItem = viewModel.detectedItems.first else {
            throw InventoryItemCreationError.invalidItemData
        }

        viewModel.selectedItems = [detectedItem.id]

        let createdItems = try await viewModel.createSelectedInventoryItems()
        let createdItem = try #require(createdItems.first)

        #expect(createdItem.title == detectedItem.title)
        #expect(createdItem.serial.isEmpty)
        #expect(createdItem.hasUsedAI)
    }

    @Test("Enrichment is idempotent")
    func testEnrichmentIsIdempotent() async throws {
        let database = try createTestDatabase()
        let analysisResponse = createMockAnalysisResponse(itemCount: 2)
        let mockService = CountingMockAIAnalysisService()
        let settings = MockSettingsManager()

        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: [createTestImage()],
            location: nil,
            database: database,
            aiAnalysisService: mockService
        )

        for item in viewModel.detectedItems {
            viewModel.croppedPrimaryImages[item.id] = createTestImage()
        }

        viewModel.startEnrichment(settings: settings)
        await waitForEnrichment(viewModel)

        let firstCallCount = mockService.analyzeItemCallCount
        viewModel.startEnrichment(settings: settings)
        try await Task.sleep(for: .milliseconds(100))

        #expect(mockService.analyzeItemCallCount == firstCallCount)
        #expect(viewModel.enrichmentFinished)
    }

    @Test("Cancellation stops in-progress enrichment")
    func testEnrichmentCancellation() async throws {
        let database = try createTestDatabase()
        let analysisResponse = createMockAnalysisResponse(itemCount: 2)
        let mockService = MockAIAnalysisService()
        let settings = MockSettingsManager()

        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: [createTestImage()],
            location: nil,
            database: database,
            aiAnalysisService: mockService
        )

        for item in viewModel.detectedItems {
            viewModel.croppedPrimaryImages[item.id] = createTestImage()
        }

        viewModel.startEnrichment(settings: settings)
        try await Task.sleep(for: .milliseconds(50))
        viewModel.cancelEnrichment()
        try await Task.sleep(for: .milliseconds(50))

        #expect(!viewModel.isEnriching)
        #expect(!viewModel.enrichmentFinished)
        #expect(viewModel.enrichmentCompleted < viewModel.enrichmentTotal)
    }

    @Test("Analyze item call count matches item count")
    func testAnalyzeItemCallCountMatchesItemCount() async throws {
        let database = try createTestDatabase()
        let analysisResponse = createMockAnalysisResponse(itemCount: 3)
        let mockService = CountingMockAIAnalysisService()
        let settings = MockSettingsManager()

        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: analysisResponse,
            images: [createTestImage()],
            location: nil,
            database: database,
            aiAnalysisService: mockService
        )

        for item in viewModel.detectedItems {
            viewModel.croppedPrimaryImages[item.id] = createTestImage()
        }

        viewModel.startEnrichment(settings: settings)
        await waitForEnrichment(viewModel)

        #expect(mockService.analyzeItemCallCount == 3)
    }
}
