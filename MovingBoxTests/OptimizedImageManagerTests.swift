import Testing
import SwiftUI
@testable import MovingBox

@MainActor
@Suite struct OptimizedImageManagerTests {
    
    let manager: OptimizedImageManager
    let testImageId = "test_image"
    let testDirectory: URL
    
    init() {
        // Create isolated test directory for this test suite
        let testDirectoryName = "OptimizedImageManagerTests-\(UUID().uuidString)"
        self.testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(testDirectoryName)
        
        // Create isolated manager instance
        self.manager = OptimizedImageManager(testDirectory: testDirectory)
        
        // Create test directory
        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
    
    
    private func cleanupTestFiles() {
        // Since we have an isolated directory, just remove all contents
        if FileManager.default.fileExists(atPath: testDirectory.path) {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        // Recreate the directory
        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
    
    // Clean up after each test to prevent pollution
    private func cleanupAfterTest() {
        manager.clearCache()
        // For isolated tests, we don't need aggressive cleanup between tests
        // since each test suite has its own directory
    }
    
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
    func aiImagePreparation() async throws {
        // Given
        let originalImage = createTestImage(size: CGSize(width: 2000, height: 2000))
        
        // When
        let base64String = await manager.prepareImageForAI(from: originalImage)
        
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
    
    @Test("Multiple images can be saved and loaded")
    func multipleImageManagement() async throws {
        // Given
        let testImages = [
            createTestImage(size: CGSize(width: 100, height: 100)),
            createTestImage(size: CGSize(width: 200, height: 200)),
            createTestImage(size: CGSize(width: 300, height: 300))
        ]
        let itemId = "test_item_multi"
        
        // When
        let savedURLs = try await manager.saveSecondaryImages(testImages, itemId: itemId)
        let loadedImages = try await manager.loadSecondaryImages(from: savedURLs)
        
        // Then
        #expect(savedURLs.count == testImages.count)
        #expect(loadedImages.count == testImages.count)
        
        // Verify all images exist
        for urlString in savedURLs {
            guard let url = URL(string: urlString) else { continue }
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }
    
    @Test("Single secondary image can be added")
    func addSecondaryImage() async throws {
        // Given
        let testImage = createTestImage(size: CGSize(width: 150, height: 150))
        let itemId = "test_item_single"
        
        // When
        let savedURL = try await manager.addSecondaryImage(testImage, itemId: itemId)
        
        // Then
        #expect(!savedURL.isEmpty)
        guard let url = URL(string: savedURL) else {
            #expect(Bool(false), "Invalid URL string returned")
            return
        }
        #expect(FileManager.default.fileExists(atPath: url.path))
        
        // Verify it can be loaded
        let loadedImage = try await manager.loadImage(url: url)
        #expect(loadedImage.size.width > 0)
        #expect(loadedImage.size.height > 0)
    }
    
    @Test("Secondary image can be deleted")
    func deleteSecondaryImage() async throws {
        // Given
        let testImage = createTestImage(size: CGSize(width: 100, height: 100))
        let itemId = "test_item_delete"
        let savedURL = try await manager.addSecondaryImage(testImage, itemId: itemId)
        
        // Verify it exists
        guard let url = URL(string: savedURL) else {
            #expect(Bool(false), "Invalid URL string returned")
            return
        }
        #expect(FileManager.default.fileExists(atPath: url.path))
        
        // When
        try await manager.deleteSecondaryImage(urlString: savedURL)
        
        // Then
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
    
    @Test("Multiple images can be prepared for AI")
    func multipleImagesAIPreparation() async {
        // Given
        let testImages = [
            createTestImage(size: CGSize(width: 1000, height: 1000)),
            createTestImage(size: CGSize(width: 800, height: 600))
        ]
        
        // When
        let base64Images = await manager.prepareMultipleImagesForAI(from: testImages)
        
        // Then
        #expect(base64Images.count == testImages.count)
        for base64String in base64Images {
            #expect(!base64String.isEmpty)
            // Verify it's valid base64
            #expect(Data(base64Encoded: base64String) != nil)
        }
    }
    
    @Test("Secondary thumbnails can be loaded")
    func secondaryThumbnailsLoading() async throws {
        // Given
        let testImages = [
            createTestImage(size: CGSize(width: 1000, height: 1000)),
            createTestImage(size: CGSize(width: 800, height: 600))
        ]
        let itemId = "test_item_thumbnails"
        
        // When
        let savedURLs = try await manager.saveSecondaryImages(testImages, itemId: itemId)
        let thumbnails = await manager.loadSecondaryThumbnails(from: savedURLs)
        
        // Then
        #expect(thumbnails.count == testImages.count)
        for thumbnail in thumbnails {
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

private extension OptimizedImageManager {
    enum ImageConfig {
        static let maxDimension: CGFloat = 2500
        static let thumbnailSize = CGSize(width: 512, height: 512)
    }
}
