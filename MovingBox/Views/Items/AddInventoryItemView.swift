import SwiftUI
import SwiftData
import AVFoundation

struct AddInventoryItemView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @StateObject private var settings = SettingsManager()
    @State private var showingCamera = false
    @State private var showingPermissionDenied = false
    
    let location: InventoryLocation?
    
    var body: some View {
        VStack {
            Text("Tap the camera button below to add a new item")
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: checkCameraPermissionsAndPresent) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
            }
        }
        .navigationTitle("Add New Item")
        .onAppear(perform: checkCameraPermissionsAndPresent)
        .sheet(isPresented: $showingCamera) {
            CameraView { image, needsAnalysis, completion in
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
                
                // CHANGE: Save image at original quality instead of compressed
                if let originalData = image.jpegData(compressionQuality: 1.0) {
                    newItem.data = originalData
                    modelContext.insert(newItem)
                    TelemetryManager.shared.trackInventoryItemAdded(name: newItem.title)
                    try? modelContext.save()
                    
                    if needsAnalysis {
                        Task {
                            // CHANGE: Use PhotoManager for AI analysis
                            guard let base64ForAI = PhotoManager.loadCompressedPhotoForAI(from: image) else {
                                completion()
                                router.navigate(to: .editInventoryItemView(item: newItem, showSparklesButton: true))
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
                                    router.navigate(to: .editInventoryItemView(item: newItem, isEditing: true))
                                }
                            } catch {
                                print("Error analyzing image: \(error)")
                                completion()
                                router.navigate(to: .editInventoryItemView(item: newItem, showSparklesButton: true))
                            }
                        }
                    } else {
                        completion()
                        router.navigate(to: .editInventoryItemView(item: newItem))
                    }
                }
            }
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

// End of file
