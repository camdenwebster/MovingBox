import Foundation
import AVFoundation
import UIKit
import Combine

// MARK: - UIDevice Extension

extension UIDevice {
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafeBytes(of: &systemInfo.machine) { buffer in
            var codeArray: [CChar] = []
            for byte in buffer {
                if byte == 0 {
                    break
                }
                codeArray.append(CChar(bitPattern: byte))
            }
            codeArray.append(0)  // Null terminate
            return codeArray
        }
        let modelIdentifier = String(cString: modelCode)
        return modelIdentifier
    }
}

// MARK: - Camera Capability Model

struct CameraCapability {
    let device: AVCaptureDevice
    let deviceType: AVCaptureDevice.DeviceType
    let minZoomFactor: CGFloat
    let maxZoomFactor: CGFloat
    let minimumFocusDistance: Int  // in millimeters
    let displayZoomFactor: CGFloat  // normalized display factor (0.5x, 1x, 3x, etc.)

    var displayLabel: String {
        if displayZoomFactor == 0.5 {
            return "0.5x"
        } else if displayZoomFactor.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(displayZoomFactor))x"
        } else {
            return String(format: "%.1fx", displayZoomFactor)
        }
    }
}

// MARK: - Macro Recommendation

struct MacroRecommendation {
    let currentCamera: CameraCapability
    let recommendedCamera: CameraCapability
    let focusDistanceImprovement: Int  // in millimeters
    let message: String

    /// True if the recommended camera can focus significantly closer than current camera
    var shouldAutoSwitch: Bool {
        focusDistanceImprovement > 50  // If improvement is > 50mm, worth suggesting
    }
}

// MARK: - Camera Device Manager

@MainActor
final class CameraDeviceManager: NSObject {
    private(set) var availableCameras: [CameraCapability] = []
    private(set) var optimalZoomLevels: [CGFloat] = []

    private var discoveredDevices: [AVCaptureDevice.DeviceType: AVCaptureDevice] = [:]
    private let position: AVCaptureDevice.Position

    init(position: AVCaptureDevice.Position = .back) {
        self.position = position
        super.init()
        discoverCameras()
    }

    // MARK: - Camera Discovery

