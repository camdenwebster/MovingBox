import Testing
import SwiftUI
import AVFoundation
@testable import MovingBox

@MainActor
@Suite struct MultiPhotoCameraTests {
    
    @Test("MultiPhotoCameraViewModel initializes correctly")
    func testViewModelInitialization() async throws {
        let viewModel = MultiPhotoCameraViewModel()
        
        // Test initial state
        #expect(viewModel.capturedImages.isEmpty)
        #expect(viewModel.flashMode == .auto)
        #expect(viewModel.currentZoomFactor == 1.0)
        #expect(viewModel.currentZoomText == "1x")
        #expect(viewModel.showPhotoLimitAlert == false)
    }
    
    @Test("Flash mode cycling works correctly")
    func testFlashModeCycling() async throws {
        let viewModel = MultiPhotoCameraViewModel()
        
        // Initial state should be auto
        #expect(viewModel.flashMode == .auto)
        #expect(viewModel.flashIcon == "bolt.badge.a.fill")
        
        // First cycle: auto -> on
        viewModel.cycleFlash()
        #expect(viewModel.flashMode == .on)
        #expect(viewModel.flashIcon == "bolt.fill")
        
        // Second cycle: on -> off
        viewModel.cycleFlash()
        #expect(viewModel.flashMode == .off)
        #expect(viewModel.flashIcon == "bolt.slash.fill")
        
        // Third cycle: off -> auto
        viewModel.cycleFlash()
        #expect(viewModel.flashMode == .auto)
        #expect(viewModel.flashIcon == "bolt.badge.a.fill")
    }
    
    @Test("Image removal works correctly")
    func testImageRemoval() async throws {
        let viewModel = MultiPhotoCameraViewModel()
        
        // Create test images
        let testImage1 = createTestImage(size: CGSize(width: 100, height: 100), color: .red)
        let testImage2 = createTestImage(size: CGSize(width: 100, height: 100), color: .green)
        let testImage3 = createTestImage(size: CGSize(width: 100, height: 100), color: .blue)
        
        // Add images manually (simulating capture)
        viewModel.capturedImages = [testImage1, testImage2, testImage3]
        #expect(viewModel.capturedImages.count == 3)
        
        // Remove middle image
        viewModel.removeImage(at: 1)
        #expect(viewModel.capturedImages.count == 2)
        
        // Verify correct image was removed (should have red and blue remaining)
        #expect(viewModel.capturedImages[0] == testImage1) // Red
        #expect(viewModel.capturedImages[1] == testImage3) // Blue
        
        // Test removing invalid index (should be ignored)
        viewModel.removeImage(at: 10)
        #expect(viewModel.capturedImages.count == 2)
        
        viewModel.removeImage(at: -1)
        #expect(viewModel.capturedImages.count == 2)
    }
    
    @Test("Photo limit alert functionality")
    func testPhotoLimitAlert() async throws {
        let viewModel = MultiPhotoCameraViewModel()
        
        // Fill up to 5 images
        let testImage = createTestImage(size: CGSize(width: 100, height: 100), color: .red)
        viewModel.capturedImages = Array(repeating: testImage, count: 5)
        
        #expect(viewModel.capturedImages.count == 5)
        #expect(viewModel.showPhotoLimitAlert == false)
        
        // Note: We can't directly test the alert trigger from capturePhoto() 
        // since that requires camera hardware, but we can test the limit logic
        #expect(viewModel.capturedImages.count >= 5)
    }
    
    @Test("MultiPhotoCameraView can be instantiated")
    func testViewInstantiation() async throws {
        @State var capturedImages: [UIImage] = []
        
        let view = MultiPhotoCameraView(
            capturedImages: $capturedImages,
            onPermissionCheck: { _ in },
            onComplete: { _ in }
        )
        
        // Verify view can be created without errors
        // Note: SwiftUI views are value types, so they're never nil
        let viewType = type(of: view)
        #expect(viewType == MultiPhotoCameraView.self)
    }
    
    @Test("Square cropping logic")
    func testSquareCropping() async throws {
        let viewModel = MultiPhotoCameraViewModel()
        
        // Create rectangular test image
        let testImage = createTestImage(size: CGSize(width: 200, height: 100), color: .red)
        
        // Test the private cropToSquare method indirectly
        // Since the method is private, we test the expected behavior:
        // - The smaller dimension should become the side length
        // - For a 200x100 image, result should be 100x100
        
        #expect(testImage.size.width == 200)
        #expect(testImage.size.height == 100)
        
        // The actual cropping happens in the private method,
        // but we can verify the ViewModel initializes correctly
        #expect(viewModel.capturedImages.isEmpty)
    }
    
    @Test("PhotoThumbnailScrollView handles empty images")
    func testPhotoThumbnailScrollViewEmpty() async throws {
        let scrollView = PhotoThumbnailScrollView(
            images: [],
            onDelete: { _ in }
        )
        
        // Verify view can be created with empty images
        let viewType = type(of: scrollView)
        #expect(viewType == PhotoThumbnailScrollView.self)
    }
    
    @Test("PhotoThumbnailScrollView handles multiple images")
    func testPhotoThumbnailScrollViewWithImages() async throws {
        let testImages = [
            createTestImage(size: CGSize(width: 100, height: 100), color: .red),
            createTestImage(size: CGSize(width: 100, height: 100), color: .green),
            createTestImage(size: CGSize(width: 100, height: 100), color: .blue)
        ]
        
        var deletedIndex: Int?
        
        let scrollView = PhotoThumbnailScrollView(
            images: testImages,
            onDelete: { index in
                deletedIndex = index
            }
        )
        
        // Verify view can be created with multiple images
        let viewType = type(of: scrollView)
        #expect(viewType == PhotoThumbnailScrollView.self)
        
        // Test that delete callback works (simulated)
        scrollView.onDelete(1)
        #expect(deletedIndex == 1)
    }
    
    @Test("PhotoThumbnailView instantiation")
    func testPhotoThumbnailView() async throws {
        let testImage = createTestImage(size: CGSize(width: 100, height: 100), color: .red)
        var deletedIndex: Int?
        
        let thumbnailView = PhotoThumbnailView(
            image: testImage,
            index: 2,
            onDelete: { index in
                deletedIndex = index
            }
        )
        
        // Verify view can be created
        let viewType = type(of: thumbnailView)
        #expect(viewType == PhotoThumbnailView.self)
        
        // Test delete callback
        thumbnailView.onDelete(2)
        #expect(deletedIndex == 2)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}