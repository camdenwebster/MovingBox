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

        #expect(singleMode.displayName == "Single")
        #expect(multiMode.displayName == "Multi")
        #expect(singleMode.description == "Multiple photos of one item")
        #expect(multiMode.description == "One photo with multiple items")
    }

    @Test("CaptureMode max photos logic")
    func testCaptureModeLimits() {
        let singleMode = CaptureMode.singleItem
        let multiMode = CaptureMode.multiItem

        #expect(singleMode.maxPhotosAllowed(isPro: false) == 1)
        #expect(singleMode.maxPhotosAllowed(isPro: true) == 5)
        #expect(multiMode.maxPhotosAllowed(isPro: false) == 1)
        #expect(multiMode.maxPhotosAllowed(isPro: true) == 1)
    }

    @Test("CaptureMode validation")
    func testCaptureModeValidation() {
        let singleMode = CaptureMode.singleItem
        let multiMode = CaptureMode.multiItem

        #expect(singleMode.isValidPhotoCount(1) == true)
        #expect(singleMode.isValidPhotoCount(5) == true)
        #expect(singleMode.isValidPhotoCount(6) == false)
        #expect(multiMode.isValidPhotoCount(1) == true)
        #expect(multiMode.isValidPhotoCount(2) == false)
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

        #expect(singleMode.showsPhotoPickerButton == true)
        #expect(multiMode.showsPhotoPickerButton == true)
        #expect(singleMode.showsThumbnailScrollView == true)
        #expect(multiMode.showsThumbnailScrollView == false)
        #expect(singleMode.allowsMultipleCaptures == true)
        #expect(multiMode.allowsMultipleCaptures == false)
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