    /// Discover all available cameras and their capabilities
    private func discoverCameras() {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera
        ]

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )

        print("📷 Discovering cameras for position: \(position)")

        var capabilities: [CameraCapability] = []

        for device in discoverySession.devices {
            if let capability = createCapability(for: device) {
                capabilities.append(capability)
                discoveredDevices[device.deviceType] = device
                print("✅ Found \(device.deviceType): zoom [\(capability.minZoomFactor)x-\(capability.maxZoomFactor)x], min focus: \(capability.minimumFocusDistance)mm, display: \(capability.displayLabel)")
            }
        }

        // Sort by zoom factor for consistent ordering
        self.availableCameras = capabilities.sorted { $0.displayZoomFactor < $1.displayZoomFactor }

        // Calculate optimal zoom levels
        self.optimalZoomLevels = calculateZoomLevels()

        print("📷 Camera discovery complete: \(self.availableCameras.count) cameras found")
        print("📷 Discovered cameras: \(self.availableCameras.map { "\($0.deviceType)=\($0.displayLabel)" }.joined(separator: ", "))")
        print("📷 Optimal zoom levels: \(self.optimalZoomLevels.map { String(format: "%.1fx", $0) })")
    }

    /// Create a capability object for a device
    private func createCapability(for device: AVCaptureDevice) -> CameraCapability? {
        // Get the default format for the device
        guard device.formats.first != nil else {
            print("❌ No formats available for device: \(device.deviceType)")
            return nil
        }

        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = device.maxAvailableVideoZoomFactor
        let minFocus = device.minimumFocusDistance

        // Determine display zoom factor based on device type
        let displayZoom = getDisplayZoomFactor(for: device.deviceType, minZoom: minZoom)

        return CameraCapability(
            device: device,
            deviceType: device.deviceType,
            minZoomFactor: minZoom,
            maxZoomFactor: maxZoom,
            minimumFocusDistance: minFocus,
            displayZoomFactor: displayZoom
        )
    }

    /// Determine the display zoom factor for a camera type
    private func getDisplayZoomFactor(
        for deviceType: AVCaptureDevice.DeviceType,
        minZoom: CGFloat
    ) -> CGFloat {
        switch deviceType {
        case .builtInUltraWideCamera:
            // Ultra-wide is typically 0.5x
            let modelIdentifier = UIDevice.current.modelIdentifier
            print("📷 Ultra-wide camera detected on \(modelIdentifier)")
            return 0.5
        case .builtInWideAngleCamera:
            // Standard wide angle is always 1x
            return 1.0
        case .builtInTelephotoCamera:
            // Telephoto zoom varies by device:
            // iPhone 17 (16 Pro/Pro Max): 5x
            // iPhone 16 Pro: 5x
            // iPhone 15 Pro: 3x
            // iPhone 14 Pro: 3x
            let modelIdentifier = UIDevice.current.modelIdentifier
            print("📷 Telephoto camera detected on \(modelIdentifier)")

            // Check for iPhone 17 (16 Pro) or iPhone 16 Pro models (both have 5x telephoto)
            if modelIdentifier.contains("iPhone17") || modelIdentifier.contains("iPhone16,2") {
                print("📷 Detected iPhone 16/17 Pro - using 5.0x telephoto")
                return 5.0
            }

            // For other models, default to 3x (older Pro models)
            print("📷 Not iPhone 16/17 Pro - using 3.0x telephoto as fallback")
            return 3.0
        default:
            return 1.0
        }
    }

    /// Calculate optimal zoom levels to show in UI
    private func calculateZoomLevels() -> [CGFloat] {
        var levels = Set<CGFloat>()

        for capability in availableCameras {
            levels.insert(capability.displayZoomFactor)
        }

        // Ensure 1x is always included as baseline
        levels.insert(1.0)

        return Array(levels).sorted()
    }

    // MARK: - Camera Selection

    /// Get the best camera for a specific zoom level
    func camera(forZoomLevel zoom: CGFloat) -> CameraCapability? {
        print("📷 Looking for camera that supports zoom \(String(format: "%.1fx", zoom))")

        // First, try to find exact match
        if let exact = availableCameras.first(where: { $0.displayZoomFactor == zoom }) {
            print("📷 Found exact match: \(exact.deviceType) at \(exact.displayLabel)")
            return exact
        }

        // Then find best match that can achieve this zoom
        let candidates = availableCameras
            .filter { $0.minZoomFactor <= zoom && zoom <= $0.maxZoomFactor }

        print("📷 Found \(candidates.count) candidates that can achieve this zoom")

        return candidates
            .min { abs($0.displayZoomFactor - zoom) < abs($1.displayZoomFactor - zoom) }
    }

    /// Get the best camera for macro/close-up photography
    func bestCameraForMacro() -> CameraCapability? {
        // Ultra-wide typically has shortest minimum focus distance
        return availableCameras.min { $0.minimumFocusDistance < $1.minimumFocusDistance }
    }

    /// Get camera by type
    func camera(ofType deviceType: AVCaptureDevice.DeviceType) -> CameraCapability? {
        return availableCameras.first { $0.deviceType == deviceType }
    }

    // MARK: - Macro Detection & Recommendations

    /// Check if current camera would benefit from switching for macro photography
    func checkMacroRecommendation(
        currentDevice: AVCaptureDevice,
        currentZoom: CGFloat
    ) -> MacroRecommendation? {
        guard let currentCapability = availableCameras.first(where: { $0.device == currentDevice }) else {
            return nil
        }

        // Check if ultra-wide would be significantly better
        guard let bestMacro = bestCameraForMacro(),
              bestMacro.device != currentDevice else {
            return nil  // Already using best macro camera or no better option
        }

        let focusImprovement = currentCapability.minimumFocusDistance - bestMacro.minimumFocusDistance

        // Only recommend if improvement is meaningful (> 50mm)
        guard focusImprovement > 50 else {
            return nil
        }

        let message = String(
            format: "Switch to %.1fx for better close-up focus (%.0fmm closer)",
            bestMacro.displayZoomFactor,
            CGFloat(focusImprovement)
        )

        return MacroRecommendation(
            currentCamera: currentCapability,
            recommendedCamera: bestMacro,
            focusDistanceImprovement: focusImprovement,
            message: message
        )
    }

    /// Get the device object for a capability
    func device(for capability: CameraCapability) -> AVCaptureDevice {
        return capability.device
    }

    // MARK: - Utility Methods

    /// Check if a specific zoom factor is supported by any camera
    func canAchieveZoom(_ zoom: CGFloat) -> Bool {
        return availableCameras.contains { $0.minZoomFactor <= zoom && zoom <= $0.maxZoomFactor }
    }

    /// Get all supported zoom levels from all cameras
    func allSupportedZoomLevels() -> [CGFloat] {
        optimalZoomLevels
    }
}

