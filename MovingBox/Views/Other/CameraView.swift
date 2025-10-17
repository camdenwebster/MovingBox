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
    @State private var isProcessingCapture = false
    
    var onPhotoCapture: ((UIImage, Bool, @escaping () async -> Void) async -> Void)?
    
    private var isMockCamera: Bool {
        ProcessInfo.processInfo.arguments.contains("UI-Testing-Mock-Camera")
    }
    
    var body: some View {
        Group {
            if isMockCamera {
                MockCameraView(image: $capturedImage)
                    .onChange(of: capturedImage) { _, newImage in
                        handleCapturedImage(newImage)
                    }
            } else {
                CustomCameraView(capturedImage: $capturedImage) { authorized in
                    if !authorized {
                        showingPermissionDenied = true
                    }
                }
                .onChange(of: capturedImage) { _, newImage in
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
        .disabled(isProcessingCapture)
        .onDisappear {
            if !isProcessingCapture {
                capturedImage = nil
            }
        }
    }
    
    private func handleCapturedImage(_ newImage: UIImage?) {
        Task {
            if let image = newImage {
                isProcessingCapture = true
                analyzingImage = image
                showingImageAnalysis = true
                
                await onPhotoCapture?(image, true) {
                    Task { @MainActor in
                        showingImageAnalysis = false
                        analyzingImage = nil
                        isProcessingCapture = false
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
            }
            .accessibilityIdentifier("takePhotoButton")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(UIConstants.cornerRadius)
            .padding(.bottom, 30)
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
