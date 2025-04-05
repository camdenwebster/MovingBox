import SwiftUI

enum OnboardingCameraStep {
    case camera
    case review(UIImage)
    case details(InventoryItem)
}

struct OnboardingCameraFlow: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep: OnboardingCameraStep = .camera
    
    var body: some View {
        Group {
            switch currentStep {
            case .camera:
                CameraView { image, _, completion in
                    print("[DEBUG] OnboardingCameraFlow - Camera captured image")
                    withAnimation {
                        currentStep = .review(image)
                    }
                    completion()
                }
                .onboardingCamera()
                
            case .review(let image):
                PhotoReviewView(
                    image: image,
                    onAccept: { image, needsAnalysis, completion in
                        print("[DEBUG] OnboardingCameraFlow - Photo accepted")
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
                            modelContext.insert(newItem)
                            try? modelContext.save()
                            
                            Task {
                                guard let base64ForAI = PhotoManager.loadCompressedPhotoForAI(from: image) else {
                                    print("[DEBUG] OnboardingCameraFlow - Failed to compress image for AI")
                                    completion()
                                    await MainActor.run {
                                        withAnimation {
                                            currentStep = .details(newItem)
                                        }
                                    }
                                    return
                                }
                                
                                let openAi = OpenAIService(
                                    imageBase64: base64ForAI,
                                    settings: settings,
                                    modelContext: modelContext
                                )
                                
                                do {
                                    print("[DEBUG] OnboardingCameraFlow - Starting AI analysis")
                                    let imageDetails = try await openAi.getImageDetails()
                                    await MainActor.run {
                                        print("[DEBUG] OnboardingCameraFlow - AI analysis complete")
                                        newItem.title = imageDetails.title
                                        newItem.quantityString = imageDetails.quantity
                                        newItem.desc = imageDetails.description
                                        newItem.make = imageDetails.make
                                        newItem.model = imageDetails.model
                                        newItem.hasUsedAI = true
                                        
                                        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
                                        newItem.price = Decimal(string: priceString) ?? 0
                                        
                                        try? modelContext.save()
                                        
                                        completion()
                                        withAnimation {
                                            currentStep = .details(newItem)
                                        }
                                    }
                                } catch {
                                    print("[DEBUG] OnboardingCameraFlow - AI analysis failed: \(error)")
                                    completion()
                                    await MainActor.run {
                                        withAnimation {
                                            currentStep = .details(newItem)
                                        }
                                    }
                                }
                            }
                        }
                    },
                    onRetake: {
                        print("[DEBUG] OnboardingCameraFlow - Retaking photo")
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
                    print("[DEBUG] OnboardingCameraFlow - InventoryDetailView disappeared")
                    onboardingManager.moveToNext()
                }
            }
        }
    }
}
