import RevenueCatUI
import SwiftUI
import SwiftData
import AVFoundation

struct AddInventoryItemView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    @State private var showingCamera = false
    @State private var showingPermissionDenied = false
    @State private var showingPaywall = false
    @State private var showLimitAlert = false
    @State private var showingImageAnalysis = false
    @State private var analyzingImage: UIImage?
    @Query private var allItems: [InventoryItem]
    
    let location: InventoryLocation?
    
    var body: some View {
        VStack {
            Text("Tap the camera button below to add a new item")
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                if settings.shouldShowFirstTimePaywall(itemCount: allItems.count) {
                    showingPaywall = true
                } else if settings.hasReachedItemLimit(currentCount: allItems.count) {
                    showLimitAlert = true
                } else {
                    checkCameraPermissionsAndPresent()
                }
            }) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
            }
        }
        .navigationTitle("Add New Item")
        .onAppear {
            if settings.shouldShowFirstTimePaywall(itemCount: allItems.count) {
                showingPaywall = true
            } else if settings.hasReachedItemLimit(currentCount: allItems.count) {
                showLimitAlert = true
            } else {
                checkCameraPermissionsAndPresent()
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(
                showingImageAnalysis: $showingImageAnalysis,
                analyzingImage: $analyzingImage
            ) { image, needsAnalysis, completion in
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
                
                if let originalData = image.jpegData(compressionQuality: 1.0) {
                    newItem.data = originalData
                    modelContext.insert(newItem)
                    TelemetryManager.shared.trackInventoryItemAdded(name: newItem.title)
                    try? modelContext.save()
                    
                    if needsAnalysis {
                        Task {
                            guard let base64ForAI = PhotoManager.loadCompressedPhotoForAI(from: image) else {
                                completion()
                                router.navigate(to: .inventoryDetailView(item: newItem, showSparklesButton: true, isEditing: true))
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
                                    completion()
                                    router.navigate(to: .inventoryDetailView(item: newItem, isEditing: true))
                                }
                            } catch {
                                print("Error analyzing image: \(error)")
                                completion()
                                router.navigate(to: .inventoryDetailView(item: newItem, showSparklesButton: true, isEditing: true))
                            }
                        }
                    } else {
                        completion()
                        router.navigate(to: .inventoryDetailView(item: newItem, isEditing: true))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingImageAnalysis) {
            if let image = analyzingImage {
                ImageAnalysisView(image: image) {
                    showingImageAnalysis = false
                    analyzingImage = nil
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            revenueCatManager.presentPaywall(isPresented: $showingPaywall)
        }
        .alert("Upgrade to Pro", isPresented: $showLimitAlert) {
            Button("Upgrade") {
                showingPaywall = true
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("You've reached the maximum number of items (\(SettingsManager.maxFreeItems)) for free users. Upgrade to Pro for unlimited items!")
        }
        .alert("Camera Access Required", isPresented: $showingPermissionDenied) {
            Button("Go to Settings", action: openSettings)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please grant camera access in Settings to use this feature.")
        }
    }
    
    private func checkCameraPermissionsAndPresent() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        showingPermissionDenied = true
                    }
                }
            }
        default:
            showingPermissionDenied = true
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func updateUIWithImageDetails(_ imageDetails: ImageDetails, for item: InventoryItem) {
        let fetchDescriptor = FetchDescriptor<InventoryLabel>()
        
        guard let labels = try? modelContext.fetch(fetchDescriptor) else { return }
        
        item.title = imageDetails.title
        item.quantityString = imageDetails.quantity
        item.label = labels.first { $0.name == imageDetails.category }
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        item.hasUsedAI = true
        
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        guard let locations = try? modelContext.fetch(locationDescriptor) else { return }
        
        if location == nil && item.location == nil {
            item.location = locations.first { $0.name == imageDetails.location }
        }
        
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        item.price = Decimal(string: priceString) ?? 0
        
        try? modelContext.save()
    }
}

#Preview {
    AddInventoryItemView(location: nil)
        .modelContainer(try! ModelContainer(for: InventoryLocation.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        .environmentObject(Router())
        .environmentObject(SettingsManager())
        .environmentObject(RevenueCatManager.shared)
}
