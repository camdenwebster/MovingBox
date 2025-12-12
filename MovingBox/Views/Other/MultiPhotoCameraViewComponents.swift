import SwiftUI
import AVFoundation

// MARK: - Photo Thumbnail Scroll View

struct PhotoThumbnailScrollView: View {
    let images: [UIImage]
    let onDelete: (Int) -> Void

    var body: some View {
        if !images.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        PhotoThumbnailView(
                            image: image,
                            index: index,
                            onDelete: onDelete
                        )
                        .animation(.easeInOut(duration: 0.2), value: images.count)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 80)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Individual Photo Thumbnail Component

struct PhotoThumbnailView: View {
    let image: UIImage
    let index: Int
    let onDelete: (Int) -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack {
            // Thumbnail image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)

            // Delete button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onDelete(index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 20, height: 20)
                    )
            }
            .frame(width: 20, height: 20)
            .offset(x: 25, y: -25)
            .accessibilityLabel("Delete photo \(index + 1)")
        }
        .onTapGesture {
            // Visual feedback for tap
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Capture Animation View

struct CaptureAnimationView: View {
    let image: UIImage
    let startRect: CGRect
    let endRect: CGRect
    @Binding var isVisible: Bool

    @State private var animationProgress: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        if isVisible {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: interpolate(from: startRect.width, to: endRect.width, progress: animationProgress),
                    height: interpolate(from: startRect.height, to: endRect.height, progress: animationProgress)
                )
                .clipShape(RoundedRectangle(cornerRadius: interpolate(from: 0, to: 8, progress: animationProgress)))
                .position(
                    x: interpolate(from: startRect.midX, to: endRect.midX, progress: animationProgress),
                    y: interpolate(from: startRect.midY, to: endRect.midY, progress: animationProgress)
                )
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.6)) {
                        animationProgress = 1.0
                    }

                    withAnimation(.easeOut(duration: 0.2).delay(0.6)) {
                        opacity = 0
                    }
                }
        }
    }

    private func interpolate(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        return start + (end - start) * progress
    }
}

// MARK: - Zoom Control View

struct ZoomControlView: View {
    let zoomFactors: [CGFloat]
    let currentZoomIndex: Int
    let onZoomTap: (Int) -> Void

    var body: some View {
        // iOS native style - simple horizontal stack, no background
        HStack(spacing: 12) {
            ForEach(Array(zoomFactors.enumerated()), id: \.offset) { index, factor in
                ZoomButtonView(
                    zoomFactor: factor,
                    isSelected: index == currentZoomIndex,
                    onTap: {
                        onZoomTap(index)
                    }
                )
            }
        }
    }
}

struct ZoomButtonView: View {
    let zoomFactor: CGFloat
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Circular background for selected state (iOS native style)
                if isSelected {
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 50, height: 50)
                }

                Text(formatZoomText(zoomFactor))
                    .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel("\(formatZoomText(zoomFactor)) zoom")
    }

    private func formatZoomText(_ factor: CGFloat) -> String {
        if factor == 0.5 {
            return "0.5×"
        } else if factor.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(factor))×"
        } else {
            return String(format: "%.1f×", factor)
        }
    }
}


// MARK: - Focus Indicator View

struct FocusIndicatorView: View {
    @State private var scale: CGFloat = 1.5
    @State private var opacity: Double = 1.0

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Square Camera Preview View

struct SquareCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let onTapToFocus: ((CGPoint) -> Void)?

    class SquarePreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            // Ensure the preview layer fills the view and maintains square aspect
            previewLayer.frame = bounds

            // Set video gravity to show what will actually be captured
            previewLayer.videoGravity = .resizeAspectFill
        }
    }

    func makeUIView(context: Context) -> SquarePreviewView {
        let view = SquarePreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection {
            connection.videoRotationAngle = 90
        }

        // Add tap gesture for focus
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        view.isUserInteractionEnabled = true

        return view
    }

    func updateUIView(_ uiView: SquarePreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: SquareCameraPreviewView

        init(_ parent: SquareCameraPreviewView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            parent.onTapToFocus?(point)
        }
    }
}

// MARK: - Full Screen Camera Preview View

