import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import UIKit
import Combine

// MARK: - Environment Key for Preview Mode

private struct IsPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isPreview: Bool {
        get { self[IsPreviewKey.self] }
        set { self[IsPreviewKey.self] = newValue }
    }
}

/// Represents the capture mode for the MultiPhotoCameraView
enum CaptureMode: CaseIterable {
    case singleItem  /// Multiple photos of one item (existing functionality)
    case multiItem   /// One photo with multiple items (new functionality)
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .singleItem: return "Single"
        case .multiItem: return "Multi"
        }
    }
    
    var description: String {
        switch self {
        case .singleItem: return "Multiple photos of one item"
        case .multiItem: return "One photo with multiple items"
        }
    }
    
    var iconName: String {
        switch self {
        case .singleItem: return "photo"
        case .multiItem: return "photo.stack"
        }
    }
    
    // MARK: - Photo Limits
    
    func maxPhotosAllowed(isPro: Bool) -> Int {
        switch self {
        case .singleItem:
            return isPro ? 5 : 1
        case .multiItem:
            return 1 // Always 1 for multi-item mode
        }
    }
    
    func photoCounterText(currentCount: Int, isPro: Bool) -> String {
        switch self {
        case .singleItem:
            let maxPhotos = maxPhotosAllowed(isPro: isPro)
            return "\(currentCount) of \(maxPhotos)"
        case .multiItem:
            return ""  // No counter text for multi-item mode
        }
    }
    
    // MARK: - Validation
    
    func isValidPhotoCount(_ count: Int) -> Bool {
        switch self {
        case .singleItem:
            return count >= 1 && count <= 5
        case .multiItem:
            return count == 1
        }
    }
    
    func errorMessage(for error: CaptureModeError) -> String {
        switch (self, error) {
        case (.singleItem, .tooManyPhotos):
            return "You can take up to 5 photos in single-item mode."
        case (.multiItem, .tooManyPhotos):
            return "You can only take one photo in multi-item mode."
        case (.singleItem, .noPhotos):
            return "Please take at least one photo."
        case (.multiItem, .noPhotos):
            return "Please take exactly one photo for multi-item analysis."
        }
    }
    
    // MARK: - UI Behavior
    
    var showsPhotoPickerButton: Bool {
        switch self {
        case .singleItem: return true
        case .multiItem: return true  // Enable photo picker for multi-item mode
        }
    }
    
    var showsThumbnailScrollView: Bool {
        switch self {
        case .singleItem: return true
        case .multiItem: return false
        }
    }
    
    var allowsMultipleCaptures: Bool {
        switch self {
        case .singleItem: return true
        case .multiItem: return false
        }
    }
    
    // MARK: - Navigation
    
    func postCaptureDestination(images: [UIImage], location: InventoryLocation?) -> PostCaptureDestination {
        switch self {
        case .singleItem:
            return .itemCreationFlow(images: images, location: location)
        case .multiItem:
            return .multiItemSelection(images: images, location: location)
        }
    }
}

// MARK: - Supporting Types

enum PostCaptureDestination {
    case itemCreationFlow(images: [UIImage], location: InventoryLocation?)
    case multiItemSelection(images: [UIImage], location: InventoryLocation?)
}

enum CaptureModeError {
    case tooManyPhotos
    case noPhotos
}

