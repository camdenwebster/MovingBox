import SwiftUI
import RevenueCat

struct SubscriptionSettingsView: View {
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    @State private var subscriptionInfo: RevenueCatManager.SubscriptionInfo?
    @State private var isLoading = true
    @State private var isSyncing = false
    @State private var isRestoring = false
    @State private var lastSyncDate: Date?
    
    var body: some View {
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
                            .symbolEffect(.rotate, options: .nonRepeating, value: isSyncing)
                            .foregroundStyle(isSyncing ? .secondary : Color.green)
                    }
                    .disabled(isSyncing)
                    
                    Button(action: {
                        Task {
                            await restorePurchases()
                        }
                    }) {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                            .symbolEffect(.rotate, options: .nonRepeating, value: isRestoring)
                            .foregroundStyle(isRestoring ? .secondary : Color.green)
                    }
                    .disabled(isRestoring)
                    
                    if let managementURL = info.managementURL {
                        Link(destination: managementURL) {
                            Label("Manage Subscription", systemImage: "gear")
                        }
                    }
                } footer: {
                    if let lastSync = lastSyncDate {
                        Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
            } else {
                Section {
                    Text("Unable to load subscription details")
                        .foregroundColor(.secondary)
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
            lastSyncDate = .now
        } catch {
            print("Error syncing purchases: \(error)")
        }
        isSyncing = false
    }
    
    private func restorePurchases() async {
        isRestoring = true
        do {
            try await revenueCatManager.restorePurchases()
            lastSyncDate = .now
            // Refresh subscription info after restore
            subscriptionInfo = try await revenueCatManager.getSubscriptionInfo()
        } catch {
            print("Error restoring purchases: \(error)")
        }
        isRestoring = false
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
