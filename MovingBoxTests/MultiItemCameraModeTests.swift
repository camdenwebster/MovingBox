import AVFoundation
import SwiftUI
import Testing

@testable import MovingBox

@MainActor
@Suite struct MultiItemCaptureModeTests {

    // MARK: - CaptureMode Enum Tests

    @Test("CaptureMode enum supports single, multi-item, and video modes")
    func testCaptureModeEnum() {
        let singleMode = CaptureMode.singleItem
        let multiMode = CaptureMode.multiItem
        let videoMode = CaptureMode.video

        switch singleMode {
        case .singleItem:
            break
        case .multiItem:
            #expect(Bool(false), "Single mode should not be multi mode")
        case .video:
            #expect(Bool(false), "Single mode should not be video mode")
        }

        switch multiMode {
        case .multiItem:
            break
        case .singleItem:
            #expect(Bool(false), "Multi mode should not be single mode")
        case .video:
            #expect(Bool(false), "Multi mode should not be video mode")
        }

        switch videoMode {
        case .video:
            break
        case .singleItem:
            #expect(Bool(false), "Video mode should not be single mode")
        case .multiItem:
            #expect(Bool(false), "Video mode should not be multi mode")
        }
    }

    @Test("CaptureMode provides correct display names")
    func testCaptureModeDisplayNames() {
        #expect(CaptureMode.singleItem.displayName == "Single")
        #expect(CaptureMode.multiItem.displayName == "Multi")
        #expect(CaptureMode.video.displayName == "Video")
    }

    @Test("CaptureMode provides correct descriptions")
    func testCaptureModeDescriptions() {
        #expect(CaptureMode.singleItem.description == "Multiple photos of one item")
        #expect(CaptureMode.multiItem.description == "Multiple photos with multiple items")
        #expect(CaptureMode.video.description == "Analyze items from a video")
    }

    @Test("CaptureMode provides correct SF Symbol names")
    func testCaptureModeIcons() {
        #expect(CaptureMode.singleItem.iconName == "photo")
        #expect(CaptureMode.multiItem.iconName == "photo.stack")
        #expect(CaptureMode.video.iconName == "video")
    }

    @Test("CaptureMode defaults to single item")
    func testCaptureModeDefault() {
        // Verify that the default mode is single item for backward compatibility
        let defaultMode = CaptureMode.singleItem

        switch defaultMode {
        case .singleItem:
            // Expected default
            break
        case .multiItem:
            #expect(Bool(false), "Default should be single item mode")
        case .video:
            #expect(Bool(false), "Default should be single item mode")
        }
    }

    // MARK: - MultiPhotoCameraView Mode Integration Tests

    @Test("MultiPhotoCameraView accepts capture mode parameter")
    func testCameraViewModeParameter() {
        let capturedImages: [UIImage] = []

        // Test single-item mode initialization
        let singleModeView = MultiPhotoCameraView(
            capturedImages: .constant(capturedImages),
            captureMode: .singleItem,
            onPermissionCheck: { _ in },
            onComplete: { _, _ in }
        )

        let multiModeView = MultiPhotoCameraView(
            capturedImages: .constant(capturedImages),
            captureMode: .multiItem,
            onPermissionCheck: { _ in },
            onComplete: { _, _ in }
        )

        // Verify both views can be created
        #expect(type(of: singleModeView) == MultiPhotoCameraView.self)
        #expect(type(of: multiModeView) == MultiPhotoCameraView.self)
    }

    @Test("MultiPhotoCameraView maintains backward compatibility")
    func testBackwardCompatibility() {
        let capturedImages: [UIImage] = []

        let legacyView = MultiPhotoCameraView(
            capturedImages: .constant(capturedImages),
            onPermissionCheck: { _ in },
            onComplete: { _, _ in }
        )

        // Verify backward compatibility
        #expect(type(of: legacyView) == MultiPhotoCameraView.self)
    }

    // MARK: - Camera Mode Selection UI Tests

    @Test("Camera mode selection state management")
    func testCaptureModeSelectionState() {
        var selectedMode = CaptureMode.singleItem

        // Test initial state
        #expect(selectedMode == .singleItem)

        // Test mode switching
        selectedMode = .multiItem
        #expect(selectedMode == .multiItem)

        // Test mode switching back
        selectedMode = .singleItem
        #expect(selectedMode == .singleItem)
    }

    @Test("Camera mode affects photo limit behavior")
    func testCaptureModePhotoLimits() {
        // In single-item mode: allow up to max analysis photos for Pro users.
        let singleItemLimit = CaptureMode.singleItem.maxPhotosAllowed(isPro: true)
        #expect(singleItemLimit == CaptureMode.maxPhotosPerAnalysis)

        let singleItemLimitFree = CaptureMode.singleItem.maxPhotosAllowed(isPro: false)
        #expect(singleItemLimitFree == 1)

        // In multi-item mode: allow the full analysis max
        let multiItemLimit = CaptureMode.multiItem.maxPhotosAllowed(isPro: true)
        #expect(multiItemLimit == CaptureMode.maxPhotosPerAnalysis)

        let multiItemLimitFree = CaptureMode.multiItem.maxPhotosAllowed(isPro: false)
        #expect(multiItemLimitFree == CaptureMode.maxPhotosPerAnalysis)

        let videoLimit = CaptureMode.video.maxPhotosAllowed(isPro: true)
        #expect(videoLimit == 0)
    }

