//
//  MockServices.swift
//  MovingBox
//
//  Created by Claude Code on 9/10/25.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

@testable import MovingBox

// MARK: - Mock AI Analysis Service

@MainActor
class MockAIAnalysisService: AIAnalysisServiceProtocol {
    var shouldFail = false
    var shouldFailMultiItem = false
    var analyzeItemCallCount = 0

    var mockResponse = ImageDetails(
        title: "Test Item",
        quantity: "1",
        description: "A test item for mocking",
        make: "Test Make",
        model: "Test Model",
        category: "Electronics",
        location: "Test Location",
        price: "100.00",
        serialNumber: "TEST123"
    )

    var mockMultiItemResponse = MultiItemAnalysisResponse(
        items: [
            DetectedInventoryItem(
                title: "Mock Item 1",
                description: "First mock item",
                category: "Electronics",
                make: "Mock",
                model: "Test",
                estimatedPrice: "$99.99",
                confidence: 0.85,
                detections: [ItemDetection(sourceImageIndex: 0, boundingBox: [100, 150, 500, 700])]
            )
        ],
        detectedCount: 1,
        analysisType: "multi_item",
        confidence: 0.85
    )

    func getImageDetails(
        from images: [UIImage], settings: SettingsManager, modelContext: ModelContext
    ) async throws -> ImageDetails {
        if shouldFail {
            throw AIAnalysisError.invalidData
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        return mockResponse
    }

    func analyzeItem(
        from images: [UIImage], settings: SettingsManager, modelContext: ModelContext
    ) async throws -> ImageDetails {
        analyzeItemCallCount += 1

        if shouldFail {
            throw AIAnalysisError.invalidData
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        return mockResponse
    }

    func getMultiItemDetails(
        from images: [UIImage], settings: SettingsManager, modelContext: ModelContext
    ) async throws -> MultiItemAnalysisResponse {
        if shouldFailMultiItem {
            throw AIAnalysisError.invalidData
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        return mockMultiItemResponse
    }

    func cancelCurrentRequest() {
        // Mock implementation - no-op
    }
}

// MARK: - Mock Image Manager

@MainActor
class MockImageManager: ImageManagerProtocol {
    var shouldFail = false
    var mockImages: [UIImage] = []
    var mockURLs: [String] = []

    func saveImage(_ image: UIImage, id: String) async throws -> URL {
        if shouldFail {
            throw NSError(
                domain: "MockImageManager", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Mock save failed"])
        }
        return URL(string: "file:///mock/\(id).jpg")!
    }

    func saveSecondaryImages(_ images: [UIImage], itemId: String) async throws -> [String] {
        if shouldFail {
            throw NSError(
                domain: "MockImageManager", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Mock save failed"])
        }
        return images.enumerated().map { "file:///mock/\(itemId)_\($0.offset).jpg" }
    }

    func loadImage(url: URL) async throws -> UIImage {
        if shouldFail {
            throw NSError(
                domain: "MockImageManager", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Mock load failed"])
        }
        return mockImages.first ?? UIImage()
    }

    func loadSecondaryImages(from urls: [String]) async throws -> [UIImage] {
        if shouldFail {
            throw NSError(
                domain: "MockImageManager", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Mock load failed"])
        }
        return mockImages
    }

    func deleteSecondaryImage(urlString: String) async throws {
        if shouldFail {
            throw NSError(
                domain: "MockImageManager", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Mock delete failed"])
        }
        // Mock implementation - remove from mockURLs if exists
        if let index = mockURLs.firstIndex(of: urlString) {
            mockURLs.remove(at: index)
        }
    }

    func prepareImageForAI(from image: UIImage) async -> String? {
        if shouldFail {
            return nil
        }
        return "mock_base64_string_for_testing"
    }

    func getThumbnailURL(for id: String) -> URL? {
        return URL(string: "file:///mock/thumb_\(id).jpg")
    }
}

// MARK: - Mock Settings Manager

@MainActor
class MockSettingsManager: SettingsManager {
    private var _isPro = false
    private var _highQualityAnalysisEnabled = false
    private var _maxTokens = 1000

    override var isPro: Bool {
        get { return _isPro }
        set { _isPro = newValue }
    }

    override var highQualityAnalysisEnabled: Bool {
        get { return _highQualityAnalysisEnabled }
        set { _highQualityAnalysisEnabled = newValue }
    }

    override var maxTokens: Int {
        get { return _maxTokens }
        set { _maxTokens = newValue }
    }

    override var effectiveAIModel: String {
        return "google/gemini-3-flash-preview"
    }

    override var effectiveDetailLevel: String {
        return (isPro && highQualityAnalysisEnabled) ? "high" : "low"
    }

    override var effectiveImageResolution: CGFloat {
        return (isPro && highQualityAnalysisEnabled) ? 1250.0 : 512.0
    }
}

// MARK: - Test Data Helpers

extension InventoryItem {
    @MainActor
    static func createTestItem(in context: ModelContext) -> InventoryItem {
        let item = InventoryItem()
        item.title = "Test Item"
        item.desc = "A test item for unit testing"
        item.price = Decimal(100.0)
        item.make = "Test Make"
        item.model = "Test Model"
        item.serial = "TEST123"
        item.quantityString = "1"

        context.insert(item)
        return item
    }

    @MainActor
    static func createTestItemWithImages(in context: ModelContext) -> InventoryItem {
        let item = createTestItem(in: context)
        item.imageURL = URL(string: "file:///test/primary.jpg")
        item.secondaryPhotoURLs = [
            "file:///test/secondary1.jpg",
            "file:///test/secondary2.jpg",
        ]
        return item
    }
}

extension UIImage {
    static func createTestImage(
        size: CGSize = CGSize(width: 100, height: 100), color: UIColor = .blue
    ) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContext(size)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - Home Test Helpers

extension Home {
    @MainActor
    static func createTestHome(
        in context: ModelContext,
        name: String = "Test Home",
        address1: String = "123 Test St",
        city: String = "Test City",
        state: String = "CA",
        zip: String = "12345",
        country: String = "US",
        isPrimary: Bool = false,
        colorName: String = "green"
    ) -> Home {
        let home = Home(
            name: name,
            address1: address1,
            city: city,
            state: state,
            zip: zip,
            country: country
        )
        home.isPrimary = isPrimary
        home.colorName = colorName
        context.insert(home)
        return home
    }

    @MainActor
    static func createTestHomeWithLocations(
        in context: ModelContext,
        name: String = "Test Home",
        locationCount: Int = 3
    ) -> Home {
        let home = createTestHome(in: context, name: name)

        for i in 1...locationCount {
            let location = InventoryLocation(name: "Room \(i)", desc: "Test room \(i)")
            location.home = home
            context.insert(location)
        }

        return home
    }
}
