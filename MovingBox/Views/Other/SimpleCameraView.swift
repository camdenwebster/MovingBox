import SwiftUI
import UIKit
import AVFoundation

struct SimpleCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var capturedImages: [UIImage]
    let onDone: () -> Void

    @State private var showingPermissionDenied = false

    private var isMockCamera: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-Testing-Mock-Camera")
    }

    var body: some View {
        Group {
            if isMockCamera {
                MockSimpleCameraView(capturedImages: $capturedImages, onDone: onDone)
            } else {
                ImagePicker(image: Binding(
                    get: { nil }, 
                    set: { newImage in
                        if let newImage {
                            capturedImages.append(newImage)
                        }
                    }
                ), sourceType: .camera) { authorized in
                    if !authorized {
                        showingPermissionDenied = true
                    }
                }
                .onChange(of: capturedImages) { oldValue, newValue in
                }
                .alert("Camera Access Required", isPresented: $showingPermissionDenied) {
                    Button("Go to Settings", action: openSettings)
                    Button("Cancel", role: .cancel) { dismiss() }
                } message: {
                    Text("Please grant camera access in Settings to use this feature.")
                }
                VStack {
                    Spacer()
                    Button("Done") {
                        onDone()
                    }
                    .padding()
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
    @Binding var capturedImages: [UIImage]
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Spacer()
            Image("tablet")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .padding()

            HStack {
                Button("Take Photo") {
                    if let mockImage = UIImage(named: "tablet") {
                        capturedImages.append(mockImage)
                        print("Mock Camera: Captured \(capturedImages.count) images")
                    }
                }
                .accessibilityIdentifier("takePhotoButton")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                Button("Done") {
                    print("Mock Camera: Done capturing")
                    onDone()
                }
                .accessibilityIdentifier("doneButton")
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.bottom, 30)
        }
    }
}
