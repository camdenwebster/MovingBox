import SwiftUI
import SwiftData

struct OnboardingItemView: View {
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.modelContext) var modelContext
    @Query private var locations: [InventoryLocation]
    @State private var showCameraFlow = false
    @State private var showPrivacyAlert = false
    @State private var showingImageAnalysis = false
    @State private var analyzingImage: UIImage?
    @State private var selectedItem: InventoryItem?
    @State private var showingDetail = false

    var body: some View {
        OnboardingContainer {
            ZStack {
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
                
                if showingImageAnalysis, let image = analyzingImage {
                    Color(.systemBackground)
                        .edgesIgnoringSafeArea(.all)
                    ImageAnalysisView(image: image) {
                        showingImageAnalysis = false
                        analyzingImage = nil
                    }
                    .environment(\.isOnboarding, true)
                    .transition(.opacity)
                }
            }
            .animation(.default, value: showingImageAnalysis)
        }
        .onboardingBackground()
        .sheet(isPresented: $showCameraFlow) {
            NavigationStack {
                CameraView(
                    showingImageAnalysis: $showingImageAnalysis,
                    analyzingImage: $analyzingImage
                ) { image, needsAnalysis, completion async -> Void in
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
                    
                    if let originalData = image.jpegData(compressionQuality: 1.0) {
                        let id = UUID().uuidString
                        if let imageURL = try? await OptimizedImageManager.shared.saveImage(image, id: id) {
                            newItem.imageURL = imageURL
                            modelContext.insert(newItem)
                            try? modelContext.save()
                            
                            if needsAnalysis {
                                guard let base64ForAI = OptimizedImageManager.shared.prepareImageForAI(from: image) else {
                                    await completion()
                                    selectedItem = newItem
                                    showCameraFlow = false
                                    showingDetail = true
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
                                        updateUIWithImageDetails(imageDetails, for: newItem)
                                        TelemetryManager.shared.trackCameraAnalysisUsed()
                                        Task {
                                            await completion()
                                        }
                                        selectedItem = newItem
                                        showCameraFlow = false
                                        showingDetail = true
                                    }
                                } catch {
                                    print("Error analyzing image: \(error)")
                                    await completion()
                                    selectedItem = newItem
                                    showCameraFlow = false
                                    showingDetail = true
                                }
                            } else {
                                await completion()
                                selectedItem = newItem
                                showCameraFlow = false
                                showingDetail = true
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetail, onDismiss: {
            if selectedItem?.modelContext != nil {
                manager.moveToNext()
            }
        }) {
            if let item = selectedItem {
                NavigationStack {
                    InventoryDetailView(
                        inventoryItemToDisplay: item,
                        navigationPath: .constant(NavigationPath()),
                        isEditing: true
                    )
                }
            }
        }
        .alert("Privacy Notice", isPresented: $showPrivacyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                showCameraFlow = true
            }
        } message: {
            Text("Photos you take will be processed by OpenAI's vision API. Please ensure no sensitive information is visible in your photos.")
        }
    }
    
    private func updateUIWithImageDetails(_ imageDetails: ImageDetails, for item: InventoryItem) {
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

struct PrivacyBulletPoint: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            Text(text)
                .font(.subheadline)
        }
    }
    
    private var iconColor: Color {
        switch icon {
        case "checkmark.shield":
            return .green
        case "xmark.shield":
            return .red
        case "exclamationmark.triangle":
            return .orange
        default:
            return .primary
        }
    }
}

#Preview {
    OnboardingItemView()
        .environmentObject(OnboardingManager())
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
