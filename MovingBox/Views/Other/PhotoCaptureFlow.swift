import SwiftUI

enum PhotoCaptureStep {
    case camera
    case review(UIImage)
}

struct PhotoCaptureFlow: View {
    @Environment(\.dismiss) private var dismiss
    let onPhotoSelected: (UIImage) -> Void
    @State private var currentStep: PhotoCaptureStep = .camera
    
    var body: some View {
        Group {
            switch currentStep {
            case .camera:
                CameraView { image, _, completion in
                    print("[DEBUG] PhotoCaptureFlow - Camera captured image")
                    withAnimation {
                        currentStep = .review(image)
                    }
                    completion()
                }
                .onboardingCamera()
                
            case .review(let image):
                PhotoReviewView(
                    image: image,
                    onAccept: { image, _, completion in
                        print("[DEBUG] PhotoCaptureFlow - Photo accepted")
                        onPhotoSelected(image)
                        completion()
                        dismiss()
                    },
                    onRetake: {
                        print("[DEBUG] PhotoCaptureFlow - Retaking photo")
                        withAnimation {
                            currentStep = .camera
                        }
                    },
                    isOnboarding: true
                )
            }
        }
    }
}