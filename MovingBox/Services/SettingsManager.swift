import Foundation
import SwiftUI
import StoreKit
import RevenueCat

@MainActor
class SettingsManager: ObservableObject {
    // Keys for UserDefaults
    private enum Keys {
        static let aiModel = "aiModel"
        static let temperature = "temperature"
        static let maxTokens = "maxTokens"
        static let apiKey = "apiKey"
        static let isHighDetail = "isHighDetail"
        static let hasLaunched = "hasLaunched"
        static let lastSyncDate = "lastSyncDate"
        static let iCloudEnabled = "iCloudEnabled"
        static let isPro = "isPro"
        static let hasSeenPaywall = "hasSeenPaywall"
    }
    
    // Published properties that will update the UI
    @Published var aiModel: String {
        didSet {
            UserDefaults.standard.set(aiModel, forKey: Keys.aiModel)
        }
    }
    
    @Published var temperature: Double {
        didSet {
            UserDefaults.standard.set(temperature, forKey: Keys.temperature)
        }
    }
    
    @Published var maxTokens: Int {
        didSet {
            UserDefaults.standard.set(maxTokens, forKey: Keys.maxTokens)
        }
    }
    
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: Keys.apiKey)
        }
    }
    
    @Published var isHighDetail: Bool {
        didSet {
            UserDefaults.standard.set(isHighDetail, forKey: Keys.isHighDetail)
        }
    }
    
    @Published var hasLaunched: Bool {
        didSet {
            UserDefaults.standard.set(hasLaunched, forKey: Keys.hasLaunched)
        }
    }
    
    @Published var lastiCloudSync: Date {
        didSet {
            UserDefaults.standard.set(lastiCloudSync, forKey: Keys.lastSyncDate)
        }
    }
    
    @Published var iCloudEnabled: Bool {
        didSet {
            UserDefaults.standard.set(iCloudEnabled, forKey: Keys.iCloudEnabled)
        }
    }
    
    @Published var isPro: Bool {
        didSet {
            print("📱 SettingsManager - Saving Pro status: \(isPro)")
            UserDefaults.standard.set(isPro, forKey: Keys.isPro)
        }
    }
    
    @Published var hasSeenPaywall: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenPaywall, forKey: Keys.hasSeenPaywall)
        }
    }
    
    // Pro feature constants
    static let maxFreeItems = 50
    static let maxFreeLocations = 5
    static let maxFreePhotosPerItem = 3
    
    private let revenueCatManager = RevenueCatManager.shared
    
    // Default values
    private let defaultAIModel = "gpt-4o-mini"
    private let defaultTemperature = 0.7
    private let defaultMaxTokens = 300
    private let defaultApiKey = ""
    private let isHighDetailDefault = false
    private let hasLaunchedDefault = false
    
    init() {
        // Initialize with default values first
        self.aiModel = defaultAIModel
        self.temperature = defaultTemperature
        self.maxTokens = defaultMaxTokens
        self.apiKey = defaultApiKey
        self.isHighDetail = isHighDetailDefault
        self.hasLaunched = hasLaunchedDefault
        self.iCloudEnabled = true
        self.isPro = false
        self.hasSeenPaywall = false
        self.lastiCloudSync = Date.distantPast
        
        // Load saved values and setup async state
        Task {
            await setupInitialState()
        }
    }
    
    private func setupInitialState() async {
        // Load values from UserDefaults
        self.aiModel = UserDefaults.standard.string(forKey: Keys.aiModel) ?? defaultAIModel
        self.temperature = UserDefaults.standard.double(forKey: Keys.temperature)
        self.maxTokens = UserDefaults.standard.integer(forKey: Keys.maxTokens)
        self.apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? defaultApiKey
        self.isHighDetail = UserDefaults.standard.bool(forKey: Keys.isHighDetail)
        self.hasLaunched = UserDefaults.standard.bool(forKey: Keys.hasLaunched)
        self.iCloudEnabled = UserDefaults.standard.bool(forKey: Keys.iCloudEnabled)
        self.isPro = UserDefaults.standard.bool(forKey: Keys.isPro)
        self.hasSeenPaywall = UserDefaults.standard.bool(forKey: Keys.hasSeenPaywall)
        self.lastiCloudSync = UserDefaults.standard.object(forKey: Keys.lastSyncDate) as? Date ?? Date.distantPast
        
        if self.temperature == 0.0 { self.temperature = defaultTemperature }
        if self.maxTokens == 0 { self.maxTokens = defaultMaxTokens }
        
        if !UserDefaults.standard.contains(key: Keys.iCloudEnabled) {
            self.iCloudEnabled = true
        }
        
        // Check RevenueCat status immediately
        do {
            print("📱 SettingsManager - Checking RevenueCat status on launch")
            let customerInfo = try await Purchases.shared.customerInfo()
            let isPro = customerInfo.entitlements["Pro"]?.isActive == true
            print("📱 SettingsManager - RevenueCat status check complete - isPro: \(isPro)")
            self.isPro = isPro
        } catch {
            print("⚠️ SettingsManager - Error fetching initial customer info: \(error)")
            // Fallback to saved value
            self.isPro = UserDefaults.standard.bool(forKey: Keys.isPro)
            print("📱 SettingsManager - Using saved Pro status: \(self.isPro)")
        }
        
        // Setup subscription monitoring
        setupSubscriptionMonitoring()
        
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("Is-Pro") {
            print("⚠️ Running with UI-Testing-Pro flag enabled - All Pro features enabled")
            self.isPro = true
        }
        #endif
    }
    
    private func setupSubscriptionMonitoring() {
        // Listen for subscription status changes
        NotificationCenter.default.addObserver(
            forName: .subscriptionStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let isPro = notification.userInfo?["isProActive"] as? Bool {
                print("📱 SettingsManager - Received subscription status change: isPro = \(isPro)")
                
                // Handle actor-isolated property on main actor
                Task { @MainActor in
                    self.isPro = isPro
                    
                    // Post notification for successful purchase
                    if isPro {
                        NotificationCenter.default.post(name: .purchaseCompleted, object: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Pro Feature Checks
    
    func shouldShowPaywall() -> Bool {
        !isPro
    }
    
    func shouldShowPaywallForAI() -> Bool {
        !isPro
    }
    
    func shouldShowPaywallForCamera() -> Bool {
        !isPro && !hasSeenPaywall
    }
    
    func hasReachedItemLimit(currentCount: Int) -> Bool {
        !isPro && currentCount >= SettingsManager.maxFreeItems
    }
    
    func hasReachedLocationLimit(currentCount: Int) -> Bool {
        !isPro && currentCount >= SettingsManager.maxFreeLocations
    }
    
    func shouldShowFirstTimePaywall(itemCount: Int) -> Bool {
        !isPro && itemCount == 0 && !hasSeenPaywall
    }
    
    func shouldShowFirstLocationPaywall(locationCount: Int) -> Bool {
        !isPro && locationCount == 0 && !hasSeenPaywall
    }
    
    func canAddMoreItems(currentCount: Int) -> Bool {
        isPro || currentCount < SettingsManager.maxFreeItems
    }
    
    func canAddMoreLocations(currentCount: Int) -> Bool {
        isPro || currentCount < SettingsManager.maxFreeLocations
    }
    
    func canAddMorePhotos(currentCount: Int) -> Bool {
        isPro || currentCount < SettingsManager.maxFreePhotosPerItem
    }
    
    func canAccessICloudSync() -> Bool {
        return isPro
    }
    
    // MARK: - Purchase Flow
    
    func purchasePro() {
        print("📱 SettingsManager - Initiating Pro purchase")
        Task {
            do {
                try await revenueCatManager.purchasePro()
                // Customer info will be updated via notification
            } catch {
                print("⚠️ SettingsManager - Error purchasing pro: \(error)")
            }
        }
    }
    
    func restorePurchases() async throws {
        print("📱 SettingsManager - Initiating purchase restoration")
        try await RevenueCatManager.shared.restorePurchases()
        // Customer info will be updated via notification
    }

    // MARK: - Reset Settings
    
    func resetToDefaults() {
        aiModel = defaultAIModel
        temperature = defaultTemperature
        maxTokens = defaultMaxTokens
        apiKey = defaultApiKey
        isHighDetail = isHighDetailDefault
        hasLaunched = hasLaunchedDefault
        hasSeenPaywall = false
        isPro = false
        lastiCloudSync = Date.distantPast
        iCloudEnabled = true
        
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("Is-Pro") {
            isPro = true
        }
        #endif
    }
}

extension Notification.Name {
    static let purchaseCompleted = Notification.Name("PurchaseCompletedNotification")
}

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
