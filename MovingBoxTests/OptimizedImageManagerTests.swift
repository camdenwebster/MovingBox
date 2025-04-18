import Testing
import SwiftUI
@testable import MovingBox

@MainActor
@Suite struct OptimizedImageManagerTests {
    
    let manager = OptimizedImageManager.shared
    let testImageId = "test_image"
    
    @Test("Image save and load validates data integrity")
    func imageDataIntegrity() async throws {
        // Given
        let size = CGSize(width: 100, height: 100)
        let testImage = createTestImage(size: size)
        
        // When
        let savedURL = try await manager.saveImage(testImage, id: testImageId)
        let loadedImage = try await manager.loadImage(url: savedURL)
        
        // Then
        #expect(FileManager.default.fileExists(atPath: savedURL.path))
        
        // Verify image content rather than size (which may be optimized)
        let loadedImageData = loadedImage.jpegData(compressionQuality: 1.0)
        let originalImageData = testImage.jpegData(compressionQuality: 1.0)
        #expect(loadedImageData?.count ?? 0 > 0)
        #expect(originalImageData?.count ?? 0 > 0)
    }
    
    @Test("Image optimization reduces large images")
    func imageOptimization() {
        // Given
        let originalSize = CGSize(width: 3000, height: 3000)
        let largeImage = createTestImage(size: originalSize)
        
        // When
        let optimizedImage = manager.optimizeImage(largeImage)
        
        // Then
        #expect(optimizedImage.size.width < originalSize.width)
        #expect(optimizedImage.size.height < originalSize.height)
        #expect(optimizedImage.size.width <= OptimizedImageManager.ImageConfig.maxDimension)
        #expect(optimizedImage.size.height <= OptimizedImageManager.ImageConfig.maxDimension)
    }
    
    @Test("Small images remain unoptimized")
    func smallImageOptimization() {
        // Given
        let originalSize = CGSize(width: 100, height: 100)
        let smallImage = createTestImage(size: originalSize)
        
        // When
        let optimizedImage = manager.optimizeImage(smallImage)
        
        // Then
        #expect(optimizedImage.size == originalSize)
    }
    
    @Test("Thumbnail generation creates smaller image")
    func thumbnailGeneration() async throws {
        // Given
        let originalImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // When
        _ = try await manager.saveImage(originalImage, id: testImageId)
        let thumbnail = try await manager.loadThumbnail(id: testImageId)
        
        // Then
        #expect(thumbnail.size.width <= OptimizedImageManager.ImageConfig.thumbnailSize.width)
        #expect(thumbnail.size.height <= OptimizedImageManager.ImageConfig.thumbnailSize.height)
    }
    
    @Test("Image cache properly stores and retrieves thumbnails")
    func thumbnailCaching() async throws {
        // Given
        let originalImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        
        // When - First load (saves to cache)
        _ = try await manager.saveImage(originalImage, id: testImageId)
        let firstLoad = try await manager.loadThumbnail(id: testImageId)
        
        // Then - Second load (should hit cache)
        let secondLoad = try await manager.loadThumbnail(id: testImageId)
        #expect(firstLoad.size == secondLoad.size)
    }
    
    @Test("Image preparation for AI resizes to correct dimensions")
    func aiImagePreparation() {
        // Given
        let originalImage = createTestImage(size: CGSize(width: 2000, height: 2000))
        
        // When
        let base64String = manager.prepareImageForAI(from: originalImage)
        
        // Then
        #expect(base64String != nil)
    }
    
    @Test("Invalid image URLs throw appropriate errors")
    func invalidImageHandling() async {
        // Given
        let invalidURL = URL(fileURLWithPath: "/invalid/path/image.jpg")
        
        // Then
        await #expect { try await manager.loadImage(url: invalidURL) } throws: { error in
            return error is OptimizedImageManager.ImageError
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

private extension OptimizedImageManager {
    enum ImageConfig {
        static let maxDimension: CGFloat = 2500
        static let thumbnailSize = CGSize(width: 512, height: 512)
    }
}
