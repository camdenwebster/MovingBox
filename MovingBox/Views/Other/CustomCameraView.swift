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
                    // Top controls - Flash
                    HStack {
                        Spacer()
                        
                        Button {
                            model.cycleFlash()
                        } label: {
                            Image(systemName: model.flashIcon)
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        .padding([.trailing, .top], 44)
                    }
                    
                    Spacer()
                    
                    // Zoom control
                    Button {
                        model.cycleZoom()
                    } label: {
                        Text(model.currentZoomText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 28)
                            .background(.black.opacity(0.25))
                            .cornerRadius(14)
                    }
                    .offset(y: -geometry.size.height * 0.1)
                    
                    // Bottom controls
                    HStack(spacing: 60) {
                        Spacer()
                            .frame(width: 40)
                        
                        // Shutter button
                        Button {
                            model.capturePhoto { image in
                                self.capturedImage = image
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 3)
                                    .frame(width: 62, height: 62)
                                Circle()
                                    .fill(.white)
                                    .frame(width: 50, height: 50)
                            }
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
                                .frame(width: 40, height: 40)
                                .background(.black.opacity(0.25))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 40)
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
    private lazy var zoomFactors: [CGFloat] = {
        guard let device = device else { return [1.0, 2.0, 5.0].map { CGFloat($0) } }
        var factors: [CGFloat] = [1.0, 2.0, 5.0].map { CGFloat($0) }
        if device.virtualDeviceSwitchOverVideoZoomFactors.contains(where: { CGFloat($0.doubleValue) < 1.0 }) {
            factors.insert(0.5, at: 0)
        }
        return factors
    }()
    
    private var currentZoomIndex = 0
    
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
