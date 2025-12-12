import SwiftUI
import AVFoundation

enum CameraMode {
    case singlePhoto
    case multiPhoto(maxPhotos: Int = 5)
}

struct CustomCameraView: View {
    @StateObject private var model = CameraViewModel()
    @Binding var capturedImage: UIImage?
    @Binding var capturedImages: [UIImage]
    let mode: CameraMode
    let onPermissionCheck: (Bool) -> Void
    let onComplete: (([UIImage], CaptureMode) -> Void)?
    let onCancel: (() -> Void)?
    
    // Single photo mode initializer (backward compatible)
    init(
        capturedImage: Binding<UIImage?>,
        onPermissionCheck: @escaping (Bool) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self._capturedImage = capturedImage
        self._capturedImages = .constant([])
        self.mode = .singlePhoto
        self.onPermissionCheck = onPermissionCheck
        self.onComplete = nil
        self.onCancel = onCancel
    }
    
    // Multi photo mode initializer
    init(
        capturedImages: Binding<[UIImage]>,
        mode: CameraMode = .multiPhoto(),
        onPermissionCheck: @escaping (Bool) -> Void,
        onComplete: @escaping ([UIImage], CaptureMode) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self._capturedImage = .constant(nil)
        self._capturedImages = capturedImages
        self.mode = mode
        self.onPermissionCheck = onPermissionCheck
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    private let aspectRatio: CGFloat = 4.0 / 3.0
    private static let barHeightFactor = 0.15
    
    var body: some View {
        switch mode {
        case .singlePhoto:
            singlePhotoView
        case .multiPhoto(_):
            MultiPhotoCameraView(
                capturedImages: $capturedImages,
                onPermissionCheck: onPermissionCheck,
                onComplete: onComplete ?? { _, _ in },
                onCancel: onCancel
            )
        }
    }
    
    private var singlePhotoView: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                CameraPreviewView(session: model.session)
                    .ignoresSafeArea()
                    .onAppear {
                        Task {
                            await model.checkPermissions(completion: onPermissionCheck)
                        }
                    }
                    .onDisappear {
                        Task {
                            await model.stopSession()
                        }
                    }
                
                // Black borders to maintain 3:4 aspect ratio
                VStack(spacing: 0) {
                    // Top black bar - smaller
                    Color.black
                        .opacity(0.75)
                        .frame(height: geometry.size.height * Self.barHeightFactor * 0.5)
                        .ignoresSafeArea()
                    
                    // Camera preview space
                    Color.clear
                        .frame(height: geometry.size.width * aspectRatio)
                    
                    // Bottom black bar - larger
                    Color.black
                        .opacity(0.75)
                        .frame(height: geometry.size.height * Self.barHeightFactor * 1.5)
                        .ignoresSafeArea()
                }
                
                // Camera controls
                VStack {
                    // Top controls
                    HStack(spacing: 16) {
                        // Close button (left)
                        if let onCancel = onCancel {
                            Button {
                                onCancel()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(.black.opacity(0.5)))
                            }
                        }

                        Spacer()

                        // Flash button
                        Button {
                            model.cycleFlash()
                        } label: {
                            Image(systemName: model.flashIcon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }

                        // Camera flip button (moved to top)
                        Button {
                            Task {
                                await model.switchCamera()
                            }
                        } label: {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)

                    Spacer()

                    // Zoom controls (horizontal, above bottom bar)
                    HStack(spacing: 12) {
                        ForEach(model.zoomFactors.indices, id: \.self) { index in
                            Button {
                                model.setZoom(to: index)
                            } label: {
                                ZStack {
                                    if model.currentZoomIndex == index {
                                        Circle()
                                            .fill(.white.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                    }

                                    Text(model.zoomTextForIndex(index))
                                        .font(.system(size: 16, weight: model.currentZoomIndex == index ? .bold : .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)

                    // Bottom controls
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            // Thumbnail placeholder (left)
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 50, height: 50)

                            Spacer()

                            // Shutter button (center)
                            Button {
                                model.capturePhoto { image in
                                    self.capturedImage = image
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 4)
                                        .frame(width: 76, height: 76)
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 64, height: 64)
                                }
                            }

                            Spacer()

                            // Camera flip placeholder for symmetry
                            Color.clear
                                .frame(width: 50, height: 50)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        .padding(.bottom, 50)
                    }
                    .background(
                        Rectangle()
                            .fill(.black)
                            .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
        }
    }
}

@MainActor
final class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var currentZoomText: String = "1x"
    
    var flashIcon: String {
        switch flashMode {
        case .auto: return "bolt.badge.a.fill"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }
    
    let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private let output = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?
    private var isBackCamera = true
    private var isConfigured = false
    
    // Include 0.5x for wide angle if available
    lazy var zoomFactors: [CGFloat] = {
        guard let device = device else { return [1.0, 2.0, 5.0].map { CGFloat($0) } }
        var factors: [CGFloat] = [1.0, 2.0, 5.0].map { CGFloat($0) }
        if device.virtualDeviceSwitchOverVideoZoomFactors.contains(where: { CGFloat($0.doubleValue) < 1.0 }) {
            factors.insert(0.5, at: 0)
        }
        return factors
    }()

    @Published var currentZoomIndex = 0
    
    override init() {
        super.init()
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.setupSession()
        }
    }
    
    func cycleFlash() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        case .off:
            flashMode = .auto
        @unknown default:
            flashMode = .auto
        }
    }
    
    func cycleZoom() {
        currentZoomIndex = (currentZoomIndex + 1) % zoomFactors.count
        let newZoom = zoomFactors[currentZoomIndex]

        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = newZoom
            device.unlockForConfiguration()

            currentZoomFactor = newZoom
            currentZoomText = String(format: "%.1fx", newZoom)
        } catch {
            print("Could not lock device for configuration: \(error)")
        }
    }

