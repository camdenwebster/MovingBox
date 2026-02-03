//
//  MockServices.swift
//  MovingBox
//
//  Created by Claude Code on 9/10/25.
//

import Foundation
import SQLiteData
import SwiftUI
import UIKit

@testable import MovingBox

// MARK: - Mock OpenAI Service

@MainActor
class MockOpenAIService: OpenAIServiceProtocol {
    var shouldFail = false
    var shouldFailMultiItem = false

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
                confidence: 0.85
            )
        ],
        detectedCount: 1,
        analysisType: "multi_item",
        confidence: 0.85
    )

    func getImageDetails(
        from images: [UIImage], settings: SettingsManager, database: any DatabaseWriter
    ) async throws -> ImageDetails {
        if shouldFail {
            throw OpenAIError.invalidData
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        return mockResponse
    }

    func getMultiItemDetails(
        from images: [UIImage], settings: SettingsManager, database: any DatabaseWriter
    ) async throws -> MultiItemAnalysisResponse {
        if shouldFailMultiItem {
            throw OpenAIError.invalidData
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
        if isPro && highQualityAnalysisEnabled {
            return "gpt-5-mini"
        }
        return "gpt-4o"
    }

    override var effectiveDetailLevel: String {
        return (isPro && highQualityAnalysisEnabled) ? "high" : "low"
    }

    override var effectiveImageResolution: CGFloat {
        return (isPro && highQualityAnalysisEnabled) ? 1250.0 : 512.0
    }
}

// MARK: - Test Data Helpers

@MainActor
@discardableResult
func createTestItem(in database: DatabaseQueue) throws -> SQLiteInventoryItem {
    let item = SQLiteInventoryItem(
        id: UUID(),
        title: "Test Item",
        quantityString: "1",
        desc: "A test item for unit testing",
        serial: "TEST123",
        model: "Test Model",
        make: "Test Make",
        price: Decimal(100.0)
    )
    try database.write { db in
        try SQLiteInventoryItem.insert { item }.execute(db)
    }
    return item
}

@MainActor
@discardableResult
func createTestItemWithImages(in database: DatabaseQueue) throws -> SQLiteInventoryItem {
    var item = SQLiteInventoryItem(
        id: UUID(),
        title: "Test Item",
        quantityString: "1",
        desc: "A test item for unit testing",
        serial: "TEST123",
        model: "Test Model",
        make: "Test Make",
        price: Decimal(100.0)
    )
    item.imageURL = URL(string: "file:///test/primary.jpg")
    item.secondaryPhotoURLs = [
        "file:///test/secondary1.jpg",
        "file:///test/secondary2.jpg",
    ]
    try database.write { db in
        try SQLiteInventoryItem.insert { item }.execute(db)
    }
    return item
}

// MARK: - Home Test Helpers

@MainActor
@discardableResult
func createTestHome(
    in database: DatabaseQueue,
    name: String = "Test Home",
    address1: String = "123 Test St",
    city: String = "Test City",
    state: String = "CA",
    zip: String = "12345",
    country: String = "US",
    isPrimary: Bool = false,
    colorName: String = "green"
) throws -> SQLiteHome {
    let home = SQLiteHome(
        id: UUID(),
        name: name,
        address1: address1,
        city: city,
        state: state,
        zip: zip,
        country: country,
        isPrimary: isPrimary,
        colorName: colorName
    )
    try database.write { db in
        try SQLiteHome.insert { home }.execute(db)
    }
    return home
}

@MainActor
@discardableResult
func createTestHomeWithLocations(
    in database: DatabaseQueue,
    name: String = "Test Home",
    locationCount: Int = 3
) throws -> SQLiteHome {
    let home = try createTestHome(in: database, name: name)

    for i in 1...locationCount {
        let location = SQLiteInventoryLocation(
            id: UUID(),
            name: "Room \(i)",
            desc: "Test room \(i)",
            homeID: home.id
        )
        try database.write { db in
            try SQLiteInventoryLocation.insert { location }.execute(db)
        }
    }

    return home
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
