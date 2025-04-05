import SwiftUI

enum OnboardingCameraStep {
    case camera
    case review(UIImage)
    case details(InventoryItem)
}

struct OnboardingCameraFlow: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @State private var currentStep: OnboardingCameraStep = .camera
    
    var body: some View {
        Group {
            switch currentStep {
            case .camera:
                CameraView { image, _, completion in
                    completion()
                    withAnimation {
                        currentStep = .review(image)
                    }
                }
                .onboardingCamera()
                
            case .review(let image):
                PhotoReviewView(
                    image: image,
                    onAccept: { image, needsAnalysis, completion in
                        let newItem = InventoryItem(
                            title: "",
                            quantityString: "1",
                            quantityInt: 1,
                            desc: "",
                            serial: "",
                            model: "",
                            make: "",
                            location: nil,
                            label: nil,
                            price: Decimal.zero,
                            insured: false,
                            assetId: "",
                            notes: "",
                            showInvalidQuantityAlert: false
                        )
                        
                        if let originalData = image.jpegData(compressionQuality: 1.0) {
                            newItem.data = originalData
                            completion()
                            withAnimation {
                                currentStep = .details(newItem)
                            }
                        }
                    },
                    onRetake: {
                        withAnimation {
                            currentStep = .camera
                        }
                    },
                    isOnboarding: true
                )
                
            case .details(let item):
                InventoryDetailView(
                    inventoryItemToDisplay: item,
                    navigationPath: .constant(NavigationPath()),
                    isEditing: true
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .interactiveDismissDisabled()
                .onDisappear {
                    onboardingManager.moveToNext()
                }
            }
        }
    }
}