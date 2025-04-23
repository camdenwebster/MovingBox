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
    @State private var showingPaywall = false
    @State private var showingPermissionDenied = false
    @State private var showItemCreationFlow = false
    @Query private var allItems: [InventoryItem]
    
    let location: InventoryLocation?
    
    var body: some View {
        VStack {
            Text("Tap the camera button below to add a new item")
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
                    showingPaywall = true
                } else {
                    checkCameraPermissionsAndPresentFlow()
                }
            }) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
            }
        }
        .navigationTitle("Add New Item")
        .onAppear {
            if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
                showingPaywall = true
            } else {
                checkCameraPermissionsAndPresentFlow()
            }
        }
        .sheet(isPresented: $showItemCreationFlow) {
            ItemCreationFlowView(location: location) {
                // Optional callback when item creation is complete
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
    
    private func checkCameraPermissionsAndPresentFlow() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showItemCreationFlow = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showItemCreationFlow = true
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
