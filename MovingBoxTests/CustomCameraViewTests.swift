import AVFoundation
import SwiftUI
import Testing

@testable import MovingBox

@MainActor
@Suite struct MultiPhotoCameraViewTests {

    @Test("CaptureMode enum has correct cases")
    func testCaptureModeEnum() {
        let singleMode = CaptureMode.singleItem
        let multiMode = CaptureMode.multiItem
        let videoMode = CaptureMode.video

        #expect(singleMode.displayName == "Single")
        #expect(multiMode.displayName == "Multi")
        #expect(videoMode.displayName == "Video")
        #expect(singleMode.description == "Multiple photos of one item")
        #expect(multiMode.description == "Multiple photos with multiple items")
        #expect(videoMode.description == "Analyze items from a video")
    }

    @Test("CaptureMode max photos logic")
    func testCaptureModeLimits() {
        let singleMode = CaptureMode.singleItem
        let multiMode = CaptureMode.multiItem
        let videoMode = CaptureMode.video

        #expect(singleMode.maxPhotosAllowed(isPro: false) == 1)
        #expect(singleMode.maxPhotosAllowed(isPro: true) == CaptureMode.maxPhotosPerAnalysis)
        #expect(multiMode.maxPhotosAllowed(isPro: false) == CaptureMode.maxPhotosPerAnalysis)
        #expect(multiMode.maxPhotosAllowed(isPro: true) == CaptureMode.maxPhotosPerAnalysis)
        #expect(videoMode.maxPhotosAllowed(isPro: true) == 0)
    }

    @Test("CaptureMode validation")
    func testCaptureModeValidation() {
        let singleMode = CaptureMode.singleItem
        let multiMode = CaptureMode.multiItem
        let videoMode = CaptureMode.video

        #expect(singleMode.isValidPhotoCount(1) == true)
        #expect(singleMode.isValidPhotoCount(CaptureMode.maxPhotosPerAnalysis) == true)
        #expect(singleMode.isValidPhotoCount(CaptureMode.maxPhotosPerAnalysis + 1) == false)
        #expect(multiMode.isValidPhotoCount(1) == true)
        #expect(multiMode.isValidPhotoCount(CaptureMode.maxPhotosPerAnalysis) == true)
        #expect(multiMode.isValidPhotoCount(CaptureMode.maxPhotosPerAnalysis + 1) == false)
        #expect(videoMode.isValidPhotoCount(1) == false)
    }

    @Test("MultiPhotoCameraView single item mode initializer")
    func testSingleItemModeInitializer() async throws {
        let capturedImages: [UIImage] = []
        var permissionGranted: Bool? = nil

        let view = MultiPhotoCameraView(
            capturedImages: .constant(capturedImages),
            captureMode: .singleItem,
            onPermissionCheck: { granted in
                permissionGranted = granted
            },
            onComplete: { _, _ in }
        )

        let viewType = type(of: view)
        #expect(viewType == MultiPhotoCameraView.self)
    }

    @Test("MultiPhotoCameraView multi item mode initializer")
    func testMultiItemModeInitializer() async throws {
        let capturedImages: [UIImage] = []
        var completionResult: ([UIImage], CaptureMode)? = nil

        let view = MultiPhotoCameraView(
            capturedImages: .constant(capturedImages),
            captureMode: .multiItem,
            onPermissionCheck: { _ in },
            onComplete: { images, mode in
                completionResult = (images, mode)
            }
        )

        let viewType = type(of: view)
        #expect(viewType == MultiPhotoCameraView.self)
    }

    @Test("MultiPhotoCameraView backward compatibility")
    func testBackwardCompatibility() async throws {
        let capturedImages: [UIImage] = []

        let view = MultiPhotoCameraView(
            capturedImages: .constant(capturedImages),
            onPermissionCheck: { _ in },
            onComplete: { _, _ in }
        )

        let viewType = type(of: view)
        #expect(viewType == MultiPhotoCameraView.self)
    }

    @Test("CaptureMode UI behavior")
    func testCaptureModeBehavior() {
        let singleMode = CaptureMode.singleItem
        let multiMode = CaptureMode.multiItem
        let videoMode = CaptureMode.video

        #expect(singleMode.showsPhotoPickerButton == true)
        #expect(multiMode.showsPhotoPickerButton == true)
        #expect(videoMode.showsPhotoPickerButton == false)
        #expect(singleMode.showsThumbnailScrollView == true)
        #expect(multiMode.showsThumbnailScrollView == true)
        #expect(videoMode.showsThumbnailScrollView == false)
        #expect(singleMode.allowsMultipleCaptures == true)
        #expect(multiMode.allowsMultipleCaptures == true)
        #expect(videoMode.allowsMultipleCaptures == false)
    }

    // MARK: - Helper Methods

    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
