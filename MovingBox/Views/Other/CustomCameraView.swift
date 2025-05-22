import SwiftUI
import AVFoundation

struct CustomCameraView: View {
    @StateObject private var model = CameraViewModel()
    @Binding var capturedImage: UIImage?
    let onPermissionCheck: (Bool) -> Void
    
    var body: some View {
        ZStack {
            CameraPreviewView(session: model.session)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button {
                        model.toggleFlash()
                    } label: {
                        Image(systemName: model.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.trailing)
                
                HStack(spacing: 60) {
                    Button {
                        model.switchCamera()
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Button {
                        model.capturePhoto { image in
                            self.capturedImage = image
                        }
                    } label: {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 75, height: 75)
                            .background(.white)
                            .clipShape(Circle())
                    }
                    
                    Button {
                        model.switchZoom()
                    } label: {
                        Text(model.currentZoomText)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .task {
            await model.checkPermissions(completion: onPermissionCheck)
        }
    }
}

class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var currentZoomText: String = "1x"
    
    let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private let output = AVCapturePhotoOutput()
    private var photoData: Data?
    private var completion: ((UIImage?) -> Void)?
    private var isBackCamera = true
    private let zoomFactors: [CGFloat] = [1.0, 2.0, 5.0]
    private var currentZoomIndex = 0
    
    override init() {
        super.init()
        setupSession()
    }
    
    func checkPermissions(completion: @escaping (Bool) -> Void) async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
            await startSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            completion(granted)
            if granted {
                await startSession()
            }
        default:
            completion(false)
        }
    }
    
    private func setupSession() {
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        self.device = device
        self.input = input
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }
    
    @MainActor
    private func startSession() {
        guard !session.isRunning else { return }
        session.startRunning()
    }
    
    func toggleFlash() {
        flashMode = flashMode == .on ? .off : .on
    }
    
    func switchCamera() {
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
    
    func switchZoom() {
        currentZoomIndex = (currentZoomIndex + 1) % zoomFactors.count
        let newZoom = zoomFactors[currentZoomIndex]
        
        do {
            try device?.lockForConfiguration()
            device?.videoZoomFactor = newZoom
            device?.unlockForConfiguration()
            
            currentZoomFactor = newZoom
            currentZoomText = String(format: "%.0fx", newZoom)
        } catch {
            print("Could not lock device for configuration: \(error)")
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion?(nil)
            return
        }
        
        if isBackCamera {
            completion?(image)
        } else {
            // Flip image if using front camera
            if let cgImage = image.cgImage {
                let flippedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
                completion?(flippedImage)
            } else {
                completion?(image)
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect.zero)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.frame
        }
    }
}