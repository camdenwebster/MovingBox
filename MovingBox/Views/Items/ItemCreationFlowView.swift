import SwiftUI
import SwiftData
import AVFoundation

enum ItemCreationStep {
    case camera
    case analyzing
    case details
}

struct ItemCreationFlowView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    
    @State private var currentStep: ItemCreationStep = .camera
    @State private var capturedImage: UIImage?
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
                    CameraView(
                        showingImageAnalysis: .constant(false),
                        analyzingImage: .constant(nil)
                    ) { image, needsAnalysis, completion async -> Void in
                        // Set processing flag to prevent premature dismissal
                        processingImage = true
                        
                        // Process the image
                        await handleCapturedImage(image)
                        
                        // Complete the camera operation but stay in the sheet
                        await completion()
                        
                        // Transition to next step
                        if self.item != nil {
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
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .move(edge: .leading)
                    ))
                    .id("camera-\(transitionId)")
                    
                case .analyzing:
                    if let image = capturedImage, let item = item {
                        ZStack {
                            ImageAnalysisView(image: image) {
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
                                await performImageAnalysis(item: item, image: image)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                        .id("analysis-\(transitionId)")
                    }
                    
                case .details:
                    if let item = item {
                        InventoryDetailView(
                            inventoryItemToDisplay: item,
                            navigationPath: .constant(NavigationPath()),
                            isEditing: true
                        ) {
                            onComplete?()
                            dismiss()
                        }
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
    
    private func handleCapturedImage(_ image: UIImage) async {
        await MainActor.run {
            capturedImage = image
        }
        
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
        
        // Save the image
        let id = UUID().uuidString
        
        do {
            let imageURL = try await OptimizedImageManager.shared.saveImage(image, id: id)
            
            await MainActor.run {
                newItem.imageURL = imageURL
                modelContext.insert(newItem)
                try? modelContext.save()
                TelemetryManager.shared.trackInventoryItemAdded(name: newItem.title)
                self.item = newItem
            }
        } catch {
            print("Error processing image: \(error)")
        }
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
            guard let imageBase64 = OptimizedImageManager.shared.prepareImageForAI(from: image) else {
                throw OpenAIError.invalidData
            }
            
            // Create OpenAI service and get image details
            let openAi = OpenAIService(imageBase64: imageBase64, settings: settings, modelContext: modelContext)
            TelemetryManager.shared.trackCameraAnalysisUsed()
            
            print("Calling OpenAI for image analysis...")
            let imageDetails = try await openAi.getImageDetails()
            print("OpenAI analysis complete, updating item...")
            
            // Update the item with the results
            await MainActor.run {
                updateItemWithImageDetails(item: item, imageDetails: imageDetails)
                item.hasUsedAI = true // Mark as analyzed by AI
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
    
    private func updateItemWithImageDetails(item: InventoryItem, imageDetails: ImageDetails) {
        // Get all labels for category matching
        let labels = try? modelContext.fetch(FetchDescriptor<InventoryLabel>())
        
        // Get all locations for location matching
        let locations = try? modelContext.fetch(FetchDescriptor<InventoryLocation>())
        
        item.title = imageDetails.title
        item.quantityString = imageDetails.quantity
        item.label = labels?.first { $0.name == imageDetails.category }
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        
        if item.location == nil {
            item.location = locations?.first { $0.name == imageDetails.location }
        }
        
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        if let price = Decimal(string: priceString) {
            item.price = price
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ItemCreationFlowView(location: nil, onComplete: nil)
        .modelContainer(try! ModelContainer(for: InventoryLocation.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