struct MultiPhotoCameraView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    @StateObject private var model = MultiPhotoCameraViewModel()
    @Binding var capturedImages: [UIImage]
    let captureMode: CaptureMode
    let onPermissionCheck: (Bool) -> Void
    let onComplete: ([UIImage], CaptureMode) -> Void
    let onCancel: (() -> Void)?

    @Environment(\.isPreview) private var isPreview

    private var isUITesting: Bool {
        isPreview || ProcessInfo.processInfo.arguments.contains("UI-Testing-Mock-Camera")
    }

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingPhotoPicker = false
    @State private var animatingImage: UIImage?
    @State private var showingCaptureAnimation = false
    @State private var focusPoint: CGPoint?
    @State private var showingFocusIndicator = false
    @State private var orientation = UIDeviceOrientation.portrait
    @State private var localZoomIndex: Int = 0
    @State private var showMultiItemPreview = false

    init(
        capturedImages: Binding<[UIImage]>,
        captureMode: CaptureMode = .singleItem,
        onPermissionCheck: @escaping (Bool) -> Void,
        onComplete: @escaping ([UIImage], CaptureMode) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self._capturedImages = capturedImages
        self.captureMode = captureMode
        self.onPermissionCheck = onPermissionCheck
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    init(
        capturedImages: Binding<[UIImage]>,
        onPermissionCheck: @escaping (Bool) -> Void,
        onComplete: @escaping ([UIImage], CaptureMode) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self._capturedImages = capturedImages
        self.captureMode = .singleItem
        self.onPermissionCheck = onPermissionCheck
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    var body: some View {
        GeometryReader { geometry in
            let squareSize = calculateSquareSize(geometry: geometry)
            let cameraRect = calculateCameraRect(geometry: geometry, squareSize: squareSize)

            ZStack(alignment: .center) {
                Color.black.ignoresSafeArea(.all)

                cameraPreview(geometry: geometry)

                if showMultiItemPreview,
                   let capturedImage = model.capturedImages.first {
                    MultiItemPreviewOverlay(
                        capturedImage: capturedImage,
                        squareSize: squareSize,
                        onRetake: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                showMultiItemPreview = false
                            }
                            model.capturedImages.removeAll()
                        },
                        onAnalyze: { onComplete(model.capturedImages, model.selectedCaptureMode) }
                    )
                    .transition(.scale.combined(with: .opacity))
                }

                cameraControls(geometry: geometry, cameraRect: cameraRect)
            }
        }
        .onCameraCaptureEvent { event in
            handleCameraCaptureEvent(event)
        }
        .alert("Photo Limit Reached", isPresented: $model.showPhotoLimitAlert) {
            if settings.isPro || model.selectedCaptureMode == .multiItem {
                Button("OK") { }
            } else {
                Button("Close") { }
                Button("Go Pro") {
                    model.showingPaywall = true
                }
            }
        } message: {
            if model.selectedCaptureMode == .multiItem {
                Text(model.selectedCaptureMode.errorMessage(for: .tooManyPhotos))
            } else if settings.isPro {
                Text(model.selectedCaptureMode.errorMessage(for: .tooManyPhotos))
            } else {
                Text("You can only add one photo per item. Upgrade to MovingBox Pro to add more photos.")
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedItems,
            maxSelectionCount: max(0, model.selectedCaptureMode.maxPhotosAllowed(isPro: settings.isPro) - model.capturedImages.count),
            matching: .images
        )
        .alert("Switch Camera Mode?", isPresented: $model.showingModeSwitchConfirmation) {
            Button("Cancel", role: .cancel) {
                model.cancelModeSwitch()
            }
            Button("Switch Mode", role: .destructive) {
                model.confirmModeSwitch()
            }
        } message: {
            Text("Switching modes will clear your current photos. Are you sure?")
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                await processSelectedPhotos(newItems)
            }
        }
        .onChange(of: model.capturedImages) { oldImages, newImages in
            capturedImages = newImages

            if model.selectedCaptureMode == .multiItem {
                if !newImages.isEmpty && oldImages.isEmpty {
                    // Animate in when first image is captured
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showMultiItemPreview = true
                    }
                } else if newImages.isEmpty && !oldImages.isEmpty {
                    // Animate out when images are cleared (if not already animated by onRetake)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showMultiItemPreview = false
                    }
                }
            } else {
                // Ensure preview is hidden in single item mode
                showMultiItemPreview = false
                if model.selectedCaptureMode == .singleItem {
                    if newImages.count > oldImages.count, let newImage = newImages.last {
                        triggerCaptureAnimation(with: newImage)
                    }
                }
            }
        }
        .onChange(of: model.currentZoomIndex) { _, newIndex in
            localZoomIndex = newIndex
        }
        .sheet(isPresented: $model.showingPaywall) {
            revenueCatManager.presentPaywall(
                isPresented: $model.showingPaywall,
                onCompletion: { settings.isPro = true },
                onDismiss: nil
            )
        }
        .onAppear {
            model.loadInitialCaptureMode(preferredCaptureMode: settings.preferredCaptureMode, isPro: settings.isPro)
            if isPreview && !capturedImages.isEmpty {
                model.capturedImages = capturedImages
            }
        }
        .onDisappear {
            Task {
                await model.stopSession()
            }
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func cameraPreview(geometry: GeometryProxy) -> some View {
        Group {
            if isUITesting {
                Image("tablet", bundle: .main)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .onTapGesture { location in
                        handleFocusTap(at: location)
                    }
                    .onAppear {
                        onPermissionCheck(true)
                    }
            } else {
                FullScreenCameraPreviewView(
                    session: model.session,
                    orientation: orientation,
                )
                .onAppear {
                    Task {
                        await model.checkPermissions(completion: onPermissionCheck)
                    }
                }
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
        .frame(maxHeight: geometry.size.height - 180)
        .clipped()
    }

    @ViewBuilder
    private func cameraControls(geometry: GeometryProxy, cameraRect: CGRect) -> some View {
        let isMultiItemPreview = model.shouldShowMultiItemPreview(captureMode: model.selectedCaptureMode)

        VStack(spacing: 0) {
            CameraTopControls(
                model: model,
                onClose: {
                    if let onCancel = onCancel {
                        onCancel()
                    }
                },
                onDone: {
                    onComplete(model.capturedImages, model.selectedCaptureMode)
                },
                isMultiItemPreviewShowing: isMultiItemPreview,
                hasPhotoCaptured: !model.capturedImages.isEmpty
            )

            if model.selectedCaptureMode.showsThumbnailScrollView && !model.capturedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(model.capturedImages.enumerated()), id: \.offset) { index, image in
                            PhotoThumbnailView(
                                image: image,
                                index: index,
                                onDelete: { index in
                                    model.removeImage(at: index)
                                }
                            )
                            .frame(width: 60, height: 70)
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 70)
                .animation(.easeIn(duration: 0.3), value: model.capturedImages.count)
            }

            Spacer()

            if showingFocusIndicator, let focusPoint = focusPoint {
                FocusIndicatorView()
                    .position(focusPoint)
            }

            if showingCaptureAnimation, let animatingImage = animatingImage {
                CaptureAnimationView(
                    image: animatingImage,
                    startRect: cameraRect,
                    endRect: calculateThumbnailDestination(geometry: geometry),
                    isVisible: $showingCaptureAnimation
                )
            }

            if !isMultiItemPreview {
                VStack(spacing: 0) {
                    Spacer()
                    
                    ZoomControlView(
                        zoomFactors: model.zoomFactors,
                        currentZoomIndex: localZoomIndex,
                        onZoomTap: { index in
                            model.setZoom(to: index)
                        }
                    )
                    .padding(.bottom, 16)
                    
                    CameraBottomControls(
                        captureMode: model.selectedCaptureMode,
                        photoCount: model.capturedImages.count,
                        photoCounterText: model.selectedCaptureMode.photoCounterText(currentCount: model.capturedImages.count, isPro: settings.isPro),
                        hasPhotoCaptured: !model.capturedImages.isEmpty,
                        onShutterTap: { handleShutterTap() },
                        onRetakeTap: { model.capturedImages.removeAll() },
                        onPhotoPickerTap: { handlePhotoPickerTap() },
                        selectedCaptureMode: Binding(
                            get: { model.selectedCaptureMode },
                            set: { newMode in
                                let oldMode = model.selectedCaptureMode
                                if model.handleCaptureModeChange(from: oldMode, to: newMode, isPro: settings.isPro) {
                                    model.saveCaptureMode(to: settings)
                                }
                            }
                        )
                    )
                    .padding(.top, 10)
                    .background(Color.black)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    // MARK: - Helper Methods

    private func calculateSquareSize(geometry: GeometryProxy) -> CGFloat {
        let availableHeight = geometry.size.height - 180 - 100
        return min(geometry.size.width - 40, availableHeight)
    }

    private func calculateCameraRect(geometry: GeometryProxy, squareSize: CGFloat) -> CGRect {
        let previewHeight = geometry.size.height - 180
        let centerY = previewHeight / 2 + 50
        return CGRect(
            x: (geometry.size.width - squareSize) / 2,
            y: centerY - squareSize / 2,
            width: squareSize,
            height: squareSize
        )
    }

    private func handleFocusTap(at point: CGPoint, in geometry: GeometryProxy? = nil) {
        if let geometry = geometry {
            let relativeX = point.x / geometry.size.width
            let relativeY = point.y / geometry.size.height
            let clampedX = max(0, min(1, relativeX))
            let clampedY = max(0, min(1, relativeY))
            model.setFocusPoint(CGPoint(x: clampedX, y: clampedY))
        }

        focusPoint = point
        showingFocusIndicator = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showingFocusIndicator = false
        }
    }

    private func handleCameraCaptureEvent(_ event: AVCaptureEvent) {
        if event.phase == .ended {
            handleShutterTap()
        }
    }

    private func handleShutterTap() {
        if !model.canCaptureMorePhotos(captureMode: model.selectedCaptureMode, isPro: settings.isPro) {
            model.showPhotoLimitAlert = true
        } else {
            if isUITesting {
                model.captureTestPhoto()
            } else {
                model.capturePhoto()
            }
        }
    }

    private func handlePhotoPickerTap() {
        if !model.canCaptureMorePhotos(captureMode: model.selectedCaptureMode, isPro: settings.isPro) {
            model.showPhotoLimitAlert = true
        } else {
            showingPhotoPicker = true
        }
    }

    private func calculateThumbnailDestination(geometry: GeometryProxy) -> CGRect {
        let thumbnailAreaY: CGFloat = geometry.size.height * -0.095
        let thumbnailX = 20 + CGFloat(model.capturedImages.count - 1) * 68
        return CGRect(x: thumbnailX, y: thumbnailAreaY, width: 60, height: 60)
    }

    private func triggerCaptureAnimation(with image: UIImage) {
        animatingImage = image
        showingCaptureAnimation = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showingCaptureAnimation = false
            animatingImage = nil
        }
    }

    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        let maxPhotos = model.selectedCaptureMode.maxPhotosAllowed(isPro: settings.isPro)
        for item in items {
            guard model.capturedImages.count < maxPhotos else { break }

            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {

                let croppedImage = await cropToSquare(image: image)
                let optimizedImage = await OptimizedImageManager.shared.optimizeImage(croppedImage)

                await MainActor.run {
                    model.capturedImages.append(optimizedImage)
                }
            }
        }

        await MainActor.run {
            selectedItems = []
        }
    }

    private func cropToSquare(image: UIImage) async -> UIImage {
        let size = image.size
        let sideLength = min(size.width, size.height)

        let x = (size.width - sideLength) / 2
        let y = (size.height - sideLength) / 2
        let cropRect = CGRect(x: x, y: y, width: sideLength, height: sideLength)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage,
                      let croppedCGImage = cgImage.cropping(to: cropRect) else {
                    continuation.resume(returning: image)
                    return
                }

                let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
                continuation.resume(returning: croppedImage)
            }
        }
    }
}

