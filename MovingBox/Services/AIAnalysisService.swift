//
//  AIAnalysisService.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import Foundation
import MovingBoxAIAnalysis
import SwiftData
import UIKit

// MARK: - Mock Service for Testing

#if DEBUG
    class MockAIAnalysisService: AIAnalysisServiceProtocol {
        var shouldFail = false
        var shouldFailMultiItem = false

        var mockResponse = ImageDetails(
            title: "Office Desk Chair",
            quantity: "1",
            description: "Ergonomic office chair with adjustable height and lumbar support",
            make: "Herman Miller",
            model: "Aeron",
            category: "Furniture",
            location: "Home Office",
            price: "$1,295.00",
            serialNumber: ""
        )

        var mockMultiItemResponse = MultiItemAnalysisResponse(
            items: [
                DetectedInventoryItem(
                    title: "Office Desk Chair",
                    description: "Ergonomic office chair with adjustable height and lumbar support",
                    category: "Furniture",
                    make: "Herman Miller",
                    model: "Aeron",
                    estimatedPrice: "$1,295.00",
                    confidence: 0.92,
                    detections: [ItemDetection(sourceImageIndex: 0, boundingBox: [50, 100, 600, 450])]
                ),
                DetectedInventoryItem(
                    title: "MacBook Pro",
                    description: "15-inch laptop with silver finish",
                    category: "Electronics",
                    make: "Apple",
                    model: "MacBook Pro 15-inch",
                    estimatedPrice: "$2,399.00",
                    confidence: 0.95,
                    detections: [ItemDetection(sourceImageIndex: 0, boundingBox: [200, 500, 550, 900])]
                ),
                DetectedInventoryItem(
                    title: "Standing Desk",
                    description: "Height-adjustable standing desk with electric controls",
                    category: "Furniture",
                    make: "Uplift",
                    model: "V2",
                    estimatedPrice: "$799.00",
                    confidence: 0.88,
                    detections: [ItemDetection(sourceImageIndex: 0, boundingBox: [300, 50, 950, 950])]
                ),
            ],
            detectedCount: 3,
            analysisType: "multi_item",
            confidence: 0.92
        )

        func getImageDetails(from images: [UIImage], settings: AIAnalysisSettings, context: AIAnalysisContext)
            async throws
            -> ImageDetails
        {
            print("🧪 MockAIAnalysisService: getImageDetails called with \(images.count) images")
            if shouldFail {
                print("🧪 MockAIAnalysisService: Simulating failure")
                throw AIAnalysisError.invalidData
            }

            print("🧪 MockAIAnalysisService: Simulating analysis delay...")
            try await Task.sleep(nanoseconds: 500_000_000)

            print("🧪 MockAIAnalysisService: Returning mock response")
            return mockResponse
        }

        func analyzeItem(from images: [UIImage], settings: AIAnalysisSettings, context: AIAnalysisContext)
            async throws
            -> ImageDetails
        {
            print("🧪 MockAIAnalysisService: analyzeItem called with \(images.count) images")
            if shouldFail {
                print("🧪 MockAIAnalysisService: Simulating failure")
                throw AIAnalysisError.invalidData
            }

            print("🧪 MockAIAnalysisService: Simulating analysis delay...")
            try await Task.sleep(nanoseconds: 500_000_000)

            print("🧪 MockAIAnalysisService: Returning mock response")
            return mockResponse
        }

        func getMultiItemDetails(
            from images: [UIImage],
            settings: AIAnalysisSettings,
            context: AIAnalysisContext,
            narrationContext: String? = nil,
            onPartialResponse: ((MultiItemAnalysisResponse) -> Void)? = nil
        )
            async throws -> MultiItemAnalysisResponse
        {
            print("🧪 MockAIAnalysisService: getMultiItemDetails called with \(images.count) images")
            if shouldFailMultiItem {
                print("🧪 MockAIAnalysisService: Simulating multi-item failure")
                throw AIAnalysisError.invalidData
            }

            print("🧪 MockAIAnalysisService: Simulating multi-item analysis delay...")
            try await Task.sleep(nanoseconds: 500_000_000)

            print(
                "🧪 MockAIAnalysisService: Returning mock multi-item response with \(mockMultiItemResponse.items?.count ?? 0) items"
            )
            onPartialResponse?(mockMultiItemResponse)
            return mockMultiItemResponse
        }

        func cancelCurrentRequest() {
        }
    }
#endif

// MARK: - Service Factory

@MainActor
enum AIAnalysisServiceFactory {
    static func create() -> AIAnalysisServiceProtocol {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("Mock-AI") {
                print("🧪 AIAnalysisServiceFactory: Creating MockAIAnalysisService for testing")
                return MockAIAnalysisService()
            }
        #endif
        print("🔧 AIAnalysisServiceFactory: Creating real AIAnalysisService")
        return AIAnalysisService(
            imageOptimizer: OptimizedImageManager.shared,
            telemetryTracker: TelemetryManager.shared
        )
    }
}

// MARK: - Image Manager Protocol

protocol ImageManagerProtocol {
    func saveImage(_ image: UIImage, id: String) async throws -> URL
    func saveSecondaryImages(_ images: [UIImage], itemId: String) async throws -> [String]
    func loadImage(url: URL) async throws -> UIImage
    func loadSecondaryImages(from urls: [String]) async throws -> [UIImage]
    func deleteSecondaryImage(urlString: String) async throws
    func prepareImageForAI(from image: UIImage) async -> String?
    func getThumbnailURL(for id: String) -> URL?
}