struct FullScreenCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let orientation: UIDeviceOrientation
//    let onTapToFocus: ((CGPoint) -> Void)?

    class FullScreenPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            // Ensure the preview layer fills the entire view
            previewLayer.frame = bounds

            // Set video gravity to fill the entire screen
            previewLayer.videoGravity = .resizeAspectFill
        }
    }

    func makeUIView(context: Context) -> FullScreenPreviewView {
        let view = FullScreenPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        // Set initial orientation
        updateVideoOrientation(for: view.previewLayer)

        // Add tap gesture for focus
//        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
//        view.addGestureRecognizer(tapGesture)
//        view.isUserInteractionEnabled = true

        return view
    }

    func updateUIView(_ uiView: FullScreenPreviewView, context: Context) {
        uiView.previewLayer.session = session

        // Update orientation if on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            updateVideoOrientation(for: uiView.previewLayer)
        }
    }

    private func updateVideoOrientation(for previewLayer: AVCaptureVideoPreviewLayer) {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            // Keep portrait for iPhone
            if #available(iOS 17.0, *) {
                previewLayer.connection?.videoRotationAngle = 0
            } else {
                previewLayer.connection?.videoOrientation = .portrait
            }
            return
        }

        // Map device orientation to rotation angle for iPad
        let rotationAngle: Double
        switch orientation {
        case .portrait:
            rotationAngle = 0
        case .portraitUpsideDown:
            rotationAngle = 180
        case .landscapeLeft:
            rotationAngle = 270
        case .landscapeRight:
            rotationAngle = 90
        default:
            rotationAngle = 0
        }

        if #available(iOS 17.0, *) {
            // Check if the rotation angle is supported before setting it
            if let connection = previewLayer.connection {
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                    print("📹 Set video rotation angle: \(rotationAngle)° for orientation: \(orientation)")
                } else {
                    print("📹 Video rotation angle \(rotationAngle)° not supported, using fallback")
                    // Fall back to fixed rotation for older devices
                    connection.videoRotationAngle = 90
                    print("📹 Fallback: Set video rotation angle: 90° for device orientation: \(orientation)")
                }
            }
        } else {
            // Fallback for older iOS versions
            let videoOrientation: AVCaptureVideoOrientation
            switch orientation {
            case .portrait:
                videoOrientation = .portrait
            case .portraitUpsideDown:
                videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                videoOrientation = .landscapeRight
            case .landscapeRight:
                videoOrientation = .landscapeLeft
            default:
                videoOrientation = .portrait
            }
            previewLayer.connection?.videoOrientation = videoOrientation
            print("📹 Set video orientation: \(videoOrientation) for device orientation: \(orientation)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: FullScreenCameraPreviewView

        init(_ parent: FullScreenCameraPreviewView) {
            self.parent = parent
        }

//        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
//            let point = gesture.location(in: gesture.view)
//            parent.onTapToFocus?(point)
//        }
    }
}

// MARK: - Capture Mode Picker

struct CaptureModePicker: View {
    @Binding var selectedMode: CaptureMode
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        Picker("Capture Mode", selection: $selectedMode) {
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.3))
                .padding(-4)
        )
        .onAppear {
            // Customize segmented control appearance
            UISegmentedControl.appearance().backgroundColor = UIColor.black.withAlphaComponent(0.5)
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor.yellow
            UISegmentedControl.appearance().setTitleTextAttributes([
                .foregroundColor: UIColor.white
            ], for: .normal)
            UISegmentedControl.appearance().setTitleTextAttributes([
                .foregroundColor: UIColor.black
            ], for: .selected)
        }
        .accessibilityLabel("Camera mode selector")
        .accessibilityHint("Switch between single item and multi item capture modes")
    }
}

// MARK: - Multi-Item Preview Overlay

struct MultiItemPreviewOverlay: View {
    let capturedImage: UIImage
    let squareSize: CGFloat
    let onRetake: () -> Void
    let onAnalyze: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: squareSize, height: squareSize)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 10)
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 20) {
                Button {
                    onRetake()
                } label: {
                    Text("Retake")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.red.opacity(0.8))
                        .cornerRadius(25)
                }

                Button {
                    onAnalyze()
                } label: {
                    Text("Analyze")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.green)
                        .cornerRadius(25)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
    }
}

// MARK: - Top Camera Controls

struct CameraTopControls: View {
    @ObservedObject var model: MultiPhotoCameraViewModel
    let onClose: () -> Void
    let onDone: () -> Void
    let isMultiItemPreviewShowing: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white.opacity(0.3)))
                }
                .accessibilityIdentifier("cameraCloseButton")

                Spacer()

                if !isMultiItemPreviewShowing {
                    HStack(spacing: 16) {
                        Button {
                            model.cycleFlash()
                        } label: {
                            Image(systemName: model.flashIcon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.white.opacity(0.3)))
                        }
                        .accessibilityLabel("Flash \(model.flashModeText)")

                        Button {
                            Task {
                                await model.switchCamera()
                            }
                        } label: {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.white.opacity(0.3)))
                        }
                        .accessibilityLabel("Flip camera")
                    }
                }
            }
            .padding(.horizontal)
