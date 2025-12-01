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
        // Use ScrollView if we have more than 4 zoom factors, otherwise use fixed HStack
        if zoomFactors.count > 4 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(zoomFactors.enumerated()), id: \.offset) { index, factor in
                        ZoomButtonView(
                            zoomFactor: factor,
                            isSelected: index == currentZoomIndex,
                            onTap: {
                                onZoomTap(index)
                            }
                        )
                        .frame(minWidth: 50)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
        } else {
            HStack(spacing: 8) {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
        }
    }
}

struct ZoomButtonView: View {
    let zoomFactor: CGFloat
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(formatZoomText(zoomFactor))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .yellow : .white)
                .frame(height: 32)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.white.opacity(0.2) : Color.clear)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 1)
                )
        }
    }

    private func formatZoomText(_ factor: CGFloat) -> String {
        if factor == 0.5 {
            return "0.5x"
        } else if factor.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(factor))x"
        } else {
            return String(format: "%.1fx", factor)
        }
    }
}

// MARK: - Macro Recommendation Banner

struct MacroRecommendationBanner: View {
    let recommendation: MacroRecommendation
    let onSwitch: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("💡 Get Closer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(recommendation.message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: onSwitch) {
                    Text("Switch")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow)
                        .cornerRadius(6)
                }
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.6))
        )
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
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
    let onTapToFocus: ((CGPoint) -> Void)?

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
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        view.isUserInteractionEnabled = true

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

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            parent.onTapToFocus?(point)
        }
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
        .accessibilityLabel("Camera mode selector")
        .accessibilityHint("Switch between single item and multi item capture modes")
    }
}

// MARK: - Top Camera Controls

struct CameraTopControls: View {
    @ObservedObject var model: MultiPhotoCameraViewModel
    let onClose: () -> Void
    let onDone: () -> Void
    let flashModeText: String
    let photoCount: Int

    @Environment(\.featureFlags) private var featureFlags

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Close button
                Button {
                    onClose()
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
                Button("Done") {
                    onDone()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.green)
                .disabled(photoCount == 0)
                .opacity(photoCount == 0 ? 0.5 : 1.0)
                .accessibilityIdentifier("cameraDoneButton")
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .padding(.bottom, 10)

            // Zoom control (feature flagged)
            if featureFlags.showZoomControl {
                ZoomControlView(
                    zoomFactors: model.zoomFactors,
                    currentZoomIndex: model.currentZoomIndex,
                    onZoomTap: { index in
                        model.setZoom(to: index)
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
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
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        VStack(spacing: 20) {
            // Shutter controls row
            HStack(spacing: 50) {
                // Photo count
                Text(photoCounterText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 60)
                    .accessibilityIdentifier("cameraPhotoCount")

                // Shutter button or Retake button (multi-item mode with photo)
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
                if captureMode.showsPhotoPickerButton {
                    Button {
                        onPhotoPickerTap()
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

// MARK: - Preview Support

#Preview("Single Item Mode") {
    MultiPhotoCameraView(
        capturedImages: .constant([]),
        captureMode: .singleItem,
        onPermissionCheck: { _ in },
        onComplete: { _, _ in }
    )
}

#Preview("Multi Item Mode") {
    MultiPhotoCameraView(
        capturedImages: .constant([]),
        captureMode: .multiItem,
        onPermissionCheck: { _ in },
        onComplete: { _, _ in }
    )
}

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
