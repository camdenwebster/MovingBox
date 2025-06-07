import SwiftUI
import AVFoundation
import PhotosUI

struct MultiPhotoCameraView: View {
    @StateObject private var model = MultiPhotoCameraViewModel()
    @Binding var capturedImages: [UIImage]
    let onPermissionCheck: (Bool) -> Void
    let onComplete: ([UIImage]) -> Void
    let onCancel: (() -> Void)?
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingPhotoPicker = false
    
    // Default initializer with onCancel parameter
    init(
        capturedImages: Binding<[UIImage]>,
        onPermissionCheck: @escaping (Bool) -> Void,
        onComplete: @escaping ([UIImage]) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self._capturedImages = capturedImages
        self.onPermissionCheck = onPermissionCheck
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    // Square aspect ratio for viewfinder
    private let aspectRatio: CGFloat = 1.0
    private static let barHeightFactor = 0.15
    
    var body: some View {
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
                
                // Calculate layout dimensions
                let topControlsHeight: CGFloat = 44 + 20 // top padding + controls
                let thumbnailHeight: CGFloat = model.capturedImages.isEmpty ? 0 : 100 // thumbnail area when photos exist
                let viewfinderSize = geometry.size.width - 32
                let viewfinderTop = topControlsHeight + thumbnailHeight + 20
                let viewfinderCenter = viewfinderTop + (viewfinderSize / 2)
                
                // Top black bar - covers area above viewfinder
                Color.black
                    .opacity(0.75)
                    .frame(height: viewfinderTop)
                    .frame(maxWidth: .infinity)
                    .position(x: geometry.size.width / 2, y: viewfinderTop / 2)
                    .ignoresSafeArea()
                
                // Bottom black bar - covers entire area below viewfinder to bottom
                Color.black
                    .opacity(0.75)
                    .frame(height: geometry.size.height - (viewfinderTop + viewfinderSize))
                    .frame(maxWidth: .infinity)
                    .position(x: geometry.size.width / 2, y: (viewfinderTop + viewfinderSize + geometry.size.height) / 2)
                    .ignoresSafeArea()
                
                // Square viewfinder border - positioned based on calculated top
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: viewfinderSize, height: viewfinderSize)
                    .position(x: geometry.size.width / 2, y: viewfinderCenter)
                
                // Camera controls
                VStack {
                    // Top controls
                    HStack {
                        // Cancel button
                        if let onCancel = onCancel {
                            Button("Cancel") {
                                onCancel()
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 44)
                    
                    // Thumbnails scroll view (positioned below top controls)
                    if !model.capturedImages.isEmpty {
                        PhotoThumbnailScrollView(
                            images: model.capturedImages,
                            onDelete: { index in
                                model.removeImage(at: index)
                            }
                        )
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                    
                    // Zoom control (positioned above bottom controls)
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
                    .padding(.bottom, 20)
                    
                    // Bottom controls
                    HStack {
                        // Left side - Photo count and camera roll button
                        VStack(spacing: 8) {
                            // Photo count indicator
                            Text("\(model.capturedImages.count)/5")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.5))
                                .cornerRadius(12)
                            
                            // Photo picker button
                            Button {
                                showingPhotoPicker = true
                            } label: {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.black.opacity(0.25))
                                    .clipShape(Circle())
                            }
                        }
                        .frame(width: 60)
                        
                        Spacer()
                        
                        // Center - Shutter button
                        Button {
                            if model.capturedImages.count >= 5 {
                                model.showPhotoLimitAlert = true
                            } else {
                                model.capturePhoto()
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
                        
                        Spacer()
                        
                        // Right side - Camera controls and Done button
                        VStack(spacing: 12) {
                            // Camera controls stacked horizontally
                            HStack(spacing: 8) {
                                // Camera switcher
                                Button {
                                    Task {
                                        await model.switchCamera()
                                    }
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(.black.opacity(0.25))
                                        .clipShape(Circle())
                                }
                                
                                // Flash control
                                Button {
                                    model.cycleFlash()
                                } label: {
                                    Image(systemName: model.flashIcon)
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(.black.opacity(0.25))
                                        .clipShape(Circle())
                                }
                            }
                            
                            // Done button
                            Button("Done") {
                                onComplete(model.capturedImages)
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .disabled(model.capturedImages.isEmpty)
                            .opacity(model.capturedImages.isEmpty ? 0.5 : 1.0)
                        }
                        .frame(width: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Photo Limit Reached", isPresented: $model.showPhotoLimitAlert) {
            Button("OK") { }
        } message: {
            Text("You can take up to 5 photos. Delete a photo to take another one.")
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedItems,
            maxSelectionCount: 5 - model.capturedImages.count,
            matching: .images
        )
        .onChange(of: selectedItems) { _, newItems in
            Task {
                await processSelectedPhotos(newItems)
            }
        }
        .onChange(of: model.capturedImages) { _, newImages in
            capturedImages = newImages
        }
    }
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard model.capturedImages.count < 5 else { break }
            
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

@MainActor
final class MultiPhotoCameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var currentZoomText: String = "1x"
    @Published var capturedImages: [UIImage] = []
    @Published var showPhotoLimitAlert = false
    
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
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func removeImage(at index: Int) {
        guard index >= 0 && index < capturedImages.count else { return }
        capturedImages.remove(at: index)
    }
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("Failed to capture photo: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        Task { @MainActor in
            // Crop to square aspect ratio
            let croppedImage = await cropToSquare(image: image)
            
            // Optimize image immediately for memory management
            let optimizedImage = await OptimizedImageManager.shared.optimizeImage(croppedImage)
            
            if isBackCamera {
                self.capturedImages.append(optimizedImage)
            } else {
                // Flip front camera images
                if let cgImage = optimizedImage.cgImage {
                    let flippedImage = UIImage(cgImage: cgImage, scale: optimizedImage.scale, orientation: .leftMirrored)
                    self.capturedImages.append(flippedImage)
                } else {
                    self.capturedImages.append(optimizedImage)
                }
            }
            
            print("📸 MultiPhotoCameraView - Captured photo \(self.capturedImages.count)/5")
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

// MARK: - Photo Thumbnail Scroll View Component

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

#Preview {
    MultiPhotoCameraView(
        capturedImages: .constant([]),
        onPermissionCheck: { _ in },
        onComplete: { _ in }
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