// MARK: - Camera View Model

@MainActor
final class MultiPhotoCameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var currentZoomText: String = "1x"
    @Published var capturedImages: [UIImage] = []
    @Published var showPhotoLimitAlert = false
    @Published var currentZoomIndex: Int = 0
    @Published var macroRecommendation: MacroRecommendation? = nil
    @Published var selectedCaptureMode: CaptureMode = .singleItem
    @Published var showingModeSwitchConfirmation = false
    @Published var showingPaywall = false
    private var cameraDeviceManager: CameraDeviceManager?
    private var pendingCaptureMode: CaptureMode?
    private var isHandlingModeChange = false

    var flashIcon: String {
        switch flashMode {
        case .auto: return "bolt.badge.a.fill"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }
    
    var flashModeText: String {
        switch flashMode {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        @unknown default: return "Off"
        }
    }

    let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private let output = AVCapturePhotoOutput()
    private var isBackCamera = true
    private var isConfigured = false

    /// Get zoom factors from the device manager (dynamic discovery)
    var zoomFactors: [CGFloat] {
        cameraDeviceManager?.allSupportedZoomLevels() ?? [1.0, 2.0, 5.0]
    }

    private static var initializationCounter = 0

    override init() {
        super.init()
        Self.initializationCounter += 1
        print("🎥 MultiPhotoCameraViewModel #\(Self.initializationCounter) initialized")
        // Initialize camera device manager
        self.cameraDeviceManager = CameraDeviceManager(position: .back)
        // Setup session immediately on init - it's safe because init is called once per @StateObject
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
        setZoom(to: currentZoomIndex)
    }

    func setZoom(to index: Int) {
        guard index >= 0 && index < zoomFactors.count else {
            print("❌ Invalid zoom index: \(index), available: \(zoomFactors.count)")
            return
        }

        let newZoom = zoomFactors[index]
        print("🔍 Setting zoom to index \(index) = \(String(format: "%.1fx", newZoom))")

        guard let device = device else {
            print("❌ No device available for zoom")
            return
        }

        do {
            try device.lockForConfiguration()
            let previousZoom = device.videoZoomFactor

            // Check if we need to switch cameras for this zoom level
            if let targetCamera = cameraDeviceManager?.camera(forZoomLevel: newZoom),
               targetCamera.device != device {
                print("📱 Zoom level \(String(format: "%.1fx", newZoom)) requires camera switch from \(device.deviceType) to \(targetCamera.deviceType)")
                device.unlockForConfiguration()

                // Update zoom index BEFORE switching cameras to ensure UI consistency
                currentZoomIndex = index
                currentZoomFactor = newZoom
                currentZoomText = String(format: "%.1fx", newZoom)

                // Switch camera and apply zoom
                Task {
                    await switchToCamera(targetCamera.device, withZoom: newZoom)
                    // Ensure macro recommendation is updated after camera switch
                    await MainActor.run {
                        self.updateMacroRecommendation()
                    }
                }
                return
            }

            // Apply zoom on current device
            device.videoZoomFactor = newZoom
            device.unlockForConfiguration()

            currentZoomIndex = index
            currentZoomFactor = newZoom
            currentZoomText = String(format: "%.1fx", newZoom)

            // Check for macro recommendation
            updateMacroRecommendation()

            print("✅ Zoom changed from \(String(format: "%.1fx", previousZoom)) to \(currentZoomText)")
        } catch {
            print("❌ Could not lock device for configuration: \(error)")
        }
    }

    /// Update macro recommendation based on current camera and zoom
    private func updateMacroRecommendation() {
        guard let device = device else { return }
        let recommendation = cameraDeviceManager?.checkMacroRecommendation(
            currentDevice: device,
            currentZoom: currentZoomFactor
        )
        self.macroRecommendation = recommendation
        if let recommendation = recommendation {
            print("💡 Macro recommendation: \(recommendation.message)")
        }
    }

    func checkPermissions(completion: @escaping (Bool) -> Void) async {
        print("📹 checkPermissions called, status checking...")
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📹 Camera authorization status: \(status)")

        switch status {
        case .authorized:
            print("📹 Camera already authorized")
            completion(true)
            await startSession()
        case .notDetermined:
            print("📹 Requesting camera permission...")
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            print("📹 Permission request result: \(granted)")
            await MainActor.run {
                completion(granted)
            }
            if granted {
                await startSession()
            }
        default:
            print("📹 Camera permission denied or restricted")
            await MainActor.run {
                completion(false)
            }
        }
    }

    private func setupSession() async {
        guard !isConfigured else {
            print("📹 setupSession called but already configured, returning")
            return
        }

        print("📹 setupSession starting...")

        await MainActor.run {
            session.sessionPreset = .photo
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("❌ Failed to get camera device or create input")
            return
        }

        print("✅ Got camera device and input")

        await MainActor.run { [self] in
            self.device = device
            self.input = input
            // Refresh camera device manager with newly discovered devices
            self.cameraDeviceManager = CameraDeviceManager(position: .back)

            session.beginConfiguration()
            if session.canAddInput(input) {
                session.addInput(input)
                print("✅ Added camera input to session")
            } else {
                print("❌ Cannot add input to session")
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
                print("✅ Added photo output to session")
            } else {
                print("❌ Cannot add output to session")
            }
            session.commitConfiguration()
            print("✅ Session configuration committed")

            // Configure initial focus settings
            do {
                try device.lockForConfiguration()

                // Set up continuous autofocus if supported
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                    print("✅ Initial focus mode set to continuous autofocus")
                }

                // Set up continuous auto exposure if supported
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                    print("✅ Initial exposure mode set to continuous auto exposure")
                }

                device.unlockForConfiguration()
                print("📹 Camera focus capabilities: focus POI supported: \(device.isFocusPointOfInterestSupported)")
            } catch {
                print("❌ Error configuring initial focus settings: \(error)")
            }


            isConfigured = true
            print("📹 setupSession completed successfully")

            // Set initial zoom to 1.0x (wide-angle camera)
            // Find the index of 1.0x in the zoom factors array
            if let index = self.zoomFactors.firstIndex(of: 1.0) {
                self.currentZoomIndex = index
                self.currentZoomFactor = 1.0
                self.currentZoomText = "1x"
                print("📹 Initial zoom set to 1.0x at index \(index)")
            } else {
                print("⚠️ Could not find 1.0x zoom level in available factors: \(self.zoomFactors)")
            }
        }
    }

    func stopSession() async {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    private func startSession() async {
        guard !session.isRunning else {
            print("📹 startSession called but session already running")
            return
        }

        print("📹 Starting camera session...")
        await MainActor.run {
            session.startRunning()
            print("📹 Camera session started: \(session.isRunning)")
        }
    }

    func switchCamera() async {
        await MainActor.run {
            isBackCamera.toggle()
            let position: AVCaptureDevice.Position = isBackCamera ? .back : .front

            // Create new device manager for the new position
            let newManager = CameraDeviceManager(position: position)

            // Get the wide angle camera for the new position
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                isBackCamera.toggle()  // Revert toggle
                return
            }

            session.beginConfiguration()

            if let currentInput = input {
                session.removeInput(currentInput)
            }

            if session.canAddInput(newInput) {
                session.addInput(newInput)
                device = newDevice
                input = newInput
                cameraDeviceManager = newManager
                // Reset zoom to 1x when switching cameras
                // Find the index of 1.0x in the new zoom factors array
                if let index = self.zoomFactors.firstIndex(of: 1.0) {
                    currentZoomIndex = index
                    setZoom(to: index)
                } else {
                    print("⚠️ Could not find 1.0x zoom level after camera switch: \(self.zoomFactors)")
                    currentZoomIndex = 0
                    setZoom(to: 0)
                }
            } else {
                isBackCamera.toggle()  // Revert toggle
            }

            session.commitConfiguration()
        }
    }

    /// Switch to a specific camera device and apply zoom
    private func switchToCamera(_ targetDevice: AVCaptureDevice, withZoom zoomFactor: CGFloat) async {
        await MainActor.run {
            session.beginConfiguration()

            // Remove current input
            if let currentInput = input {
                session.removeInput(currentInput)
            }

            // Create and add new input
            guard let newInput = try? AVCaptureDeviceInput(device: targetDevice) else {
                session.commitConfiguration()
                print("❌ Failed to create input for target device")
                return
            }

            if session.canAddInput(newInput) {
                session.addInput(newInput)
                device = targetDevice
                input = newInput

                // Apply zoom after switching
                do {
                    try targetDevice.lockForConfiguration()

                    // Clamp zoom to valid range for this camera
                    let clampedZoom = max(targetDevice.minAvailableVideoZoomFactor,
                                        min(targetDevice.maxAvailableVideoZoomFactor, zoomFactor))

                    targetDevice.videoZoomFactor = clampedZoom
                    targetDevice.unlockForConfiguration()

                    currentZoomFactor = clampedZoom
                    currentZoomText = String(format: "%.1fx", clampedZoom)
                    print("✅ Switched to \(targetDevice.deviceType) and applied zoom: \(currentZoomText)")
                } catch {
                    print("❌ Failed to apply zoom after camera switch: \(error)")
                    // Reset to original device on error
                    device = nil
                }
            } else {
                print("❌ Cannot add new input to session for device: \(targetDevice.deviceType)")
            }

            session.commitConfiguration()
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        output.capturePhoto(with: settings, delegate: self)
    }

    func captureTestPhoto() {
        // For UI testing, use the tablet image from TestAssets
        guard let testImage = UIImage(named: "tablet") else {
            print("❌ Could not load tablet test image")
            return
        }

        Task { @MainActor in
            // Crop to square aspect ratio
            let croppedImage = await cropToSquare(image: testImage)

            // Optimize image immediately for memory management
            let optimizedImage = await OptimizedImageManager.shared.optimizeImage(croppedImage)

            self.capturedImages.append(optimizedImage)
            print("📸 MultiPhotoCameraView - Captured test photo \(self.capturedImages.count)/5")
        }
    }

    func removeImage(at index: Int) {
        guard index >= 0 && index < capturedImages.count else { return }
        capturedImages.remove(at: index)
    }

    func setFocusPoint(_ point: CGPoint) {
        guard let device = device else {
            print("❌ No camera device available")
            return
        }

        do {
            try device.lockForConfiguration()

            print("🎯 Attempting to set focus to point: \(point)")
            print("📹 Focus supported: \(device.isFocusPointOfInterestSupported)")
            print("📹 Current focus mode: \(device.focusMode.rawValue)")
            print("📹 Current zoom: \(String(format: "%.1fx", device.videoZoomFactor))")

            // IMPORTANT: Save current zoom before making changes
            let previousZoom = device.videoZoomFactor

            // Set focus point and mode
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point

                // Use continuous autofocus for video preview
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                    print("✅ Set to continuous autofocus")
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                    print("✅ Set to autofocus")
                }
            } else {
                print("❌ Focus point of interest not supported")
            }

            // Set exposure point and mode
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point

                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                    print("✅ Set to continuous auto exposure")
                } else if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                    print("✅ Set to auto exposure")
                }
            }

            // IMPORTANT: Restore zoom factor after focus/exposure changes
            // Device configuration can reset zoom, so we need to reapply it
            device.videoZoomFactor = previousZoom
            print("✅ Restored zoom to \(String(format: "%.1fx", previousZoom))")

            device.unlockForConfiguration()
            print("✅ Focus configuration complete")
        } catch {
            print("❌ Error setting focus point: \(error)")
        }
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
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: image)
                    return
                }

                let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
                print("📐 CGImage size: \(originalSize) (UIImage size: \(image.size), orientation: \(image.imageOrientation.rawValue))")

                let sideLength = min(originalSize.width, originalSize.height)

                let x = (originalSize.width - sideLength) / 2
                let y = (originalSize.height - sideLength) / 2
                let cropRect = CGRect(x: x, y: y, width: sideLength, height: sideLength)

                print("📐 Crop rect: \(cropRect) from CGImage size: \(originalSize)")

                guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
                    print("❌ Failed to crop CGImage")
                    continuation.resume(returning: image)
                    return
                }

                print("📐 Cropped CGImage size: \(croppedCGImage.width)x\(croppedCGImage.height)")

                let croppedImage = UIImage(
                    cgImage: croppedCGImage,
                    scale: image.scale,
                    orientation: image.imageOrientation
                )

                print("📐 Final UIImage size: \(croppedImage.size)")
                continuation.resume(returning: croppedImage)
            }
        }
    }

    func handleCaptureModeChange(from oldMode: CaptureMode, to newMode: CaptureMode, isPro: Bool) -> Bool {
        guard !isHandlingModeChange else { return false }
        isHandlingModeChange = true
        defer { isHandlingModeChange = false }

        if newMode == .multiItem && !isPro {
            selectedCaptureMode = oldMode
            showingPaywall = true
            return false
        }

        if !capturedImages.isEmpty {
            pendingCaptureMode = newMode
            selectedCaptureMode = oldMode
            showingModeSwitchConfirmation = true
            return false
        }

        performModeSwitch(to: newMode)
        return true
    }

    func performModeSwitch(to newMode: CaptureMode) {
        capturedImages.removeAll()
        selectedCaptureMode = newMode
        pendingCaptureMode = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func confirmModeSwitch() {
        if let newMode = pendingCaptureMode {
            performModeSwitch(to: newMode)
        }
    }

    func cancelModeSwitch() {
        pendingCaptureMode = nil
    }

    func loadInitialCaptureMode(preferredCaptureMode: Int, isPro: Bool) {
        if preferredCaptureMode == 1 && isPro {
            selectedCaptureMode = .multiItem
        } else {
            selectedCaptureMode = .singleItem
        }
    }

    func saveCaptureMode(to settings: SettingsManager) {
        settings.preferredCaptureMode = selectedCaptureMode == .singleItem ? 0 : 1
    }

    func canCaptureMorePhotos(captureMode: CaptureMode, isPro: Bool) -> Bool {
        let maxPhotos = captureMode.maxPhotosAllowed(isPro: isPro)
        return capturedImages.count < maxPhotos
    }

    func shouldShowMultiItemPreview(captureMode: CaptureMode) -> Bool {
        return captureMode == .multiItem && !capturedImages.isEmpty
    }
}
