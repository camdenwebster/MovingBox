import SwiftUI
import SwiftData
import AVFoundation
import StoreKit

enum ItemCreationStep: CaseIterable {
    case camera
    case analyzing
    case multiItemSelection
    case details
    
    var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .analyzing: return "Analyzing"
        case .multiItemSelection: return "Select Items"
        case .details: return "Details"
        }
    }
    
    static func getNavigationFlow(for captureMode: CaptureMode) -> [ItemCreationStep] {
        switch captureMode {
        case .singleItem:
            return [.camera, .analyzing, .details]
        case .multiItem:
            return [.camera, .analyzing, .multiItemSelection, .details]
        }
    }
}

struct ItemCreationFlowView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    
    @State private var currentStep: ItemCreationStep = .camera
    @State private var capturedImage: UIImage?
    @State private var capturedImages: [UIImage] = []
    @State private var captureMode: CaptureMode = .singleItem
    @State private var item: InventoryItem?
    @State private var showingPermissionDenied = false
    @State private var processingImage = false
    @State private var analysisComplete = false
    @State private var errorMessage: String?
    @State private var transitionId = UUID()

    // Animation properties
    private let transitionAnimation = Animation.easeInOut(duration: 0.3)

    let location: InventoryLocation?
    let onComplete: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch currentStep {
                case .camera:
                    MultiPhotoCameraView(
                        capturedImages: $capturedImages,
                        onPermissionCheck: { granted in
                            if !granted {
                                showingPermissionDenied = true
                            }
                        },
                        onComplete: { images, selectedMode in
                            // Set processing flag to prevent premature dismissal
                            processingImage = true

                            Task {
                                // Update capture mode based on user selection in camera
                                await updateCaptureMode(selectedMode)
                                // Process the images
                                await handleCapturedImages(images)

                                // Transition to next step
                                // For single-item mode: check if item was created
                                // For multi-item mode: always proceed to analyzing
                                if selectedMode == .multiItem || self.item != nil {
                                    await MainActor.run {
                                        withAnimation(transitionAnimation) {
                                            transitionId = UUID()
                                            currentStep = .analyzing
                                        }
                                    }
                                } else {
                                    await MainActor.run {
                                        processingImage = false
                                        dismiss()
                                    }
                                }
                            }
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .move(edge: .leading)
                    ))
                    .id("camera-\(transitionId)")
                    
                case .analyzing:
                    if !capturedImages.isEmpty, let item = item {
                        ZStack {
                            ImageAnalysisView(images: capturedImages) {
                                // The ImageAnalysisView will signal when minimum display time has elapsed
                                // but we only move to details if analysis is actually complete
                                if analysisComplete {
                                    print("Analysis view completed and analysis is done")
                                    withAnimation(transitionAnimation) {
                                        transitionId = UUID()
                                        currentStep = .details
                                    }
                                } else if errorMessage != nil {
                                    print("Analysis view completed with error")
                                    withAnimation(transitionAnimation) {
                                        transitionId = UUID()
                                        currentStep = .details
                                    }
                                }
                                // Otherwise, we keep waiting for analysis to complete
                            }
                        }
                        .task {
                            // Only start analysis if we haven't completed it yet
                            if !analysisComplete && errorMessage == nil {
                                await performMultiImageAnalysis(item: item, images: capturedImages)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                        .id("analysis-\(transitionId)")
                    }
                    
                case .multiItemSelection:
                    // This view doesn't support multi-item selection, fall back to details
                    Text("Multi-item selection not supported in this view")
                        .onAppear {
                            currentStep = .details
                        }
                    
                case .details:
                    if let item = item {
                        InventoryDetailView(
                            inventoryItemToDisplay: item,
                            navigationPath: .constant(NavigationPath()),
                            isEditing: true,
                            onSave: {
                                onComplete?()
                                dismiss()
                            },
                            onCancel: {
                                dismiss()
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .opacity
                        ))
                        .id("details-\(transitionId)")
                    } else {
                        Text("Loading item details...")
                            .onAppear {
                                // Fallback in case the item isn't ready
                                if item == nil {
                                    dismiss()
                                }
                            }
                    }
                }
            }
            .animation(transitionAnimation, value: currentStep)
            .interactiveDismissDisabled(currentStep != .camera || processingImage)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: analysisComplete) { _, newValue in
            if newValue && currentStep == .analyzing {
                print("Analysis complete changed to true")
                // Transition after a slight delay for smoother UX
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(transitionAnimation) {
                        transitionId = UUID()
                        currentStep = .details
                    }
                }
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil && currentStep == .analyzing {
                print("Error message set, moving to details")
                // Transition after a slight delay for smoother UX
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(transitionAnimation) {
                        transitionId = UUID()
                        currentStep = .details
                    }
                }
            }
        }
        .alert("Camera Access Required", isPresented: $showingPermissionDenied) {
            Button("Go to Settings", action: openSettings)
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("Please grant camera access in Settings to use this feature.")
        }
        .alert(errorMessage ?? "Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Continue Anyway", role: .none) {
                withAnimation(transitionAnimation) {
                    currentStep = .details
                }
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred during image analysis.")
        }
    }

    private func updateCaptureMode(_ mode: CaptureMode) async {
        await MainActor.run {
            print("🔄 ItemCreationFlowView - Updating capture mode from \(captureMode) to \(mode)")
            captureMode = mode
            print("✅ ItemCreationFlowView - Capture mode updated. Current mode: \(captureMode)")
        }
    }

    private func handleCapturedImages(_ images: [UIImage]) async {
        await MainActor.run {
            capturedImages = images
            capturedImage = images.first // For backward compatibility
        }

        print("📸 ItemCreationFlowView - handleCapturedImages called. Capture mode: \(captureMode)")

        // Only run single-item creation if in single-item mode
        guard captureMode == .singleItem else {
            print("⏭️ ItemCreationFlowView - Skipping single-item creation (in multi-item mode)")
            return
        }

        print("➡️ ItemCreationFlowView - Running single item creation flow")

        // Create the item first
        let newItem = InventoryItem(
            title: "",
            quantityString: "1",
            quantityInt: 1,
            desc: "",
            serial: "",
            model: "",
            make: "",
            location: location,
            label: nil,
            price: Decimal.zero,
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false
        )
        
        // Generate a unique ID for this item
        let itemId = UUID().uuidString
        
        do {
            if let primaryImage = images.first {
                // Save the primary image
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(primaryImage, id: itemId)
                newItem.imageURL = primaryImageURL
                
                // Save secondary images if there are more than one
                if images.count > 1 {
                    let secondaryImages = Array(images.dropFirst())
                    let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(secondaryImages, itemId: itemId)
                    newItem.secondaryPhotoURLs = secondaryURLs
                }
            }
            
            await MainActor.run {
                modelContext.insert(newItem)
                try? modelContext.save()
                TelemetryManager.shared.trackInventoryItemAdded(name: newItem.title)
                self.item = newItem
            }
        } catch {
            print("Error processing images: \(error)")
        }
    }
    
    // Legacy method for backward compatibility (keep for now)
    private func handleCapturedImage(_ image: UIImage) async {
        await handleCapturedImages([image])
    }
    
    private func performImageAnalysis(item: InventoryItem, image: UIImage) async {
        print("Starting image analysis...")
        
        // Reset flags to ensure proper state
        await MainActor.run {
            analysisComplete = false
            errorMessage = nil
        }
        
        do {
            // Prepare image for AI
            guard await OptimizedImageManager.shared.prepareImageForAI(from: image) != nil else {
                throw OpenAIError.invalidData
            }
            
            // Create OpenAI service and get image details
            let openAi = OpenAIServiceFactory.create()
            TelemetryManager.shared.trackCameraAnalysisUsed()
            
            print("Calling OpenAI for image analysis...")
            let imageDetails = try await openAi.getImageDetails(
                from: [capturedImage].compactMap { $0 },
                settings: settings,
                modelContext: modelContext
            )
            print("OpenAI analysis complete, updating item...")
            
            // Update the item with the results
            await MainActor.run {
                // Get all labels and locations for the unified update
                let labels = (try? modelContext.fetch(FetchDescriptor<InventoryLabel>())) ?? []
                let locations = (try? modelContext.fetch(FetchDescriptor<InventoryLocation>())) ?? []
                
                item.updateFromImageDetails(imageDetails, labels: labels, locations: locations)
                try? modelContext.save()
                
                // Set processing flag to false
                processingImage = false
                
                // Set analysis complete flag to trigger UI update
                analysisComplete = true
                print("Analysis complete, item updated")
            }
        } catch let openAIError as OpenAIError {
            await MainActor.run {
                switch openAIError {
                case .invalidURL:
                    errorMessage = "Invalid URL configuration"
                case .invalidResponse:
                    errorMessage = "Error communicating with AI service"
                case .invalidData:
                    errorMessage = "Unable to process AI response"
                case .rateLimitExceeded:
                    errorMessage = "Rate limit exceeded, please try again later"
                case .serverError(_):
                    errorMessage = "Server error: \(openAIError.localizedDescription)"
                case .networkCancelled:
                    errorMessage = "Request was cancelled. Please try again."
                case .networkTimeout:
                    errorMessage = "Request timed out. Please check your connection and try again."
                case .networkUnavailable:
                    errorMessage = "Network unavailable. Please check your internet connection."
                @unknown default:
                    errorMessage = "Unknown AI service error"
                }
                processingImage = false
                print("Analysis error: \(errorMessage ?? "unknown")")
            }
        } catch {
            await MainActor.run {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                processingImage = false
                print("Analysis exception: \(error)")
            }
        }
    }
    
    private func performMultiImageAnalysis(item: InventoryItem, images: [UIImage]) async {
        print("Starting multi-image analysis with \(images.count) images...")
        
        // Reset flags to ensure proper state
        await MainActor.run {
            analysisComplete = false
            errorMessage = nil
        }
        
        do {
            // Prepare all images for AI
            let imageBase64Array = await OptimizedImageManager.shared.prepareMultipleImagesForAI(from: images)
            
            guard !imageBase64Array.isEmpty else {
                throw OpenAIError.invalidData
            }
            
            // Create OpenAI service with multiple images and get image details
            let openAi = OpenAIServiceFactory.create()
            TelemetryManager.shared.trackCameraAnalysisUsed()
            
            print("Calling OpenAI for multi-image analysis...")
            let imageDetails = try await openAi.getImageDetails(
                from: capturedImages,
                settings: settings,
                modelContext: modelContext
            )
            print("OpenAI multi-image analysis complete, updating item...")
            
            // Update the item with the results
            await MainActor.run {
                // Get all labels and locations for the unified update
                let labels = (try? modelContext.fetch(FetchDescriptor<InventoryLabel>())) ?? []
                let locations = (try? modelContext.fetch(FetchDescriptor<InventoryLocation>())) ?? []

                item.updateFromImageDetails(imageDetails, labels: labels, locations: locations)
                try? modelContext.save()

                // Increment successful AI analysis count and check for review request
                settings.incrementSuccessfulAIAnalysis()
                if settings.shouldRequestReview() {
                    requestAppReview()
                }

                // Set processing flag to false
                processingImage = false

                // Set analysis complete flag to trigger UI update
                analysisComplete = true
                print("Multi-image analysis complete, item updated")
            }
        } catch let openAIError as OpenAIError {
            await MainActor.run {
                switch openAIError {
                case .invalidURL:
                    errorMessage = "Invalid URL configuration"
                case .invalidResponse:
                    errorMessage = "Error communicating with AI service"
                case .invalidData:
                    errorMessage = "Unable to process AI response"
                case .rateLimitExceeded:
                    errorMessage = "Rate limit exceeded, please try again later"
                case .serverError(_):
                    errorMessage = "Server error: \(openAIError.localizedDescription)"
                case .networkCancelled:
                    errorMessage = "Request was cancelled. Please try again."
                case .networkTimeout:
                    errorMessage = "Request timed out. Please check your connection and try again."
                case .networkUnavailable:
                    errorMessage = "Network unavailable. Please check your internet connection."
                @unknown default:
                    errorMessage = "Unknown AI service error"
                }
                processingImage = false
                print("Multi-image analysis error: \(errorMessage ?? "unknown")")
            }
        } catch {
            await MainActor.run {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                processingImage = false
                print("Multi-image analysis exception: \(error)")
            }
        }
    }
    
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func requestAppReview() {
        // Delay review request by 2 seconds to let user glance at results
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            TelemetryManager.shared.trackAppReviewRequested()
            if #available(iOS 18.0, *) {
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    AppStore.requestReview(in: scene)
                    print("📱 Requested app review using AppStore API")
                }
            } else {
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                    print("📱 Requested app review using legacy API")
                }
            }
        }
    }
}

#Preview {
    ItemCreationFlowView(location: nil, onComplete: nil)
        .modelContainer(try! ModelContainer(for: InventoryLocation.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
