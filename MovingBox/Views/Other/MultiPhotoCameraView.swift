import SwiftUI
import AVFoundation
import PhotosUI
import UIKit
import Combine

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
    
    func completionButtonText(photoCount: Int) -> String {
        switch self {
        case .singleItem:
            return "Next"
        case .multiItem:
            return "Analyze"
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

    // Check if we're in UI testing mode
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-Testing-Mock-Camera")
    }

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingPhotoPicker = false
    @State private var animatingImage: UIImage?
    @State private var showingCaptureAnimation = false
    @State private var focusPoint: CGPoint?
    @State private var showingFocusIndicator = false
    @State private var orientation = UIDeviceOrientation.portrait
    @State private var showingPaywall = false

    // Mode switching state
    @State private var selectedCaptureMode: CaptureMode
    @State private var pendingCaptureMode: CaptureMode?
    @State private var showingModeSwitchConfirmation = false
    @State private var isHandlingModeChange = false  // Prevent onChange recursion

    // Zoom control state (isolated from model updates)
    @State private var localZoomIndex: Int = 0

    // Macro recommendation state
    @State private var dismissedMacroRecommendation: MacroRecommendation? = nil

    // New initializer with capture mode parameter
    init(
        capturedImages: Binding<[UIImage]>,
        captureMode: CaptureMode = .singleItem,
        onPermissionCheck: @escaping (Bool) -> Void,
        onComplete: @escaping ([UIImage], CaptureMode) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self._capturedImages = capturedImages
        self.captureMode = captureMode
        self._selectedCaptureMode = State(initialValue: captureMode)
        self.onPermissionCheck = onPermissionCheck
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    // Backward compatibility initializer
    init(
        capturedImages: Binding<[UIImage]>,
        onPermissionCheck: @escaping (Bool) -> Void,
        onComplete: @escaping ([UIImage], CaptureMode) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self._capturedImages = capturedImages
        self.captureMode = .singleItem
        self._selectedCaptureMode = State(initialValue: .singleItem)
        self.onPermissionCheck = onPermissionCheck
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    // Layout constants
    private let topBarHeight: CGFloat = 60
    private let bottomControlsHeight: CGFloat = 200
    
    private var flashModeText: String {
        switch model.flashMode {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        @unknown default: return "Off"
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black.ignoresSafeArea(.all)
                
                // Camera preview or static image for UI testing
                Group {
                    if isUITesting {
                        // Use static tablet image for UI testing
                        Image("tablet", bundle: .main)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .onTapGesture { location in
                                // Simulate focus tap for UI testing
                                focusPoint = location
                                showingFocusIndicator = true

                                // Hide focus indicator after animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    showingFocusIndicator = false
                                }
                            }
                            .onAppear {
                                // Simulate successful permissions for UI testing
                                onPermissionCheck(true)
                            }
                    } else {
                        // Real camera preview
                        FullScreenCameraPreviewView(
                            session: model.session,
                            orientation: orientation,
                            onTapToFocus: { point in
                                // For aspect-fit tap-to-focus, convert point directly
                                let relativeX = point.x / geometry.size.width
                                let relativeY = point.y / geometry.size.height
                                let clampedX = max(0, min(1, relativeX))
                                let clampedY = max(0, min(1, relativeY))
                                model.setFocusPoint(CGPoint(x: clampedX, y: clampedY))
                                focusPoint = point
                                showingFocusIndicator = true
                                
                                // Hide focus indicator after animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    showingFocusIndicator = false
                                }
                            }
                        )
                        .onAppear {
                            Task {
                                await model.checkPermissions(completion: onPermissionCheck)
                            }
                            // Start orientation monitoring on iPad
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                // Get current orientation first
                                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                                let currentOrientation = UIDevice.current.orientation
                                
                                // Always prefer interface orientation on iPad for better reliability
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                    let interfaceOrientation = windowScene.interfaceOrientation
                                    print("📱 Interface orientation: \(interfaceOrientation)")
                                    
                                    switch interfaceOrientation {
                                    case .portrait:
                                        orientation = .portrait
                                    case .portraitUpsideDown:
                                        orientation = .portraitUpsideDown
                                    case .landscapeLeft:
                                        orientation = .landscapeRight  // Interface landscape left = device landscape right
                                    case .landscapeRight:
                                        orientation = .landscapeLeft   // Interface landscape right = device landscape left
                                    default:
                                        orientation = .portrait
                                    }
                                } else {
                                    // Fallback to device orientation if interface orientation is unavailable
                                    if currentOrientation != .unknown && currentOrientation != .faceUp && currentOrientation != .faceDown {
                                        orientation = currentOrientation
                                    } else {
                                        orientation = .portrait
                                    }
                                }
                                
                                // Log the orientation info
                                let interfaceOrientationString: String
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                    interfaceOrientationString = "\(windowScene.interfaceOrientation)"
                                } else {
                                    interfaceOrientationString = "unknown"
                                }
                                print("📱 Camera initial orientation: device=\(currentOrientation), interface=\(interfaceOrientationString), using=\(orientation)")
                                
                                // NOTE: Removed forced orientation update that was resetting camera zoom
                                // The orientation should update naturally through the notification observer below
                                // print("📱 Forced camera orientation update to: \(orientation)")
                                
                                // Then start monitoring for changes
                                NotificationCenter.default.addObserver(
                                    forName: UIDevice.orientationDidChangeNotification,
                                    object: nil,
                                    queue: .main
                                ) { _ in
                                    let newOrientation = UIDevice.current.orientation
                                    // Only update if it's a valid orientation
                                    if newOrientation != .unknown && newOrientation != .faceUp && newOrientation != .faceDown {
                                        orientation = newOrientation
                                        print("📱 Camera orientation changed to: \(newOrientation)")
                                    }
                                }
                            }
                        }
                        .onDisappear {
                            // DON'T stop the session here - it causes issues when:
                            // 1. Switching to photo preview in multi-item mode
                            // 2. Switching between capture modes
                            // The session will be stopped when the entire camera view is dismissed

                            // Stop orientation monitoring on iPad
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                                NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
                            }
                        }
                    }
                }
                .aspectRatio(3/4, contentMode: .fit)
                .clipped()
                
                // Square crop overlay in center (visual guide for what will be captured)
                let availableHeight = geometry.size.height - 100 - 200 // Account for top and bottom UI areas
                let squareSize = min(geometry.size.width - 40, availableHeight) // Add some padding
                let centerY = geometry.size.height / 2
                let cameraRect = CGRect(x: (geometry.size.width - squareSize) / 2, y: centerY - squareSize / 2, width: squareSize, height: squareSize)
                
                Rectangle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    .frame(width: squareSize, height: squareSize)
                    .position(x: geometry.size.width / 2, y: centerY)

                // Photo preview overlay (multi-item mode with captured photo)
                if selectedCaptureMode == .multiItem && !model.capturedImages.isEmpty {
                    ZStack {
                        // Dim the camera feed
                        Color.black.opacity(0.7)
                            .ignoresSafeArea(.all)

                        // Show captured photo
                        if let capturedImage = model.capturedImages.first {
                            Image(uiImage: capturedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: squareSize, height: squareSize)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.3), radius: 10)
                        }
                    }
                }

                // UI Controls
                VStack(spacing: 0) {
                // Macro recommendation banner
                if let recommendation = model.macroRecommendation,
                   dismissedMacroRecommendation?.focusDistanceImprovement != recommendation.focusDistanceImprovement {
                    MacroRecommendationBanner(
                        recommendation: recommendation,
                        onSwitch: {
                            // Switch to the recommended camera's zoom level
                            if let zoomIndex = model.zoomFactors.firstIndex(of: recommendation.recommendedCamera.displayZoomFactor) {
                                model.setZoom(to: zoomIndex)
                            }
                        },
                        onDismiss: {
                            dismissedMacroRecommendation = recommendation
                        }
                    )
                    .padding(.top, 8)
                }

                // Top bar
                VStack(spacing: 12) {
                    HStack {
                        // Close button
                        Button {
                            if let onCancel = onCancel {
                                onCancel()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                        }
                        .accessibilityIdentifier("cameraCloseButton")

                        Spacer()

                        // Center controls: Flash and Camera switcher
                        HStack(spacing: 20) {
                            // Flash button
                            Button {
                                model.cycleFlash()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: model.flashIcon)
                                        .font(.system(size: 16))
                                    Text(flashModeText)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                            }

                            // Camera switcher
                            Button {
                                Task {
                                    await model.switchCamera()
                                }
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                        }

                        Spacer()

                        // Done button
                        Button(selectedCaptureMode.completionButtonText(photoCount: model.capturedImages.count)) {
                            onComplete(model.capturedImages, selectedCaptureMode)
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.green)
                        .disabled(model.capturedImages.isEmpty)
                        .opacity(model.capturedImages.isEmpty ? 0.5 : 1.0)
                        .accessibilityIdentifier("cameraDoneButton")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    .padding(.bottom, 10)

                    // Zoom control
                    ZoomControlView(
                        zoomFactors: model.zoomFactors,
                        currentZoomIndex: localZoomIndex,
                        onZoomTap: { index in
                            localZoomIndex = index
                            model.setZoom(to: index)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .onChange(of: model.currentZoomIndex) { _, newIndex in
                        localZoomIndex = newIndex
                    }
                }
                
                // Thumbnails (only shown in single-item mode)
                if selectedCaptureMode.showsThumbnailScrollView && !model.capturedImages.isEmpty {
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
                                .frame(width: 60, height: 60)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    .frame(height: 100)
                    .padding(.vertical, 10)
                }
                
                Spacer()
                
                // Focus indicator overlay
                if showingFocusIndicator, let focusPoint = focusPoint {
                    FocusIndicatorView()
                        .position(focusPoint)
                }
                
                // Capture animation overlay
                if showingCaptureAnimation, let animatingImage = animatingImage {
                    CaptureAnimationView(
                        image: animatingImage,
                        startRect: cameraRect,
                        endRect: calculateThumbnailDestination(geometry: geometry),
                        isVisible: $showingCaptureAnimation
                    )
                }
                
                // Bottom controls area
                VStack(spacing: 20) {
                    // Capture mode segmented control (hidden when photo preview is showing)
                    if !(selectedCaptureMode == .multiItem && !model.capturedImages.isEmpty) {
                        captureModePicker
                            .padding(.bottom, 30)
                    }

                    // Shutter controls row
                    HStack(spacing: 50) {
                        // Photo count
                        Text(selectedCaptureMode.photoCounterText(currentCount: model.capturedImages.count, isPro: settings.isPro))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 60)
                            .accessibilityIdentifier("cameraPhotoCount")
                        
                        // Shutter button or Retake button (multi-item mode with photo)
                        if selectedCaptureMode == .multiItem && !model.capturedImages.isEmpty {
                            // Retake button in multi-item mode after capture
                            Button {
                                model.capturedImages.removeAll()
                                // Camera automatically returns to live preview
                            } label: {
                                Text("Retake")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 100, height: 50)
                                    .background(.red.opacity(0.8))
                                    .cornerRadius(25)
                            }
                            .accessibilityIdentifier("cameraRetakeButton")
                        } else {
                            // Normal shutter button
                            Button {
                                let maxPhotos = selectedCaptureMode.maxPhotosAllowed(isPro: settings.isPro)
                                if model.capturedImages.count >= maxPhotos {
                                    model.showPhotoLimitAlert = true
                                } else {
                                    if isUITesting {
                                        model.captureTestPhoto()
                                    } else {
                                        model.capturePhoto()
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 70, height: 70)
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 5)
                                        .frame(width: 76, height: 76)
                                }
                            }
                            .accessibilityIdentifier("cameraShutterButton")
                        }

                        // Photo picker button (only shown in single-item mode)
                        if selectedCaptureMode.showsPhotoPickerButton {
                            Button {
                                let maxPhotos = selectedCaptureMode.maxPhotosAllowed(isPro: settings.isPro)
                                if model.capturedImages.count >= maxPhotos {
                                    model.showPhotoLimitAlert = true
                                } else {
                                    showingPhotoPicker = true
                                }
                            } label: {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .frame(width: 60)
                            }
                        } else {
                            // Spacer to maintain layout in multi-item mode
                            Spacer()
                                .frame(width: 60)
                        }
                    }
                    .padding(.bottom, 30)
                    }
                }
                
            }
        }
        .alert("Photo Limit Reached", isPresented: $model.showPhotoLimitAlert) {
            if settings.isPro || selectedCaptureMode == .multiItem {
                Button("OK") { }
            } else {
                Button("Close") { }
                Button("Go Pro") {
                    showingPaywall = true
                }
            }
        } message: {
            if selectedCaptureMode == .multiItem {
                Text(selectedCaptureMode.errorMessage(for: .tooManyPhotos))
            } else if settings.isPro {
                Text(selectedCaptureMode.errorMessage(for: .tooManyPhotos))
            } else {
                Text("You can only add one photo per item. Upgrade to MovingBox Pro to add more photos.")
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedItems,
            maxSelectionCount: max(0, selectedCaptureMode.maxPhotosAllowed(isPro: settings.isPro) - model.capturedImages.count),
            matching: .images
        )
        .alert("Switch Camera Mode?", isPresented: $showingModeSwitchConfirmation) {
            Button("Cancel", role: .cancel) {
                // Just clear the pending mode, selectedCaptureMode already reverted
                pendingCaptureMode = nil
            }
            Button("Switch Mode", role: .destructive) {
                if let newMode = pendingCaptureMode {
                    performModeSwitch(to: newMode)
                }
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

            // Trigger animation only for single-item mode
            if selectedCaptureMode == .singleItem {
                if newImages.count > oldImages.count, let newImage = newImages.last {
                    triggerCaptureAnimation(with: newImage)
                }
            }
        }
        .onChange(of: selectedCaptureMode) { oldMode, newMode in
            handleCaptureModeChange(from: oldMode, to: newMode)
        }
        .sheet(isPresented: $showingPaywall) {
            revenueCatManager.presentPaywall(
                isPresented: $showingPaywall,
                onCompletion: { settings.isPro = true },
                onDismiss: nil
            )
        }
        .onAppear {
            // Load preferred capture mode from settings on first appear
            if settings.preferredCaptureMode == 1 && settings.isPro {
                selectedCaptureMode = .multiItem
            } else {
                selectedCaptureMode = .singleItem
            }
        }
        .onDisappear {
            // Stop the camera session when the entire camera view is dismissed
            Task {
                await model.stopSession()
            }
        }
    }
    
    // MARK: - Capture Mode Picker

    private var captureModePicker: some View {
        Picker("Capture Mode", selection: $selectedCaptureMode) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                HStack(spacing: 4) {
                    Text(mode.displayName)
                    if mode == .multiItem && !settings.isPro {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
                .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
        .accessibilityLabel("Camera mode selector")
        .accessibilityHint("Switch between single item and multi item capture modes")
    }

    // MARK: - Mode Switching Logic

    private func handleCaptureModeChange(from oldMode: CaptureMode, to newMode: CaptureMode) {
        // Prevent recursion from onChange firing again
        guard !isHandlingModeChange else { return }
        isHandlingModeChange = true

        // Check if switching to Multi mode requires Pro
        if newMode == .multiItem && !settings.isPro {
            // Revert selection and show paywall
            selectedCaptureMode = oldMode
            isHandlingModeChange = false
            showingPaywall = true
            return
        }

        // If photos are captured, require confirmation
        if !model.capturedImages.isEmpty {
            pendingCaptureMode = newMode
            selectedCaptureMode = oldMode // Revert temporarily
            isHandlingModeChange = false
            showingModeSwitchConfirmation = true
            return
        }

        // No photos, switch modes directly
        performModeSwitch(to: newMode)
        isHandlingModeChange = false
    }

    private func performModeSwitch(to newMode: CaptureMode) {
        // Clear photos if any
        model.capturedImages.removeAll()

        // Simple, direct mode switch
        selectedCaptureMode = newMode

        // Save preference
        settings.preferredCaptureMode = newMode == .singleItem ? 0 : 1

        // Clear pending mode
        pendingCaptureMode = nil

        // Haptic feedback (optional, non-critical)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Helper Methods

    private func calculateThumbnailDestination(geometry: GeometryProxy) -> CGRect {
        // Calculate where the new thumbnail will appear
        // From the screenshot: thumbnails are positioned much lower, around 60% down
        let thumbnailAreaY: CGFloat = geometry.size.height * -0.11 // Based on the top of the camera feed
        
        let thumbnailX = 20 + CGFloat(model.capturedImages.count - 1) * 68 // 60 width + 8 spacing
        
        let destination = CGRect(x: thumbnailX, y: thumbnailAreaY, width: 60, height: 60)
        print("🎥 Animation destination: \(destination) (screen height: \(geometry.size.height))")
        return destination
    }
    
    private func triggerCaptureAnimation(with image: UIImage) {
        animatingImage = image
        showingCaptureAnimation = true
        
        print("🎥 Starting capture animation")
        
        // Hide animation after completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showingCaptureAnimation = false
            animatingImage = nil
        }
    }
    
    private func handleTapToFocus(point: CGPoint, in cameraRect: CGRect) {
        // Convert tap point to camera coordinate system
        let relativeX = (point.x - cameraRect.minX) / cameraRect.width
        let relativeY = (point.y - cameraRect.minY) / cameraRect.height
        
        // Clamp values to 0-1 range
        let clampedX = max(0, min(1, relativeX))
        let clampedY = max(0, min(1, relativeY))
        
        // Set focus point for camera
        model.setFocusPoint(CGPoint(x: clampedX, y: clampedY))
        
        // Show focus indicator at tap location
        focusPoint = point
        showingFocusIndicator = true
        
        // Hide focus indicator after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showingFocusIndicator = false
        }
    }
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        let maxPhotos = selectedCaptureMode.maxPhotosAllowed(isPro: settings.isPro)
        for item in items {
            guard model.capturedImages.count < maxPhotos else { break }
            
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                
                // Crop to square aspect ratio
                let croppedImage = await cropToSquare(image: image)
                
                // Optimize image immediately for memory management
                let optimizedImage = await OptimizedImageManager.shared.optimizeImage(croppedImage)
                
                await MainActor.run {
                    model.capturedImages.append(optimizedImage)
                }
            }
        }
        
        // Clear selected items after processing
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
