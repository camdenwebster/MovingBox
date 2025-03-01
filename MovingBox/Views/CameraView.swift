import SwiftUI
import AVFoundation

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @State private var showingPhotoReview = false
    @State private var capturedImage: UIImage?
    @State private var showingPermissionDenied = false
    
    var onPhotoCapture: ((UIImage, Bool, @escaping () -> Void) -> Void)?
    
    var body: some View {
        Group {
            if showingPhotoReview, let image = capturedImage {
                PhotoReviewView(image: image) { acceptedImage, needsAnalysis, completion in
                    onPhotoCapture?(acceptedImage, needsAnalysis, completion)
                    print("Calling completion handler for camera view and dismissing sheet in CameraView")
                }
            } else {
                ZStack {
                    // Camera preview
                    if let preview = camera.previewLayer, camera.isSessionReady {
                        CameraPreviewView(previewLayer: preview)
                            .ignoresSafeArea()
                    } else {
                        // Show loading state
                        ProgressView()
                            .scaleEffect(2)
                            .tint(.white)
                    }
                    
                    // Camera controls
                    VStack {
                        Spacer()
                        
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            
                            Spacer()
                            
                            // Capture button
                            Button(action: {
                                camera.captureImage { image in
                                    capturedImage = image
                                    showingPhotoReview = true
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
                            
                            Spacer()
                            
                            // Toggle camera button
                            Button(action: { camera.switchCamera() }) {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            }
                            .padding()
                        }
                        .padding(.bottom)
                    }
                }
                .background(Color.black)
            }
        }
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
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
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
        print("[Camera] PreviewViewController viewDidLoad")
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("[Camera] PreviewViewController viewDidLayoutSubviews with frame: \(view.frame)")
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

class CameraController: NSObject, ObservableObject {
    private var captureSession: AVCaptureSession?
    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var currentCamera: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    private var completionHandler: ((UIImage?) -> Void)?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    @Published var isSessionReady = false
    
    override init() {
        super.init()
        setupCaptureSession()
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
        
        // Begin configuration
        captureSession?.beginConfiguration()
        print("[Camera] Session configuration started")
        
        // Set session preset
        captureSession?.sessionPreset = .photo
        
        // Setup cameras
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            print("[Camera] Back camera found")
            backCamera = device
            currentCamera = device
        } else {
            print("[Camera] Error: Could not initialize back camera")
        }
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            print("[Camera] Front camera found")
            frontCamera = device
        } else {
            print("[Camera] Warning: Could not initialize front camera")
        }
        
        // Setup camera input
        guard let captureSession = self.captureSession,
              let currentCamera = self.currentCamera,
              let input = try? AVCaptureDeviceInput(device: currentCamera) else {
            print("[Camera] Error: Failed to create camera input")
            return
        }
        
        print("[Camera] Camera input created successfully")
        
        // Setup photo output
        photoOutput = AVCapturePhotoOutput()
        
        if captureSession.canAddInput(input) && captureSession.canAddOutput(photoOutput!) {
            captureSession.addInput(input)
            captureSession.addOutput(photoOutput!)
            print("[Camera] Input and output added to session")
        } else {
            print("[Camera] Error: Could not add input or output to session")
        }
        
        // Commit configuration
        captureSession.commitConfiguration()
        print("[Camera] Session configuration committed")
        
        // Setup preview layer
        setupPreviewLayer()
        
        // Start session in background
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
        
        // Get new camera
        let newCamera = currentCamera.position == .back ? frontCamera : backCamera
        
        // Remove current camera input
        captureSession.inputs.forEach { input in
            captureSession.removeInput(input)
        }
        
        // Add new camera input
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
        
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completionHandler?(nil)
            return
        }
        
        completionHandler?(image)
    }
}
