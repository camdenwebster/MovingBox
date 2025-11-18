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
        // Simplified view - just trigger camera flow immediately
        Color.clear
            .navigationTitle("Add New Item")
            .onAppear {
                checkPermissionsAndPresentFlow()
            }
            .sheet(isPresented: $showItemCreationFlow) {
                // Present camera directly with default single-item mode
                // User can switch modes via segmented control in camera
                EnhancedItemCreationFlowView(
                    captureMode: .singleItem,
                    location: location
                ) {
                    // Optional callback when item creation is complete
                    dismiss()
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
                Button("Cancel", role: .cancel) { dismiss() }
            } message: {
                Text("Please grant camera access in Settings to use this feature.")
            }
    }

    private func checkPermissionsAndPresentFlow() {
        // Check if this requires a paywall for AI scanning
        if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
            showingPaywall = true
            return
        }

        // Check camera permissions
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
