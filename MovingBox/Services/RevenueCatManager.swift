import Foundation
import RevenueCat
import RevenueCatUI
import SwiftUI
import Combine

@MainActor
class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    // Private storage
    @Published private var _isProSubscriptionActive = false
    
    // Public getter
    public var isProSubscriptionActive: Bool {
        ProcessInfo.processInfo.arguments.contains("Is-Pro") ? true : _isProSubscriptionActive
    }
    
    @Published private(set) var currentOffering: Offering?
    private var cancellables = Set<AnyCancellable>()
    
    // ADD: New closure for handling dismissal
    var onPaywallDismissed: (() -> Void)?
    var onPurchaseCompleted: (() -> Void)?
    
    struct SubscriptionInfo {
        let status: String
        let planType: String
        let willRenew: Bool
        let expirationDate: Date?
        let managementURL: URL?
    }
    
    private override init() {
        // CHANGE: Check for Is-Pro before setting initial value
        let isPro = ProcessInfo.processInfo.arguments.contains("Is-Pro")
        Logger.info("Initializing with Is-Pro: \(isPro)", category: .subscription)
        self._isProSubscriptionActive = isPro
        super.init()
        
        // Only setup purchases if Is-Pro is not present
        if !isPro {
            Logger.info("Setting up purchases updates", category: .subscription)
            setupPurchasesUpdates()
            
            Task {
                do {
                    try await updateCustomerInfo()
                } catch {
                    Logger.error("Error during initial customer info fetch: \(error)", category: .subscription)
                }
            }
        } else {
            Logger.info("Skipping RevenueCat setup due to Is-Pro argument", category: .subscription)
        }
    }
    
    private func setupPurchasesUpdates() {
        Logger.info("Setting up purchases delegate...", category: .subscription)
        Purchases.shared.delegate = self
        
        // Force an immediate check of customer info
        Task {
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                handleCustomerInfoUpdate(customerInfo)
                Logger.info("Initial customer info fetched", category: .subscription)
            } catch {
                Logger.error("Error fetching initial customer info: \(error)", category: .subscription)
            }
        }
    }
    
    func updateCustomerInfo() async throws {
        Logger.info("Updating customer info...", category: .subscription)
        let customerInfo = try await Purchases.shared.customerInfo()
        handleCustomerInfoUpdate(customerInfo)
    }
    
    @MainActor
    private func handleCustomerInfoUpdate(_ customerInfo: CustomerInfo) {
        Logger.info("Processing customer info update...", category: .subscription)
        Logger.debug("All entitlements:", category: .subscription)
        
        // DEBUG: Print raw entitlements for verification
        Logger.debug("Raw entitlements:", category: .subscription)
        Logger.debug("\(customerInfo.entitlements.all)", category: .subscription)
        
        customerInfo.entitlements.all.forEach { entitlement in
            Logger.debug("Entitlement: \(entitlement.key)", category: .subscription)
            Logger.debug("  - Identifier: \(entitlement.value.identifier)", category: .subscription)
            Logger.debug("  - Is active: \(entitlement.value.isActive)", category: .subscription)
            Logger.debug("  - Will renew: \(String(describing: entitlement.value.willRenew))", category: .subscription)
            Logger.debug("  - Product identifier: \(entitlement.value.productIdentifier)", category: .subscription)
            if let expirationDate = entitlement.value.expirationDate {
                Logger.debug("  - Expires: \(expirationDate)", category: .subscription)
            }
        }
        
        // Check for "Pro" entitlement (case-sensitive)
        if let proEntitlement = customerInfo.entitlements["Pro"] {
            let isPro = proEntitlement.isActive
            Logger.info("Found Pro entitlement:", category: .subscription)
            Logger.info("  - Is active: \(isPro)", category: .subscription)
            Logger.info("  - Identifier: \(proEntitlement.identifier)", category: .subscription)
            Logger.info("  - Product identifier: \(proEntitlement.productIdentifier)", category: .subscription)
            self._isProSubscriptionActive = isPro
            UserDefaults.standard.set(isPro, forKey: "isPro")
            Logger.info("Updated Pro status: \(isPro)", category: .subscription)
            
            // Notify observers
            NotificationCenter.default.post(
                name: .subscriptionStatusChanged,
                object: nil,
                userInfo: ["isProActive": isPro]
            )
        } else {
            Logger.warning("Pro entitlement not found in customerInfo", category: .subscription)
            self._isProSubscriptionActive = false
            UserDefaults.standard.set(false, forKey: "isPro")
            
            // Notify observers
            NotificationCenter.default.post(
                name: .subscriptionStatusChanged,
                object: nil,
                userInfo: ["isProActive": false]
            )
        }
    }
    
    func getSubscriptionInfo() async throws -> SubscriptionInfo {
        let customerInfo = try await Purchases.shared.customerInfo()
        let proEntitlement = customerInfo.entitlements["Pro"]
        
        return SubscriptionInfo(
            status: proEntitlement?.isActive == true ? "Active" : "Inactive",
            planType: proEntitlement?.productIdentifier == "mb_rc_699_1m_1w0" ? "Monthly" : "Annual",
            willRenew: proEntitlement?.willRenew ?? false,
            expirationDate: proEntitlement?.expirationDate,
            managementURL: customerInfo.managementURL
        )
    }
    
    func presentPaywall(isPresented: Binding<Bool>, onCompletion: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) -> some View {
        self.onPurchaseCompleted = onCompletion
        self.onPaywallDismissed = onDismiss
        
        return PaywallView()
            .onChange(of: isProSubscriptionActive) { [self] oldValue, newValue in
                if newValue {
                    Logger.info("Pro subscription activated", category: .subscription)
                    isPresented.wrappedValue = false
                    self.onPurchaseCompleted?()
                }
            }
            .onChange(of: isPresented.wrappedValue) { [self] oldValue, newValue in
                if !newValue {
                    Logger.info("Paywall view dismissed", category: .subscription)
                    self.onPaywallDismissed?()
                }
            }
    }
    
    func purchasePro() async throws {
        Logger.info("Starting Pro purchase flow", category: .subscription)
        do {
            let offerings = try await Purchases.shared.offerings()
            Logger.info("Retrieved offerings", category: .subscription)
            
            guard let offering = offerings.current else {
                Logger.warning("No offering available", category: .subscription)
                throw NSError(domain: "RevenueCatManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No offering available"])
            }
            
            Logger.info("Available packages:", category: .subscription)
            offering.availablePackages.forEach { package in
                Logger.debug("  - \(package.identifier): \(package.storeProduct.productIdentifier)", category: .subscription)
            }
            
            guard let package = offering.availablePackages.first else {
                Logger.warning("No package available", category: .subscription)
                throw NSError(domain: "RevenueCatManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No package available"])
            }
            
            Logger.info("Attempting to purchase package: \(package.identifier)", category: .subscription)
            let result = try await Purchases.shared.purchase(package: package)
            handleCustomerInfoUpdate(result.customerInfo)
        } catch {
            Logger.error("Purchase failed: \(error)", category: .subscription)
            throw error
        }
    }
    
    func restorePurchases() async throws {
        Logger.info("Starting restore purchases flow", category: .subscription)
        do {
            // First try to get current customer info
            let currentInfo = try await Purchases.shared.customerInfo()
            Logger.info("Current customer info before restore:", category: .subscription)
            handleCustomerInfoUpdate(currentInfo)
            
            // Perform the restore
            Logger.info("Calling restorePurchases...", category: .subscription)
            let customerInfo = try await Purchases.shared.restorePurchases()
            Logger.info("Restore completed, processing results...", category: .subscription)
            handleCustomerInfoUpdate(customerInfo)
            
            // Double-check the status after restore
            let finalCheck = try await Purchases.shared.customerInfo()
            Logger.info("Final verification after restore:", category: .subscription)
            handleCustomerInfoUpdate(finalCheck)
            
            // If Pro is active after restore, ensure paywall is dismissed
            if finalCheck.entitlements["Pro"]?.isActive == true {
                Logger.info("Pro is active after restore", category: .subscription)
            }
        } catch {
            Logger.error("Restore failed: \(error)", category: .subscription)
            throw error
        }
    }
    
    func syncPurchases() async throws {
        Logger.info("Syncing purchases...", category: .subscription)
        let customerInfo = try await Purchases.shared.syncPurchases()
        handleCustomerInfoUpdate(customerInfo)
    }
    
    func getCustomerInfo() async throws -> RevenueCat.CustomerInfo {
        return try await Purchases.shared.customerInfo()
    }

}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Logger.info("Delegate received updated customer info", category: .subscription)
        Task { @MainActor in
            handleCustomerInfoUpdate(customerInfo)
        }
    }
    
    nonisolated func purchases(_ purchases: Purchases, readyForPromotePaywall readyForPromote: Bool) {
        Logger.info("Ready for promote paywall: \(readyForPromote)", category: .subscription)
    }
    
    nonisolated func purchases(_ purchases: Purchases, completedTransaction transaction: StoreTransaction) {
        Logger.info("Completed transaction: \(transaction.productIdentifier)", category: .subscription)
        Task { @MainActor in
            do {
                try await updateCustomerInfo()
            } catch {
                Logger.error("Error updating customer info after transaction: \(error)", category: .subscription)
            }
        }
    }
    
    nonisolated func purchases(_ purchases: Purchases, failedTransaction transaction: StoreTransaction) {
        Logger.error("Failed transaction: \(transaction.productIdentifier)", category: .subscription)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("RevenueCatSubscriptionStatusChanged")
}