//            .padding(.trailing, 40)
            
//            .padding(.top)
//            .padding(.bottom, 10)
        }
    }
}

// MARK: - Bottom Camera Controls

struct CameraBottomControls: View {
    let captureMode: CaptureMode
    let photoCount: Int
    let photoCounterText: String
    let hasPhotoCaptured: Bool
    let onShutterTap: () -> Void
    let onRetakeTap: () -> Void
    let onPhotoPickerTap: () -> Void
    @Binding var selectedCaptureMode: CaptureMode
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        VStack(spacing: 16) {
            // Shutter button on top (centered)
            if captureMode == .multiItem && hasPhotoCaptured {
                // Retake button in multi-item mode after capture
                Button {
                    onRetakeTap()
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
                    onShutterTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 70, height: 70)
                        Circle()
                            .strokeBorder(.white.opacity(0.5), lineWidth: 3)
                            .frame(width: 80, height: 80)
                    }
                }
                .accessibilityIdentifier("cameraShutterButton")
            }

            // Bottom row: Photo count, Mode picker, Gallery button
            HStack(spacing: 12) {
                // Photo count (left side)
                Text(photoCounterText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(minWidth: 60)
                    .accessibilityIdentifier("cameraPhotoCount")

                Spacer()

                // Capture mode segmented control (center)
                CaptureModePicker(selectedMode: $selectedCaptureMode)
                    .frame(maxWidth: 200)

                Spacer()

                // Photo picker button (right side)
                if captureMode.showsPhotoPickerButton {
                    Button {
                        onPhotoPickerTap()
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(minWidth: 60)
                    }
                } else {
                    // Spacer to maintain layout symmetry
                    Color.clear
                        .frame(minWidth: 60)
                }
            }
//            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Camera Preview Container

struct CameraPreviewContainer: View {
    let isUITesting: Bool
    let session: AVCaptureSession
    let orientation: UIDeviceOrientation
    let onFocusTap: (CGPoint) -> Void
    let onPermissionCheck: (Bool) -> Void
    let onOrientationChange: (UIDeviceOrientation) -> Void
    @Binding var focusPoint: CGPoint?
    @Binding var showingFocusIndicator: Bool

    var body: some View {
        Group {
            if isUITesting {
                Image("tablet", bundle: .main)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .onTapGesture { location in
                        focusPoint = location
                        showingFocusIndicator = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            showingFocusIndicator = false
                        }
                    }
                    .onAppear {
                        onPermissionCheck(true)
                    }
            } else {
                FullScreenCameraPreviewView(
                    session: session,
                    orientation: orientation,
//                    onTapToFocus: { point in
//                        onFocusTap(point)
//                        focusPoint = point
//                        showingFocusIndicator = true
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                            showingFocusIndicator = false
//                        }
//                    }
                )
                .onAppear {
                    Task {
                        await MainActor.run {
                            onPermissionCheck(true)
                        }
                    }
                    setupOrientationMonitoring(onOrientationChange: onOrientationChange)
                }
                .onDisappear {
                    cleanupOrientationMonitoring()
                }
            }
        }
    }

    private func setupOrientationMonitoring(onOrientationChange: @escaping (UIDeviceOrientation) -> Void) {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        let currentOrientation = UIDevice.current.orientation

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let interfaceOrientation = windowScene.interfaceOrientation
            let mappedOrientation: UIDeviceOrientation
            switch interfaceOrientation {
            case .portrait: mappedOrientation = .portrait
            case .portraitUpsideDown: mappedOrientation = .portraitUpsideDown
            case .landscapeLeft: mappedOrientation = .landscapeRight
            case .landscapeRight: mappedOrientation = .landscapeLeft
            default: mappedOrientation = .portrait
            }
            onOrientationChange(mappedOrientation)
        } else if currentOrientation != .unknown && currentOrientation != .faceUp && currentOrientation != .faceDown {
            onOrientationChange(currentOrientation)
        } else {
            onOrientationChange(.portrait)
        }

        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let newOrientation = UIDevice.current.orientation
            if newOrientation != .unknown && newOrientation != .faceUp && newOrientation != .faceDown {
                onOrientationChange(newOrientation)
            }
        }
    }

    private func cleanupOrientationMonitoring() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
}

// MARK: - Preview Support

#Preview("Photo Thumbnails") {
    VStack {
        PhotoThumbnailScrollView(
            images: [
                UIImage(systemName: "photo")!,
                UIImage(systemName: "camera")!,
                UIImage(systemName: "square.and.arrow.up")!
            ],
            onDelete: { _ in }
        )
        .background(Color.black)
    }
}