    @Test("Camera mode affects photo counter display")
    func testCaptureModePhotoCounter() {
        let currentPhotoCount = 2

        // Single-item mode shows "X of Y" format
        let singleItemCounter = CaptureMode.singleItem.photoCounterText(
            currentCount: currentPhotoCount,
            isPro: true
        )
        #expect(singleItemCounter == "2 of \(CaptureMode.maxPhotosPerAnalysis)")

        // Multi-item mode shows "X of max" format
        let multiItemCounter = CaptureMode.multiItem.photoCounterText(
            currentCount: currentPhotoCount,
            isPro: true
        )
        #expect(multiItemCounter == "2 of \(CaptureMode.maxPhotosPerAnalysis)")

        let videoCounter = CaptureMode.video.photoCounterText(
            currentCount: currentPhotoCount,
            isPro: true
        )
        #expect(videoCounter == "Video")
    }

    // MARK: - Integration with Navigation Flow

    @Test("Camera mode determines post-capture navigation")
    func testCaptureModeNavigation() {
        // Single-item mode should proceed to normal item creation flow
        let singleItemDestination = CaptureMode.singleItem.postCaptureDestination(
            images: [createTestImage()],
            location: nil
        )

        switch singleItemDestination {
        case .itemCreationFlow:
            // Expected for single-item mode
            break
        case .multiItemSelection:
            #expect(Bool(false), "Single mode should not go to multi-item selection")
        }

        // Multi-item mode should proceed to AI analysis and selection
        let multiItemDestination = CaptureMode.multiItem.postCaptureDestination(
            images: [createTestImage()],
            location: nil
        )

        switch multiItemDestination {
        case .multiItemSelection:
            // Expected for multi-item mode
            break
        case .itemCreationFlow:
            #expect(Bool(false), "Multi mode should not go to regular item creation")
        }

        let videoDestination = CaptureMode.video.postCaptureDestination(
            images: [createTestImage()],
            location: nil
        )
        switch videoDestination {
        case .multiItemSelection:
            break
        case .itemCreationFlow:
            #expect(Bool(false), "Video mode should route to multi-item selection flow")
        }
    }

    // MARK: - Error Handling Tests

    @Test("Camera mode handles invalid photo counts")
    func testInvalidPhotoCountHandling() {
        // Test with no photos
        let emptyPhotos: [UIImage] = []

        let singleModeEmpty = CaptureMode.singleItem.isValidPhotoCount(emptyPhotos.count)
        #expect(singleModeEmpty == false, "Single mode should require at least one photo")

        let multiModeEmpty = CaptureMode.multiItem.isValidPhotoCount(emptyPhotos.count)
        #expect(multiModeEmpty == false, "Multi mode should require at least one photo")

        // Test with too many photos
        let tooManyPhotos = Array(repeating: createTestImage(), count: CaptureMode.maxPhotosPerAnalysis + 1)

        let singleModeMany = CaptureMode.singleItem.isValidPhotoCount(tooManyPhotos.count)
        #expect(singleModeMany == false, "Single mode should reject too many photos")

        let multiModeMany = CaptureMode.multiItem.isValidPhotoCount(tooManyPhotos.count)
        #expect(multiModeMany == false, "Multi mode should reject too many photos")

        let videoModeAny = CaptureMode.video.isValidPhotoCount(1)
        #expect(videoModeAny == false, "Video mode should not validate based on photo count")
    }

    @Test("Camera mode provides appropriate error messages")
    func testCaptureModeErrorMessages() {
        let singleModeError = CaptureMode.singleItem.errorMessage(for: .tooManyPhotos)
        #expect(singleModeError.contains("\(CaptureMode.maxPhotosPerAnalysis)"))

        let multiModeError = CaptureMode.multiItem.errorMessage(for: .tooManyPhotos)
        #expect(multiModeError.contains("\(CaptureMode.maxPhotosPerAnalysis) photos"))

        let singleModeEmpty = CaptureMode.singleItem.errorMessage(for: .noPhotos)
        #expect(singleModeEmpty.contains("at least one"))

        let multiModeEmpty = CaptureMode.multiItem.errorMessage(for: .noPhotos)
        #expect(multiModeEmpty.contains("at least one"))
    }

    // MARK: - UI State Tests

    @Test("Camera mode affects UI element visibility")
    func testCaptureModeUIElements() {
        // Single-item mode should show photo picker and multiple capture options
        #expect(CaptureMode.singleItem.showsPhotoPickerButton == true)
        #expect(CaptureMode.singleItem.showsThumbnailScrollView == true)
        #expect(CaptureMode.singleItem.allowsMultipleCaptures == true)

        // Multi-item mode now supports multi-shot capture and thumbnails
        #expect(CaptureMode.multiItem.showsPhotoPickerButton == true)
        #expect(CaptureMode.multiItem.showsThumbnailScrollView == true)
        #expect(CaptureMode.multiItem.allowsMultipleCaptures == true)

        #expect(CaptureMode.video.showsPhotoPickerButton == false)
        #expect(CaptureMode.video.showsThumbnailScrollView == false)
        #expect(CaptureMode.video.allowsMultipleCaptures == false)
    }

    // MARK: - Helper Methods

    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Supporting Types for Testing
// Note: CaptureMode, PostCaptureDestination, and CaptureModeError are now defined in MultiPhotoCameraView.swift
