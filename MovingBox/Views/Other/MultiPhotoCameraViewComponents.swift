import SwiftUI
import AVFoundation
import SwiftUIBackports

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
        let zoomButtons = HStack(spacing: 12) {
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

        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                zoomButtons
            }
            .frame(maxWidth: .infinity)
        } else {
            zoomButtons
                .frame(maxWidth: .infinity)
        }
    }
}

struct ZoomButtonView: View {
    let zoomFactor: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    
    @Namespace private var glassEffectNamespace

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Circular background for selected state (iOS native style)
                if isSelected {
                    zoomText
                        .backport.glassEffect(in: Circle())
                        .backport.glassEffectID("\(formatZoomText(zoomFactor)) zoom", in: glassEffectNamespace)

                } else {
                    zoomText
                }
            }
        }
        .accessibilityLabel("\(formatZoomText(zoomFactor)) zoom")
    }

    var zoomText: some View {
        Text(formatZoomText(zoomFactor))
            .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
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


// MARK: - Camera Control Button

struct CameraControlButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    var accessibilityLabel: String?
    var accessibilityIdentifier: String?
    var isInteractive: Bool

    @Namespace private var glassEffectNamespace

    init(
        icon: String,
        size: CGFloat = 40,
        action: @escaping () -> Void,
        accessibilityLabel: String? = nil,
        accessibilityIdentifier: String? = nil,
        isInteractive: Bool = true
    ) {
        self.icon = icon
        self.size = size
        self.action = action
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.isInteractive = isInteractive
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(.white)
                .frame(width: size, height: size)
        }
        .backport.glassEffect(in: Circle())
        .backport.glassEffectID(icon, in: glassEffectNamespace)
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }

    private var iconSize: CGFloat {
        size * 0.5
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
        .frame(width: 150)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.3))
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

    @Namespace private var glassEffectNamespace

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

            Spacer()

            Button {
                onRetake()
            } label: {
                Image(systemName: "xmark")
                    .font(.title)
                    .foregroundColor(.red)
                    .padding()
            }
            .backport.glassEffect(in: Circle())
            .backport.glassEffectID("retake", in: glassEffectNamespace)
            .tint(.red)
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
    let hasPhotoCaptured: Bool

    @Namespace private var glassEffectNamespace

    var body: some View {
        let cameraControlButtons = HStack(spacing: 16) {
            CameraControlButton(
                icon: model.flashIcon,
                action: { model.cycleFlash() },
                accessibilityLabel: "Flash \(model.flashModeText)"
            )

            CameraControlButton(
                icon: "camera.rotate",
                action: {
                    Task {
                        await model.switchCamera()
                    }
                },
                accessibilityLabel: "Flip camera"
            )
        }
        
        HStack(spacing: 16) {
            CameraControlButton(
                icon: "xmark",
                action: onClose,
                accessibilityIdentifier: "cameraCloseButton"
            )

            Spacer()

            if !isMultiItemPreviewShowing {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 16) {
                        cameraControlButtons
                    }
                } else {
                    cameraControlButtons
                }
            }

            Spacer()

            Button(action: onDone) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white)
                    .font(.title)
                    .frame(width: 30, height: 40)
            }
            .disabled(!hasPhotoCaptured)
            .backport.glassProminentButtonStyle()
            .accessibilityLabel("Continue to analysis")

        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 10)
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

    @Namespace private var glassEffectNamespace

    var body: some View {
        VStack(spacing: 16) {
            if captureMode == .multiItem && hasPhotoCaptured {
                Button {
                    onRetakeTap()
                } label: {
                    Text("Retake")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 50)
                }
                .backport.glassEffect(in: Capsule())
                .backport.glassEffectID("retake-button", in: glassEffectNamespace)
                .tint(.red)
                .accessibilityIdentifier("cameraRetakeButton")
            } else {
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

            HStack(spacing: 12) {
                Text(photoCounterText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(minWidth: 60, alignment: .leading)
                    .accessibilityIdentifier("cameraPhotoCount")

                Spacer()

                CaptureModePicker(selectedMode: $selectedCaptureMode)
                    .frame(width: 150)

                Spacer()

                if captureMode.showsPhotoPickerButton {
                    CameraControlButton(
                        icon: "photo.on.rectangle",
                        size: 50,
                        action: onPhotoPickerTap,
                        accessibilityLabel: "Choose from library"
                    )
                } else {
                    Color.clear
                        .frame(width: 50, height: 50)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity)
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

#Preview("Camera Control Buttons") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            HStack(spacing: 16) {
                CameraControlButton(
                    icon: "xmark",
                    action: {},
                    accessibilityLabel: "Close"
                )

                CameraControlButton(
                    icon: "bolt.fill",
                    action: {},
                    accessibilityLabel: "Flash"
                )

                CameraControlButton(
                    icon: "camera.rotate",
                    action: {},
                    accessibilityLabel: "Flip camera"
                )

                CameraControlButton(
                    icon: "photo.on.rectangle",
                    action: {},
                    accessibilityLabel: "Photo library"
                )
            }

            Text("Standard Size (40pt)")
                .foregroundColor(.white)
                .font(.caption)

            HStack(spacing: 16) {
                CameraControlButton(
                    icon: "xmark",
                    size: 50,
                    action: {},
                    accessibilityLabel: "Close"
                )

                CameraControlButton(
                    icon: "bolt.fill",
                    size: 50,
                    action: {},
                    accessibilityLabel: "Flash"
                )
            }

            Text("Large Size (50pt)")
                .foregroundColor(.white)
                .font(.caption)
        }
        .padding()
    }
}

#Preview("Multi-Item Preview Overlay") {
    GeometryReader { geometry in
        let squareSize = min(geometry.size.width - 40, geometry.size.height - 280)

        MultiItemPreviewOverlay(
            capturedImage: createPreviewOverlayImage(),
            squareSize: squareSize,
            onRetake: { print("Retake tapped") },
            onAnalyze: { print("Analyze tapped") }
        )
    }
    .ignoresSafeArea()
}

private func createPreviewOverlayImage() -> UIImage {
    let size = CGSize(width: 800, height: 800)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        // Create gradient background
        let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
        context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

        // Add text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 60, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let text = "Preview" as NSString
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