// MARK: - Previews

#Preview("Single Item Mode") {
    PreviewContainer {
        MultiPhotoCameraView(
            capturedImages: .constant([]),
            captureMode: .singleItem,
            onPermissionCheck: { _ in },
            onComplete: { _, _ in }
        )
    }
}

#Preview("Multi Item Mode") {
    PreviewContainer {
        MultiPhotoCameraView(
            capturedImages: .constant([]),
            captureMode: .multiItem,
            onPermissionCheck: { _ in },
            onComplete: { _, _ in }
        )
    }
}

#Preview("Single Item with Images") {
    PreviewContainer {
        MultiPhotoCameraView(
            capturedImages: .constant([
                createPreviewImage(color: .systemBlue, label: "1"),
                createPreviewImage(color: .systemGreen, label: "2"),
                createPreviewImage(color: .systemOrange, label: "3")
            ]),
            captureMode: .singleItem,
            onPermissionCheck: { _ in },
            onComplete: { _, _ in }
        )
    }
}

private func createPreviewImage(color: UIColor, label: String) -> UIImage {
    let size = CGSize(width: 200, height: 200)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 80, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let text = label as NSString
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
    }
}

// MARK: - Preview Helper

private struct PreviewContainer<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.isPreview, true)
            .environmentObject(SettingsManager())
            .environmentObject(RevenueCatManager.shared)
    }
}
