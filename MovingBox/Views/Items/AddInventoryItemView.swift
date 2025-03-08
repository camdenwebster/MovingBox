import SwiftUI
import SwiftData
import AVFoundation

struct AddInventoryItemView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @StateObject private var settings = SettingsManager()
    @State private var showingApiKeyAlert = false
    @State private var showingCamera = false
    @State private var showingPermissionDenied = false
    
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
                    location: nil,
                    label: nil,
                    price: Decimal.zero,
                    insured: false,
                    assetId: "",
                    notes: "",
                    showInvalidQuantityAlert: false
                )
                
                let imageEncoder = ImageEncoder(image: image)
                if let optimizedImage = imageEncoder.optimizeImage(),
                   let imageData = optimizedImage.jpegData(compressionQuality: 0.5) {
                    newItem.data = imageData
                    modelContext.insert(newItem)
                    try? modelContext.save()
                    
                    if needsAnalysis && !settings.apiKey.isEmpty {
                        Task {
                            let openAi = OpenAIService(
                                imageBase64: imageEncoder.encodeImageToBase64() ?? "",
                                settings: settings,
                                modelContext: modelContext
                            )
                            
                            do {
                                let imageDetails = try await openAi.getImageDetails()
                                await MainActor.run {
                                    updateUIWithImageDetails(imageDetails, for: newItem)
                                    completion()
                                    router.navigate(to: .editInventoryItemView(item: newItem))
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
        .alert("OpenAI API Key Required", isPresented: $showingApiKeyAlert) {
            Button("Go to Settings") {
                router.navigate(to: .aISettingsView)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please configure your OpenAI API key in the settings to use this feature.")
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
            if settings.apiKey.isEmpty {
                showingApiKeyAlert = true
            } else {
                showingCamera = true
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        if settings.apiKey.isEmpty {
                            showingApiKeyAlert = true
                        } else {
                            showingCamera = true
                        }
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
        item.location = locations.first { $0.name == imageDetails.location }
        
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        item.price = Decimal(string: priceString) ?? 0
        
        try? modelContext.save()
    }
}

// End of file
