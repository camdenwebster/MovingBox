import RevenueCatUI
import SwiftUI
import SwiftData
import AVFoundation

struct AddInventoryItemView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared
    @State private var showingCamera = false
    @State private var showingPermissionDenied = false
    @State private var showingPaywall = false
    @State private var showItemFlow = false
    @State private var analyzingImage: UIImage?
    @State private var selectedItem: InventoryItem?
    @Query private var allItems: [InventoryItem]
    
    let location: InventoryLocation?
    
    var body: some View {
        VStack {
            Text("Tap the camera button below to add a new item")
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                if settings.hasReachedItemLimit(currentCount: allItems.count) {
                    showingPaywall = true
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
            if settings.hasReachedItemLimit(currentCount: allItems.count) {
                showingPaywall = true
            } else {
                checkCameraPermissionsAndPresent()
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, needsAnalysis, completion async -> Void in
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
                
                let id = UUID().uuidString
                if let imageURL = try? await OptimizedImageManager.shared.saveImage(image, id: id) {
                    newItem.imageURL = imageURL
                    modelContext.insert(newItem)
                    TelemetryManager.shared.trackInventoryItemAdded(name: newItem.title)
                    try? modelContext.save()
                    
                    await completion()
                    showingCamera = false
                    
                    if needsAnalysis {
                        analyzingImage = image
                        selectedItem = newItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showItemFlow = true
                        }
                    } else {
                        router.navigate(to: .inventoryDetailView(item: newItem, isEditing: true))
                    }
                }
            }
        }
        .sheet(isPresented: $showItemFlow) {
            if let image = analyzingImage, let item = selectedItem {
                ItemAnalysisDetailView(
                    item: item,
                    image: image
                ) {
                    showItemFlow = false
                    router.navigate(to: .inventoryDetailView(item: item, isEditing: true))
                }
                .environment(\.isOnboarding, false)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            revenueCatManager.presentPaywall(
                isPresented: $showingPaywall,
                onCompletion: {
                    settings.isPro = true
                },
                onDismiss: nil
            )
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
}

#Preview {
    AddInventoryItemView(location: nil)
        .modelContainer(try! ModelContainer(for: InventoryLocation.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        .environmentObject(Router())
        .environmentObject(SettingsManager())
        .environmentObject(RevenueCatManager.shared)
}
