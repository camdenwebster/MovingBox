//
//  BoundingBoxCropperTests.swift
//  MovingBoxTests
//
//  Tests for bounding box detection and image cropping
//

import Foundation
import MovingBoxAIAnalysis
import SwiftData
import Testing
import UIKit

@testable import MovingBox

@Suite("Bounding Box Cropper Tests")
struct BoundingBoxCropperTests {

    // MARK: - Helpers

    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            Home.self,
            InsurancePolicy.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: - ItemDetection Codable Tests

    @Test("ItemDetection encodes and decodes correctly")
    func testItemDetectionCodable() throws {
        let detection = ItemDetection(sourceImageIndex: 0, boundingBox: [100, 200, 500, 800])
        let data = try JSONEncoder().encode(detection)
        let decoded = try JSONDecoder().decode(ItemDetection.self, from: data)

        #expect(decoded.sourceImageIndex == 0)
        #expect(decoded.boundingBox == [100, 200, 500, 800])
    }

    @Test("DetectedInventoryItem decodes with detections")
    func testDetectedItemWithDetections() throws {
        let json = """
            {
                "id": "test-1",
                "title": "Laptop",
                "description": "A laptop",
                "category": "Electronics",
                "make": "Apple",
                "model": "MacBook",
                "estimatedPrice": "$1000",
                "confidence": 0.95,
                "detections": [
                    {"sourceImageIndex": 0, "boundingBox": [100, 200, 500, 800]}
                ]
            }
            """
        let data = json.data(using: .utf8)!
        let item = try JSONDecoder().decode(DetectedInventoryItem.self, from: data)

        #expect(item.detections?.count == 1)
        #expect(item.detections?.first?.sourceImageIndex == 0)
        #expect(item.detections?.first?.boundingBox == [100, 200, 500, 800])
    }

    @Test("DetectedInventoryItem decodes without detections for backward compat")
    func testDetectedItemWithoutDetections() throws {
        let json = """
            {
                "id": "test-2",
                "title": "Chair",
                "description": "A chair",
                "category": "Furniture",
                "make": "IKEA",
                "model": "Markus",
                "estimatedPrice": "$200",
                "confidence": 0.85
            }
            """
        let data = json.data(using: .utf8)!
        let item = try JSONDecoder().decode(DetectedInventoryItem.self, from: data)

        #expect(item.detections == nil)
        #expect(item.title == "Chair")
    }

    // MARK: - BoundingBoxCropper.crop Tests

    @Test("Crop with valid coordinates returns cropped image")
    func testCropValidCoordinates() async {
        let image = createTestImage(width: 1000, height: 1000)
        let boundingBox = [250, 250, 750, 750]  // Center crop

        let result = await BoundingBoxCropper.crop(image: image, boundingBox: boundingBox, paddingFraction: 0.0)

        #expect(result != nil)
        if let result, let cgImage = result.cgImage {
            // Should be approximately 500x500 pixels
            #expect(cgImage.width == 500)
            #expect(cgImage.height == 500)
        }
    }

    @Test("Crop with padding expands the crop region")
    func testCropWithPadding() async {
        let image = createTestImage(width: 1000, height: 1000)
        let boundingBox = [250, 250, 750, 750]  // Center crop

        let result = await BoundingBoxCropper.crop(image: image, boundingBox: boundingBox, paddingFraction: 0.05)

        #expect(result != nil)
        if let result, let cgImage = result.cgImage {
            // With 5% padding on a 500px crop, should be ~550px (clamped to image bounds)
            #expect(cgImage.width >= 500)
            #expect(cgImage.height >= 500)
        }
    }

    @Test("Crop clamps to image bounds")
    func testCropClampsToImageBounds() async {
        let image = createTestImage(width: 1000, height: 1000)
        // Bounding box near edge - padding would extend beyond image
        let boundingBox = [0, 0, 200, 200]

        let result = await BoundingBoxCropper.crop(image: image, boundingBox: boundingBox, paddingFraction: 0.1)

        #expect(result != nil)
        if let result, let cgImage = result.cgImage {
            // Should not exceed image dimensions
            #expect(cgImage.width <= 1000)
            #expect(cgImage.height <= 1000)
        }
    }

    @Test("Crop returns nil for invalid bounding box with too few elements")
    func testCropInvalidBoundingBoxTooFew() async {
        let image = createTestImage(width: 1000, height: 1000)
        let result = await BoundingBoxCropper.crop(image: image, boundingBox: [100, 200])

        #expect(result == nil)
    }

    @Test("Crop returns nil for zero-dimension bounding box")
    func testCropZeroDimensionBoundingBox() async {
        let image = createTestImage(width: 1000, height: 1000)
        // xmin == xmax means zero width
        let result = await BoundingBoxCropper.crop(image: image, boundingBox: [100, 500, 400, 500])

        #expect(result == nil)
    }

    @Test("Crop returns nil for inverted bounding box")
    func testCropInvertedBoundingBox() async {
        let image = createTestImage(width: 1000, height: 1000)
        // ymin > ymax
        let result = await BoundingBoxCropper.crop(image: image, boundingBox: [800, 200, 100, 600])

        #expect(result == nil)
    }

