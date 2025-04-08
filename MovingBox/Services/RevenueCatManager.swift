import Foundation
import RevenueCat
import Combine

@MainActor
class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published private(set) var isProSubscriptionActive = false {
        didSet {
            print("📱 RevenueCatManager - Pro status changed: \(isProSubscriptionActive)")
            UserDefaults.standard.set(isProSubscriptionActive, forKey: "isPro")
        }
    }
    @Published private(set) var currentOffering: Offering?
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        print("📱 RevenueCatManager - Initializing...")
        setupPurchasesUpdates()
        
        // Initial fetch of customer info
        Task {
            await updateCustomerInfo()
        }
    }
    
    private func setupPurchasesUpdates() {
        print("📱 RevenueCatManager - Setting up purchases delegate...")
        Purchases.shared.delegate = self
        
        // Force an immediate check of customer info
        Task {
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                handleCustomerInfoUpdate(customerInfo)
                print("📱 RevenueCatManager - Initial customer info fetched")
            } catch {
                print("⚠️ RevenueCatManager - Error fetching initial customer info: \(error)")
            }
        }
    }
    
    func updateCustomerInfo() async {
        print("📱 RevenueCatManager - Updating customer info...")
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            handleCustomerInfoUpdate(customerInfo)
        } catch {
            print("⚠️ RevenueCatManager - Error updating customer info: \(error)")
        }
    }
    
    @MainActor
    private func handleCustomerInfoUpdate(_ customerInfo: CustomerInfo) {
        print("📱 RevenueCatManager - Processing customer info update...")
        
        // Check for "Pro" entitlement (case-sensitive)
        if let proEntitlement = customerInfo.entitlements["Pro"] {
            let isPro = proEntitlement.isActive
            print("📱 RevenueCatManager - Found Pro entitlement:")
            print("  - Is active: \(isPro)")
            print("  - Identifier: \(proEntitlement.identifier)")
            print("  - Product identifier: \(proEntitlement.productIdentifier)")
            self.isProSubscriptionActive = isPro
            print("📱 RevenueCatManager - Updated Pro status: \(isPro)")
            
            // Save to UserDefaults directly as backup
            UserDefaults.standard.set(isPro, forKey: "isPro")
            
            // Notify SettingsManager
            NotificationCenter.default.post(
                name: .subscriptionStatusChanged,
                object: nil,
                userInfo: ["isProActive": isPro]
            )
        } else {
            print("⚠️ RevenueCatManager - Pro entitlement not found in customerInfo")
            self.isProSubscriptionActive = false
            
            // Save to UserDefaults directly as backup
            UserDefaults.standard.set(false, forKey: "isPro")
            
            // Notify SettingsManager
            NotificationCenter.default.post(
                name: .subscriptionStatusChanged,
                object: nil,
                userInfo: ["isProActive": false]
            )
        }
    }
    
    func purchasePro() async throws {
        print("📱 RevenueCatManager - Starting Pro purchase flow")
        do {
            let offerings = try await Purchases.shared.offerings()
            print("📱 RevenueCatManager - Retrieved offerings")
            
            guard let offering = offerings.current else {
                print("⚠️ RevenueCatManager - No offering available")
                throw NSError(domain: "RevenueCatManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No offering available"])
            }
            
            print("📱 RevenueCatManager - Available packages:")
            offering.availablePackages.forEach { package in
                print("  - \(package.identifier): \(package.storeProduct.productIdentifier)")
            }
            
            guard let package = offering.availablePackages.first else {
                print("⚠️ RevenueCatManager - No package available")
                throw NSError(domain: "RevenueCatManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No package available"])
            }
            
            print("📱 RevenueCatManager - Attempting to purchase package: \(package.identifier)")
            let result = try await Purchases.shared.purchase(package: package)
            handleCustomerInfoUpdate(result.customerInfo)
        } catch {
            print("⚠️ RevenueCatManager - Purchase failed: \(error)")
            throw error
        }
    }
    
    func restorePurchases() async throws {
        print("📱 RevenueCatManager - Starting restore purchases flow")
        do {
            // First try to get current customer info
            let currentInfo = try await Purchases.shared.customerInfo()
            print("📱 RevenueCatManager - Current customer info before restore:")
            handleCustomerInfoUpdate(currentInfo)
            
            // Perform the restore
            print("📱 RevenueCatManager - Calling restorePurchases...")
            let customerInfo = try await Purchases.shared.restorePurchases()
            print("📱 RevenueCatManager - Restore completed, processing results...")
            handleCustomerInfoUpdate(customerInfo)
            
            // Double-check the status after restore
            let finalCheck = try await Purchases.shared.customerInfo()
            print("📱 RevenueCatManager - Final verification after restore:")
            handleCustomerInfoUpdate(finalCheck)
        } catch {
            print("⚠️ RevenueCatManager - Restore failed: \(error)")
            throw error
        }
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        print("📱 RevenueCatManager - Delegate received updated customer info")
        Task { @MainActor in
            handleCustomerInfoUpdate(customerInfo)
        }
    }
    
    nonisolated func purchases(_ purchases: Purchases, readyForPromotePaywall readyForPromote: Bool) {
        print("📱 RevenueCatManager - Ready for promote paywall: \(readyForPromote)")
    }
    
    nonisolated func purchases(_ purchases: Purchases, completedTransaction transaction: StoreTransaction) {
        print("📱 RevenueCatManager - Completed transaction: \(transaction.productIdentifier)")
        Task { @MainActor in
            try? await updateCustomerInfo()
        }
    }
    
    nonisolated func purchases(_ purchases: Purchases, failedTransaction transaction: StoreTransaction) {
        print("⚠️ RevenueCatManager - Failed transaction: \(transaction.productIdentifier)")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("RevenueCatSubscriptionStatusChanged")
}
