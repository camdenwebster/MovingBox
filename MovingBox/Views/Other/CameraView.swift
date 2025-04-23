import SwiftUI
import UIKit
import AVFoundation

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    @Binding var showingImageAnalysis: Bool
    @Binding var analyzingImage: UIImage?
    @State private var capturedImage: UIImage?
    @State private var showingPermissionDenied = false
    
    var onPhotoCapture: ((UIImage, Bool, @escaping () async -> Void) async -> Void)?
    
    private var isMockCamera: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-Testing-Mock-Camera")
    }
    
    var body: some View {
        Group {
            if isMockCamera {
                MockCameraView(image: $capturedImage)
                    .onChange(of: capturedImage) { oldImage, newImage in
                        handleCapturedImage(newImage)
                    }
            } else {
                ImagePicker(image: $capturedImage, sourceType: .camera) { authorized in
                    if !authorized {
                        showingPermissionDenied = true
                    }
                }
                .onChange(of: capturedImage) { oldImage, newImage in
                    handleCapturedImage(newImage)
                }
                .alert("Camera Access Required", isPresented: $showingPermissionDenied) {
                    Button("Go to Settings", action: openSettings)
                    Button("Cancel", role: .cancel) { dismiss() }
                } message: {
                    Text("Please grant camera access in Settings to use this feature.")
                }
            }
        }
        .onDisappear {
            capturedImage = nil
        }
    }
    
    private func handleCapturedImage(_ newImage: UIImage?) {
        Task {
            if let image = newImage {
                analyzingImage = image
                showingImageAnalysis = true
                
                await onPhotoCapture?(image, true) {
                    Task { @MainActor in
                        showingImageAnalysis = false
                        analyzingImage = nil
                    }
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

struct MockCameraView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var onboardingManager: OnboardingManager
    
    var imageName: String {
        switch onboardingManager.currentStep {
        case .homeDetails: return "craftsman-home"
        case .location: return "kitchen"
        default: return "tablet"
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .padding()
            
            Button("Take Photo") {
                image = UIImage(named: imageName)
                dismiss()
            }
            .accessibilityIdentifier("takePhotoButton")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.bottom, 30)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    let onPermissionCheck: (Bool) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        checkPermissions()
        
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func checkPermissions() {
        if sourceType == .camera {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                onPermissionCheck(true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        onPermissionCheck(granted)
                    }
                }
            default:
                onPermissionCheck(false)
            }
        } else {
            onPermissionCheck(true)
        }
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct OnboardingCameraModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.environment(\.isOnboarding, true)
    }
}

extension View {
    func onboardingCamera() -> some View {
        self.modifier(OnboardingCameraModifier())
    }
}
