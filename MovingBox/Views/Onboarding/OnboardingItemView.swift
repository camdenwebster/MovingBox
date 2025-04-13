import SwiftUI
import SwiftData

struct OnboardingItemView: View {
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.modelContext) var modelContext
    @Query private var locations: [InventoryLocation]
    
    @State private var showPrivacyAlert = false
    @State private var showCamera = false
    @State private var showItemFlow = false
    @State private var selectedItem: InventoryItem?
    @State private var capturedImage: UIImage?
    @State private var isProcessingImage = false
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                                .padding()
                                .symbolEffect(.bounce.up.byLayer, options: .nonRepeating)
                            
                            OnboardingHeaderText(text: "Add Your First Item")
                            
                            VStack(spacing: 16) {
                                OnboardingDescriptionText(text: "MovingBox uses artificial intelligence to automatically identify and catalog your items.")
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    OnboardingFeatureRow(
                                        icon: "checkmark.shield",
                                        iconColor: .green,
                                        title: "Instant Analysis",
                                        description: "Your photos are analyzed instantly"
                                    )
                                    
                                    OnboardingFeatureRow(
                                        icon: "xmark.shield",
                                        iconColor: .red,
                                        title: "Privacy First",
                                        description: "We do not store your photos"
                                    )
                                    
                                    OnboardingFeatureRow(
                                        icon: "exclamationmark.triangle",
                                        iconColor: .orange,
                                        title: "AI Processing",
                                        description: "OpenAI will process your photos"
                                    )
                                }
                                .padding(20)
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                }
                                
                                Button("Read OpenAI's Privacy Policy") {
                                    if let url = URL(string: "https://openai.com/policies/privacy-policy") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                            .frame(height: 100)
                    }
                }
                
                VStack {
                    OnboardingContinueButton(action: {
                        showPrivacyAlert = true
                    }, title: "Take a Photo")
                    .accessibilityIdentifier("onboarding-item-take-photo-button")
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onboardingBackground()
        // Camera sheet
        .sheet(isPresented: $showCamera) {
            NavigationStack {
                CameraView(
                    showingImageAnalysis: .constant(false),
                    analyzingImage: .constant(nil)
                ) { image, needsAnalysis, completion async -> Void in
                    isProcessingImage = true
                    defer { isProcessingImage = false }
                    
                    do {
                        // Create the item first
                        let newItem = createNewItem()
                        selectedItem = newItem
                        
                        // Save the image
                        let id = UUID().uuidString
                        if let imageURL = try? await OptimizedImageManager.shared.saveImage(image, id: id) {
                            newItem.imageURL = imageURL
                            try? modelContext.save()
                            
                            // Update UI state
                            await MainActor.run {
                                capturedImage = image
                                showCamera = false
                                
                                // Complete the camera operation
                                Task {
                                    await completion()
                                    // Show the analysis view after everything is ready
                                    showItemFlow = true
                                }
                            }
                        }
                    } catch {
                        print("Error processing image: \(error)")
                        await completion()
                    }
                }
            }
            .interactiveDismissDisabled(isProcessingImage)
        }
        // Analysis and Detail sheet
        .sheet(isPresented: $showItemFlow) {
            Group {
                if let image = capturedImage {
                    ItemAnalysisDetailView(
                        item: selectedItem,
                        image: image,
                        onSave: {
                            showItemFlow = false
                            manager.moveToNext()
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "Image Not Available",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Unable to process the captured image.")
                    )
                }
            }
            .onChange(of: showItemFlow) { _, isPresented in
                if isPresented {
                    print("ItemAnalysisDetailView presented with image: \(String(describing: capturedImage != nil))")
                }
            }
        }
        .alert("Privacy Notice", isPresented: $showPrivacyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                showCamera = true
            }
        } message: {
            Text("Photos you take will be processed by OpenAI's vision API. Please ensure no sensitive information is visible in your photos.")
        }
    }
    
    private func createNewItem() -> InventoryItem {
        let newItem = InventoryItem(
            title: "",
            quantityString: "1",
            quantityInt: 1,
            desc: "",
            serial: "",
            model: "",
            make: "",
            location: locations.first,
            label: nil,
            price: Decimal.zero,
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false
        )
        modelContext.insert(newItem)
        try? modelContext.save()
        return newItem
    }
}

// New view to handle analysis and detail flow
struct ItemAnalysisDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    let item: InventoryItem?
    let image: UIImage
    let onSave: () -> Void
    
    @State private var showingImageAnalysis = true
    @State private var navigationPath = NavigationPath()
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                if showingImageAnalysis {
                    ImageAnalysisView(image: image) {
                        Task {
                            await analyzeImage()
                            showingImageAnalysis = false
                            navigationPath.append("detail")
                        }
                    }
                    .environment(\.isOnboarding, true)
                } else {
                    // Placeholder view while transitioning
                    Color.clear
                }
            }
            .navigationDestination(for: String.self) { route in
                if route == "detail", let currentItem = item {
                    InventoryDetailView(
                        inventoryItemToDisplay: currentItem,
                        navigationPath: $navigationPath,
                        isEditing: true,
                        onSave: onSave
                    )
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func analyzeImage() async {
        guard let base64ForAI = OptimizedImageManager.shared.prepareImageForAI(from: image),
              let _ = item else {
            await MainActor.run {
                errorMessage = "Unable to process the image"
                showError = true
            }
            return
        }
        
        let openAi = OpenAIService(
            imageBase64: base64ForAI,
            settings: settings,
            modelContext: modelContext
        )
        
        do {
            let imageDetails = try await openAi.getImageDetails()
            await MainActor.run {
                updateUIWithImageDetails(imageDetails)
                TelemetryManager.shared.trackCameraAnalysisUsed()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error analyzing image: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func updateUIWithImageDetails(_ imageDetails: ImageDetails) {
        guard let item = item else { return }
        
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        guard let labels: [InventoryLabel] = try? modelContext.fetch(labelDescriptor) else { return }
        
        item.title = imageDetails.title
        item.quantityString = imageDetails.quantity
        item.label = labels.first { $0.name == imageDetails.category }
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        item.hasUsedAI = true
        
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        item.price = Decimal(string: priceString) ?? 0
        
        try? modelContext.save()
    }
}

#Preview {
    OnboardingItemView()
        .environmentObject(OnboardingManager())
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