    func setZoom(to index: Int) {
        guard index >= 0 && index < zoomFactors.count else { return }
        currentZoomIndex = index
        let newZoom = zoomFactors[index]

        guard let device = device else { return }

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = newZoom
            device.unlockForConfiguration()

            currentZoomFactor = newZoom
            currentZoomText = String(format: "%.1fx", newZoom)
        } catch {
            print("Could not lock device for configuration: \(error)")
        }
    }

    func zoomTextForIndex(_ index: Int) -> String {
        guard index >= 0 && index < zoomFactors.count else { return "1×" }
        let factor = zoomFactors[index]
        if factor == floor(factor) {
            return "\(Int(factor))×"
        } else {
            return String(format: "%.1f×", factor)
        }
    }
    
    func checkPermissions(completion: @escaping (Bool) -> Void) async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
            await startSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                completion(granted)
            }
            if granted {
                await startSession()
            }
        default:
            await MainActor.run {
                completion(false)
            }
        }
    }
    
    private func setupSession() async {
        guard !isConfigured else { return }
        
        await MainActor.run {
            session.sessionPreset = .photo
        }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        await MainActor.run { [self] in
            self.device = device
            self.input = input
            
            session.beginConfiguration()
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
            
            isConfigured = true
        }
    }
    
    func stopSession() async {
        guard session.isRunning else { return }
        session.stopRunning()
    }
    
    private func startSession() async {
        guard !session.isRunning else { return }
        
        await MainActor.run {
            session.startRunning()
        }
    }
    
    func switchCamera() async {
        await MainActor.run {
            session.beginConfiguration()
            
            if let currentInput = input {
                session.removeInput(currentInput)
            }
            
            isBackCamera.toggle()
            let position: AVCaptureDevice.Position = isBackCamera ? .back : .front
            
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                session.commitConfiguration()
                return
            }
            
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                device = newDevice
                input = newInput
            }
            
            session.commitConfiguration()
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        output.capturePhoto(with: settings, delegate: self)
    }
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in
                self.completion?(nil)
                self.completion = nil
            }
            return
        }
        
        Task { @MainActor in
            if isBackCamera {
                self.completion?(image)
            } else {
                if let cgImage = image.cgImage {
                    let flippedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
                    self.completion?(flippedImage)
                } else {
                    self.completion?(image)
                }
            }
            self.completion = nil
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection {
            connection.videoRotationAngle = 90
        }
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}
