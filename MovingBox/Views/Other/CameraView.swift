import SwiftUI
import AVFoundation

#if targetEnvironment(simulator)
import CoreImage.CIFilterBuiltins
#endif

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    @StateObject private var camera = CameraController()
    @State private var showingPhotoReview = false
    @State private var capturedImage: UIImage?
    @State private var showingPermissionDenied = false
    @State private var isFlashEnabled = false
    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
    
    var onPhotoCapture: ((UIImage, Bool, @escaping () -> Void) -> Void)?
    
    var body: some View {
        Group {
            if showingPhotoReview && !isOnboarding, let image = capturedImage {
                PhotoReviewView(image: image, onAccept: { acceptedImage, needsAnalysis, completion in
                    onPhotoCapture?(acceptedImage, needsAnalysis) {
                        self.capturedImage = nil
                        completion()
                        dismiss()
                    }
                }, onRetake: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        capturedImage = nil
                        showingPhotoReview = false
                    }
                }, isOnboarding: isOnboarding)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                ZStack {
                    if let preview = camera.previewLayer, camera.isSessionReady {
                        GeometryReader { geometry in
                            ZStack {
                                CameraPreviewView(previewLayer: preview)
                                    .onAppear {
                                        camera.updatePreviewOrientation(deviceOrientation)
                                    }
                                    .onRotate { newOrientation in
                                        deviceOrientation = newOrientation
                                        camera.updatePreviewOrientation(newOrientation)
                                    }
                                    .edgesIgnoringSafeArea(.all)
                                
                                Rectangle()
                                    .fill(Color.black.opacity(0.5))
                                    .edgesIgnoringSafeArea(.all)
                                    .overlay(
                                        Rectangle()
                                            .frame(width: min(geometry.size.width, geometry.size.height),
                                                   height: min(geometry.size.width, geometry.size.height))
                                            .blendMode(.destinationOut)
                                    )
                                    .compositingGroup()
                            }
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(2)
                            .tint(.white)
                    }
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .accessibilityIdentifier("dismissCamera")
                        }
                        
                        Spacer()
                        
                        HStack {
                            Button(action: {
                                isFlashEnabled.toggle()
                                camera.toggleFlash(isFlashEnabled)
                            }) {
                                Image(systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .accessibilityIdentifier("toggleFlash")
                            
                            Spacer()
                            
                            Button(action: {
                                camera.captureImage { capturedImage in
                                    if let image = capturedImage {
                                        self.capturedImage = image
                                        if isOnboarding {
                                            onPhotoCapture?(image, true) {
                                                self.capturedImage = nil
                                            }
                                        } else {
                                            showingPhotoReview = true
                                        }
                                    }
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 65, height: 65)
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                        .frame(width: 75, height: 75)
                                }
                            }
                            .accessibilityIdentifier("capturePhoto")
                            
                            Spacer()
                            
                            Button(action: { camera.switchCamera() }) {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .accessibilityIdentifier("switchCamera")
                        }
                        .padding(.bottom)
                    }
                }
                .background(Color.black)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingPhotoReview)
        .alert("Camera Access Required", isPresented: $showingPermissionDenied) {
            Button("Go to Settings", action: openSettings)
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("Please grant camera access in Settings to use this feature.")
        }
        .onAppear {
            camera.checkPermissions { authorized in
                if !authorized {
                    showingPermissionDenied = true
                }
            }
        }
        .onDisappear {
            capturedImage = nil
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// Add rotation view modifier
struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

extension View {
    func onRotate(action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

class CameraController: NSObject, ObservableObject {
    private var captureSession: AVCaptureSession?
    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var currentCamera: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    private var completionHandler: ((UIImage?) -> Void)?
    private var isConfigured = false
    private var flashEnabled = false
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    @Published var isSessionReady = false
    
    override init() {
        super.init()
        #if targetEnvironment(simulator)
        setupSimulatorPreview()
        #else
        setupCaptureSession()
        #endif
    }
    
    deinit {
        stopSession()
    }
    
    private func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
        photoOutput = nil
        previewLayer = nil
        frontCamera = nil
        backCamera = nil
        currentCamera = nil
    }

    func checkPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
    
    private func setupCaptureSession() {
        print("[Camera] Starting capture session setup")
        captureSession = AVCaptureSession()
        
        captureSession?.beginConfiguration()
        print("[Camera] Session configuration started")
        
        captureSession?.sessionPreset = .photo
        
        let initialOrientation = UIDevice.current.orientation
        let videoOrientation: AVCaptureVideoOrientation
        switch initialOrientation {
        case .landscapeLeft:
            videoOrientation = .landscapeRight
        case .landscapeRight:
            videoOrientation = .landscapeLeft
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        default:
            videoOrientation = .portrait
        }
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            print("[Camera] Back camera found")
            backCamera = device
            currentCamera = device
            
            do {
                try device.lockForConfiguration()
                device.unlockForConfiguration()
            } catch {
                print("[Camera] Error configuring device: \(error)")
            }
        } else {
            print("[Camera] Error: Could not initialize back camera")
        }
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            print("[Camera] Front camera found")
            frontCamera = device
        } else {
            print("[Camera] Warning: Could not initialize front camera")
        }
        
        guard let captureSession = self.captureSession,
              let currentCamera = self.currentCamera,
              let input = try? AVCaptureDeviceInput(device: currentCamera) else {
            print("[Camera] Error: Failed to create camera input")
            return
        }
        
        photoOutput = AVCapturePhotoOutput()
        
        if let photoOutput = photoOutput {
            if #available(iOS 14.0, *) {
                photoOutput.maxPhotoQualityPrioritization = .quality
            }
        }
        
        if captureSession.canAddInput(input) && captureSession.canAddOutput(photoOutput!) {
            captureSession.addInput(input)
            captureSession.addOutput(photoOutput!)
            
            if let photoConnection = photoOutput?.connection(with: .video),
               photoConnection.isVideoOrientationSupported {
                photoConnection.videoOrientation = videoOrientation
            }
            
            print("[Camera] Input and output added to session")
        } else {
            print("[Camera] Error: Could not add input or output to session")
        }
        
        captureSession.commitConfiguration()
        print("[Camera] Session configuration committed")
        
        setupPreviewLayer()
        
        if let connection = previewLayer?.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
        
        print("[Camera] Starting capture session")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            print("[Camera] Capture session started running")
            DispatchQueue.main.async {
                self?.isSessionReady = true
                print("[Camera] Session marked as ready")
            }
        }
    }
    
    private func setupPreviewLayer() {
        guard let captureSession = captureSession else {
            print("[Camera] Error: No capture session available for preview layer")
            return
        }
        print("[Camera] Setting up preview layer")
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        self.previewLayer = previewLayer
        print("[Camera] Preview layer setup complete")
    }
    
    func switchCamera() {
        guard let currentCamera = currentCamera,
              let captureSession = captureSession else { return }
        
        let newCamera = currentCamera.position == .back ? frontCamera : backCamera
        
        captureSession.inputs.forEach { input in
            captureSession.removeInput(input)
        }
        
        if let newCamera = newCamera,
           let input = try? AVCaptureDeviceInput(device: newCamera) {
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                self.currentCamera = newCamera
            }
        }
    }
    
    func captureImage(completion: @escaping (UIImage?) -> Void) {
        self.completionHandler = completion
        
        #if targetEnvironment(simulator)
        if let image = UIImage(named: "bicycle") {
            completion(image)
        } else {
            completion(createTestImage())
        }
        #else
        let settings = AVCapturePhotoSettings()
        settings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        
        if let deviceInput = captureSession?.inputs.first as? AVCaptureDeviceInput,
           deviceInput.device.position == .back {
            settings.flashMode = flashEnabled ? .on : .off
        }
        photoOutput?.capturePhoto(with: settings, delegate: self)
        #endif
    }
    
    #if targetEnvironment(simulator)
    private func setupSimulatorPreview() {
        print("[Camera Simulator] Setting up simulator preview")
        let simulatedSession = AVCaptureSession()
        let previewLayer = AVCaptureVideoPreviewLayer(session: simulatedSession)
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("Test Image".utf8)
        
        if let outputImage = filter.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            let testImage = UIImage(cgImage: cgImage)
            
            let imageLayer = CALayer()
            imageLayer.contents = testImage.cgImage
            imageLayer.contentsGravity = .resizeAspectFill
            imageLayer.frame = CGRect(x: 0, y: 0, width: 400, height: 400)
            
            previewLayer.addSublayer(imageLayer)
        }
        
        self.previewLayer = previewLayer
        self.isSessionReady = true
    }
    #endif

    private func createTestImage() -> UIImage? {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let testImage = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
            
            let text = "Camera Simulator"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        return testImage
    }
    
    func toggleFlash(_ enabled: Bool) {
        flashEnabled = enabled
    }
    
    func updatePreviewOrientation(_ orientation: UIDeviceOrientation) {
        guard let connection = previewLayer?.connection else { return }
        
        let videoOrientation: AVCaptureVideoOrientation
        switch orientation {
        case .landscapeLeft:
            videoOrientation = .landscapeRight
        case .landscapeRight:
            videoOrientation = .landscapeLeft
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        default:
            videoOrientation = .portrait
        }
        
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
        
        // Update photo output connection orientation
        if let photoConnection = photoOutput?.connection(with: .video),
           photoConnection.isVideoOrientationSupported {
            photoConnection.videoOrientation = videoOrientation
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        autoreleasepool {
            guard let imageData = photo.fileDataRepresentation(),
                  let originalImage = UIImage(data: imageData) else {
                completionHandler?(nil)
                return
            }
            
            let imageToProcess: UIImage
            if originalImage.imageOrientation != .up {
                UIGraphicsBeginImageContextWithOptions(originalImage.size, false, originalImage.scale)
                originalImage.draw(in: CGRect(origin: .zero, size: originalImage.size))
                if let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                    imageToProcess = normalizedImage
                } else {
                    imageToProcess = originalImage
                }
                UIGraphicsEndImageContext()
            } else {
                imageToProcess = originalImage
            }
            
            let imageSize = imageToProcess.size
            let shorterSide = min(imageSize.width, imageSize.height)
            let xOffset = (imageSize.width - shorterSide) / 2
            let yOffset = (imageSize.height - shorterSide) / 2
            let cropRect = CGRect(x: xOffset, y: yOffset, width: shorterSide, height: shorterSide)
            
            if let cgImage = imageToProcess.cgImage,
               let croppedCGImage = cgImage.cropping(to: cropRect) {
                let croppedImage = UIImage(cgImage: croppedCGImage, scale: imageToProcess.scale, orientation: .up)
                
                assert(croppedImage.size.width == croppedImage.size.height, "Cropped image is not square!")
                
                completionHandler?(croppedImage)
            } else {
                completionHandler?(nil)
            }
            
            completionHandler = nil
        }
    }
}

class PreviewViewController: UIViewController {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }
}

struct CameraPreviewView: UIViewControllerRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIViewController(context: Context) -> PreviewViewController {
        print("[Camera] Creating PreviewViewController")
        return PreviewViewController(previewLayer: previewLayer)
    }
    
    func updateUIViewController(_ uiViewController: PreviewViewController, context: Context) {
        print("[Camera] Updating PreviewViewController")
    }
}

extension View {
    func onboardingCamera() -> some View {
        self.modifier(OnboardingCameraModifier())
    }
}

private struct IsOnboardingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isOnboarding: Bool {
        get { self[IsOnboardingKey.self] }
        set { self[IsOnboardingKey.self] = newValue }
    }
}

struct OnboardingCameraModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.environment(\.isOnboarding, true)
    }
}
