import SwiftUI
import RevenueCat

struct SubscriptionSettingsView: View {
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    @State private var subscriptionInfo: RevenueCatManager.SubscriptionInfo?
    @State private var isLoading = true
    
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
                            try? await revenueCatManager.restorePurchases()
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
        .navigationTitle("Subscription")
        .task {
            do {
                subscriptionInfo = try await revenueCatManager.getSubscriptionInfo()
                isLoading = false
            } catch {
                print("Error fetching subscription info: \(error)")
                isLoading = false
            }
        }
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
