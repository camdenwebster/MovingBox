import SwiftUI
import UIKit
import AVFoundation

struct SimpleCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var capturedImage: UIImage?
    @State private var showingPermissionDenied = false
    
    private var isMockCamera: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-Testing-Mock-Camera")
    }
    
    var body: some View {
        if isMockCamera {
            MockSimpleCameraView(image: $capturedImage)
                .onChange(of: capturedImage) { _, newImage in
                    if newImage != nil {
                        dismiss()
                    }
                }
        } else {
            ZStack {
                // Check permissions first
                Color.clear
                    .onAppear {
                        checkCameraPermission()
                    }
                
                // Show camera if permissions are granted
                if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                    NativeCameraView(capturedImage: $capturedImage) {
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
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Camera already authorized, NativeCameraView will show
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        showingPermissionDenied = true
                    }
                    // If granted, the view will update automatically
                }
            }
        case .denied, .restricted:
            showingPermissionDenied = true
        @unknown default:
            showingPermissionDenied = true
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Native Camera View

struct NativeCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: NativeCameraView
        
        init(_ parent: NativeCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
                // Give SwiftUI time to process the binding change before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.parent.onDismiss()
                }
            } else {
                parent.onDismiss()
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
        }
    }
}

// MARK: - Mock Camera View

struct MockSimpleCameraView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Spacer()
            Image("tablet")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .padding()
            
            Button("Take Photo") {
                image = UIImage(named: "tablet")
            }
            .accessibilityIdentifier("cameraShutterButton")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.bottom, 30)
        }
    }
}