    // MARK: - BoundingBoxCropper.cropDetections Tests

    @Test("cropDetections returns primary and secondaries")
    func testCropDetectionsMultiple() async {
        let image = createTestImage(width: 1000, height: 1000)
        let item = DetectedInventoryItem(
            title: "Test",
            description: "Test item",
            category: "Test",
            make: "",
            model: "",
            estimatedPrice: "$10",
            confidence: 0.9,
            detections: [
                ItemDetection(sourceImageIndex: 0, boundingBox: [100, 100, 400, 400]),
                ItemDetection(sourceImageIndex: 0, boundingBox: [500, 500, 900, 900]),
            ]
        )

        let (primary, secondary) = await BoundingBoxCropper.cropDetections(for: item, from: [image])

        #expect(primary != nil)
        #expect(secondary.count == 1)
    }

    @Test("cropDetections returns nil primary when no detections")
    func testCropDetectionsNoDetections() async {
        let image = createTestImage(width: 1000, height: 1000)
        let item = DetectedInventoryItem(
            title: "Test",
            description: "Test item",
            category: "Test",
            make: "",
            model: "",
            estimatedPrice: "$10",
            confidence: 0.9,
            detections: nil
        )

        let (primary, secondary) = await BoundingBoxCropper.cropDetections(for: item, from: [image])

        #expect(primary == nil)
        #expect(secondary.isEmpty)
    }

    @Test("cropDetections skips out-of-range source image indices")
    func testCropDetectionsOutOfRangeIndex() async {
        let image = createTestImage(width: 1000, height: 1000)
        let item = DetectedInventoryItem(
            title: "Test",
            description: "Test item",
            category: "Test",
            make: "",
            model: "",
            estimatedPrice: "$10",
            confidence: 0.9,
            detections: [
                ItemDetection(sourceImageIndex: 5, boundingBox: [100, 100, 400, 400])
            ]
        )

        let (primary, secondary) = await BoundingBoxCropper.cropDetections(for: item, from: [image])

        #expect(primary == nil)
        #expect(secondary.isEmpty)
    }

    // MARK: - ViewModel Cropping Integration

    @Test("ViewModel primaryImage falls back to source image when no detections")
    @MainActor
    func testViewModelPrimaryImageFallback() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let testImage = createTestImage(width: 100, height: 100)

        let response = MultiItemAnalysisResponse(
            items: [
                DetectedInventoryItem(
                    title: "Test",
                    description: "Test",
                    category: "Test",
                    make: "",
                    model: "",
                    estimatedPrice: "$10",
                    confidence: 0.9,
                    detections: nil
                )
            ],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.9
        )

        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: response,
            images: [testImage],
            location: nil,
            modelContext: context
        )

        await viewModel.computeCroppedImages()

        // With no detections, primaryImage should fall back to first source image
        let item = viewModel.detectedItems[0]
        let result = viewModel.primaryImage(for: item)
        #expect(result != nil)
    }

    @Test("ViewModel computes cropped images from detections")
    @MainActor
    func testViewModelComputesCroppedImages() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let testImage = createTestImage(width: 1000, height: 1000)

        let response = MultiItemAnalysisResponse(
            items: [
                DetectedInventoryItem(
                    title: "Test",
                    description: "Test",
                    category: "Test",
                    make: "",
                    model: "",
                    estimatedPrice: "$10",
                    confidence: 0.9,
                    detections: [
                        ItemDetection(sourceImageIndex: 0, boundingBox: [100, 100, 500, 500])
                    ]
                )
            ],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.9
        )

        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: response,
            images: [testImage],
            location: nil,
            modelContext: context
        )

        await viewModel.computeCroppedImages()

        #expect(viewModel.hasCroppedImages)
        let item = viewModel.detectedItems[0]
        #expect(viewModel.croppedPrimaryImages[item.id] != nil)
    }

    @Test("ViewModel computeCroppedImages is idempotent")
    @MainActor
    func testViewModelCroppingIdempotent() async throws {
        let container = try createTestContainer()
        let context = ModelContext(container)
        let testImage = createTestImage(width: 1000, height: 1000)

        let response = MultiItemAnalysisResponse(
            items: [
                DetectedInventoryItem(
                    title: "Test",
                    description: "Test",
                    category: "Test",
                    make: "",
                    model: "",
                    estimatedPrice: "$10",
                    confidence: 0.9,
                    detections: [
                        ItemDetection(sourceImageIndex: 0, boundingBox: [100, 100, 500, 500])
                    ]
                )
            ],
            detectedCount: 1,
            analysisType: "multi_item",
            confidence: 0.9
        )

        let viewModel = MultiItemSelectionViewModel(
            analysisResponse: response,
            images: [testImage],
            location: nil,
            modelContext: context
        )

        await viewModel.computeCroppedImages()
        let firstCount = viewModel.croppedPrimaryImages.count

        // Calling again should not change anything
        await viewModel.computeCroppedImages()
        #expect(viewModel.croppedPrimaryImages.count == firstCount)
    }

    private func createTestImage(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.blue.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
