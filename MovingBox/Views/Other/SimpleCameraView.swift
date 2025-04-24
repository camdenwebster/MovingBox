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
        Group {
            if isMockCamera {
                MockSimpleCameraView(image: $capturedImage)
                    .onChange(of: capturedImage) { _, newImage in
                        if newImage != nil {
                            dismiss()
                        }
                    }
            } else {
                ImagePicker(image: $capturedImage, sourceType: .camera) { authorized in
                    if !authorized {
                        showingPermissionDenied = true
                    }
                }
                .onChange(of: capturedImage) { _, newImage in
                    if newImage != nil {
                        dismiss()
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
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

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
            .accessibilityIdentifier("takePhotoButton")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.bottom, 30)
        }
    }
}
