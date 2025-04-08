import SwiftUI
import RevenueCat

struct SubscriptionSettingsView: View {
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    @State private var subscriptionInfo: RevenueCatManager.SubscriptionInfo?
    @State private var isLoading = true
    @State private var isSyncing = false
    
    var body: some View {
        ZStack {
            if isSyncing {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading Subscription Details...")
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    if isLoading {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    } else if let info = subscriptionInfo {
                        Section {
                            subscriptionRow(title: "Status", value: info.status, systemImage: "checkmark.circle.fill")
                                .foregroundColor(info.status == "Active" ? .green : .red)
                            
                            subscriptionRow(title: "Plan", value: "\(info.planType) Pro", systemImage: "creditcard")
                            
                            if let expirationDate = info.expirationDate {
                                subscriptionRow(
                                    title: info.willRenew ? "Next Billing Date" : "Expires",
                                    value: expirationDate.formatted(date: .abbreviated, time: .shortened),
                                    systemImage: "calendar"
                                )
                            }
                        }
                        
                        Section {
                            Button(action: {
                                Task {
                                    await syncPurchases()
                                }
                            }) {
                                Label("Sync Purchases", systemImage: "arrow.triangle.2.circlepath")
                            }
                            
                            Button(action: {
                                Task {
                                    await restorePurchases()
                                }
                            }) {
                                Label("Restore Purchases", systemImage: "arrow.clockwise")
                            }
                            
                            if let managementURL = info.managementURL {
                                Link(destination: managementURL) {
                                    Label("Manage Subscription", systemImage: "gear")
                                }
                            }
                        }
                    } else {
                        Section {
                            Text("Unable to load subscription details")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Subscription")
        .task {
            await loadSubscriptionInfo()
        }
    }
    
    private func loadSubscriptionInfo() async {
        do {
            // First sync with RevenueCat
            await syncPurchases()
            // Then load subscription info
            subscriptionInfo = try await revenueCatManager.getSubscriptionInfo()
            isLoading = false
        } catch {
            print("Error fetching subscription info: \(error)")
            isLoading = false
        }
    }
    
    private func syncPurchases() async {
        isSyncing = true
        do {
            try await revenueCatManager.syncPurchases()
        } catch {
            print("Error syncing purchases: \(error)")
        }
        isSyncing = false
    }
    
    private func restorePurchases() async {
        isSyncing = true
        do {
            try await revenueCatManager.restorePurchases()
            // Refresh subscription info after restore
            subscriptionInfo = try await revenueCatManager.getSubscriptionInfo()
        } catch {
            print("Error restoring purchases: \(error)")
        }
        isSyncing = false
    }
    
    private func subscriptionRow(title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionSettingsView()
            .environmentObject(RevenueCatManager.shared)
    }
}
