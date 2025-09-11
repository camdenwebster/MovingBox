//
//  MockServices.swift
//  MovingBox
//
//  Created by Claude Code on 9/10/25.
//

import Foundation
import SwiftUI
import SwiftData
import UIKit
@testable import MovingBox

// MARK: - Mock OpenAI Service

@MainActor
class MockOpenAIService: OpenAIServiceProtocol {
    var shouldFail = false
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
    
    func getImageDetails(from images: [UIImage], settings: SettingsManager, modelContext: ModelContext) async throws -> ImageDetails {
        if shouldFail {
            throw OpenAIError.invalidData
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return mockResponse
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
            throw NSError(domain: "MockImageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save failed"])
        }
        return URL(string: "file:///mock/\(id).jpg")!
    }
    
    func saveSecondaryImages(_ images: [UIImage], itemId: String) async throws -> [String] {
        if shouldFail {
            throw NSError(domain: "MockImageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save failed"])
        }
        return images.enumerated().map { "file:///mock/\(itemId)_\($0.offset).jpg" }
    }
    
    func loadImage(url: URL) async throws -> UIImage {
        if shouldFail {
            throw NSError(domain: "MockImageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock load failed"])
        }
        return mockImages.first ?? UIImage()
    }
    
    func loadSecondaryImages(from urls: [String]) async throws -> [UIImage] {
        if shouldFail {
            throw NSError(domain: "MockImageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock load failed"])
        }
        return mockImages
    }
    
    func deleteSecondaryImage(urlString: String) async throws {
        if shouldFail {
            throw NSError(domain: "MockImageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock delete failed"])
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
        return isPro ? "gpt-4-vision-preview" : "gpt-4o-mini"
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
            "file:///test/secondary2.jpg"
        ]
        return item
    }
}

extension UIImage {
    static func createTestImage(size: CGSize = CGSize(width: 100, height: 100), color: UIColor = .blue) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContext(size)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}