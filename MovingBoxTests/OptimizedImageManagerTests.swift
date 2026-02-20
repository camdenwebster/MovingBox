import SwiftUI
import Testing

@testable import MovingBox

@MainActor
@Suite struct OptimizedImageManagerTests {

    let manager = OptimizedImageManager.shared

    @Test("Image optimization reduces large images")
    func imageOptimization() async throws {
        // Given
        let originalSize = CGSize(width: 3000, height: 3000)
        let largeImage = createTestImage(size: originalSize)

        // When
        let optimizedImage = await manager.optimizeImage(largeImage)

        // Then
        #expect(optimizedImage.size.width < originalSize.width)
        #expect(optimizedImage.size.height < originalSize.height)
        #expect(optimizedImage.size.width <= OptimizedImageManager.ImageConfig.maxDimension)
        #expect(optimizedImage.size.height <= OptimizedImageManager.ImageConfig.maxDimension)
    }

    @Test("Small images remain unoptimized")
    func smallImageOptimization() async {
        // Given
        let originalSize = CGSize(width: 100, height: 100)
        let smallImage = createTestImage(size: originalSize)

        // When
        let optimizedImage = await manager.optimizeImage(smallImage)

        // Then
        #expect(optimizedImage.size == originalSize)
    }

    @Test("Image preparation for AI resizes to correct dimensions")
    func aiImagePreparation() async throws {
        // Given
        let originalImage = createTestImage(size: CGSize(width: 2000, height: 2000))

        // When
        let base64String = await manager.prepareImageForAI(from: originalImage)

        // Then
        #expect(base64String != nil)
    }

    @Test("Multiple images can be prepared for AI")
    func multipleImagesAIPreparation() async {
        // Given
        let testImages = [
            createTestImage(size: CGSize(width: 1000, height: 1000)),
            createTestImage(size: CGSize(width: 800, height: 600)),
        ]

        // When
        let base64Images = await manager.prepareMultipleImagesForAI(from: testImages)

        // Then
        #expect(base64Images.count == testImages.count)
        for base64String in base64Images {
            #expect(!base64String.isEmpty)
            #expect(Data(base64Encoded: base64String) != nil)
        }
    }

    @Test("processImage returns compressed JPEG data")
    func processImageReturnsData() async {
        // Given
        let testImage = createTestImage(size: CGSize(width: 500, height: 500))

        // When
        let data = await manager.processImage(testImage)

        // Then
        #expect(data != nil)
        if let data {
            #expect(data.count > 0)
            let reloaded = UIImage(data: data)
            #expect(reloaded != nil)
        }
    }

    @Test("thumbnailImage generates thumbnail from data")
    func thumbnailImageFromData() async {
        // Given
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        guard let jpegData = testImage.jpegData(compressionQuality: 0.8) else {
            #expect(Bool(false), "Failed to create JPEG data")
            return
        }
        let photoID = UUID().uuidString

        // When
        let thumbnail = await manager.thumbnailImage(from: jpegData, photoID: photoID)

        // Then
        #expect(thumbnail != nil)
        if let thumbnail {
            #expect(thumbnail.size.width <= OptimizedImageManager.ImageConfig.thumbnailSize.width)
            #expect(thumbnail.size.height <= OptimizedImageManager.ImageConfig.thumbnailSize.height)
        }
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Private Extensions

extension OptimizedImageManager {
    fileprivate enum ImageConfig {
        static let maxDimension: CGFloat = 2500
        static let thumbnailSize = CGSize(width: 512, height: 512)
    }
}
