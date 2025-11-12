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
    @State private var showingCaptureModeSelection = false
    @State private var selectedCaptureMode: CaptureMode = .singleItem
    @Query private var allItems: [InventoryItem]
    
    let location: InventoryLocation?
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Choose how you'd like to add items")
                .multilineTextAlignment(.center)
                .font(.title2)
                .padding()
            
            VStack(spacing: 20) {
                // Single Item Button
                Button(action: {
                    selectedCaptureMode = .singleItem
                    checkPermissionsAndPresentFlow()
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 4) {
                            Text("Single Item")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Take multiple photos of one item")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Multi Item Button (Pro Feature)
                Button(action: {
                    if settings.isPro {
                        selectedCaptureMode = .multiItem
                        checkPermissionsAndPresentFlow()
                    } else {
                        showingPaywall = true
                    }
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Image(systemName: "camera.metering.multispot")
                                .font(.system(size: 50))
                                .foregroundColor(settings.isPro ? .green : .secondary)
                            
                            if !settings.isPro {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.yellow)
                                    .offset(x: 20, y: -20)
                            }
                        }
                        
                        VStack(spacing: 4) {
                            HStack {
                                Text("Multi Item")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if !settings.isPro {
                                    Text("PRO")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.yellow)
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text("Take one photo with multiple items")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background((settings.isPro ? Color.green : Color.gray).opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Add New Item")
        .sheet(isPresented: $showItemCreationFlow) {
            EnhancedItemCreationFlowView(
                captureMode: selectedCaptureMode,
                location: location
            ) {
                // Optional callback when item creation is complete
                dismiss()
            }
            .id("flow-\(selectedCaptureMode)")  // Force new view when capture mode changes
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
