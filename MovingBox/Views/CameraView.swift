import SwiftUI
import AVFoundation

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @State private var showingPhotoReview = false
    @State private var capturedImage: UIImage?
    @State private var showingPermissionDenied = false
    
    var onPhotoCapture: ((UIImage) -> Void)?
    
    var body: some View {
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
        .sheet(isPresented: $showingPhotoReview) {
            if let image = capturedImage {
                PhotoReviewView(image: image) { acceptedImage in
                    onPhotoCapture?(acceptedImage)
                    dismiss()
                }
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
        .background(Color.black)
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the frame in the main thread
        DispatchQueue.main.async {
            previewLayer.frame = uiView.frame
        }
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession = AVCaptureSession()
            
            // Begin configuration
            self.captureSession?.beginConfiguration()
            
            // Set session preset
            self.captureSession?.sessionPreset = .photo
            
            // Setup cameras
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                self.backCamera = device
                self.currentCamera = device
            }
            
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                self.frontCamera = device
            }
            
            // Setup camera input
            guard let captureSession = self.captureSession,
                  let currentCamera = self.currentCamera,
                  let input = try? AVCaptureDeviceInput(device: currentCamera) else { return }
            
            // Setup photo output
            self.photoOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(self.photoOutput!) {
                captureSession.addInput(input)
                captureSession.addOutput(self.photoOutput!)
            }
            
            // Commit configuration
            self.captureSession?.commitConfiguration()
            
            // Setup preview layer
            self.setupPreviewLayer()
            
            // Start session
            self.captureSession?.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionReady = true
            }
        }
    }
    
    private func setupPreviewLayer() {
        guard let captureSession = captureSession else { return }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        self.previewLayer = previewLayer
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
