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
    
    @Published var isPro: Bool {
        didSet {
            let proValue = ProcessInfo.processInfo.arguments.contains("Is-Pro") ? true : isPro
            print("📱 SettingsManager - Saving Pro status: \(proValue)")
            UserDefaults.standard.set(proValue, forKey: Keys.isPro)
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
        print("📱 SettingsManager - Starting initialization")
        print("📱 SettingsManager - Is-Pro argument present: \(ProcessInfo.processInfo.arguments.contains("Is-Pro"))")
        
        // Initialize with default values first
        self.aiModel = defaultAIModel
        self.temperature = defaultTemperature
        self.maxTokens = defaultMaxTokens
        self.apiKey = defaultApiKey
        self.isHighDetail = isHighDetailDefault
        self.hasLaunched = hasLaunchedDefault
        self.isPro = ProcessInfo.processInfo.arguments.contains("Is-Pro")
        self.hasSeenPaywall = false
        
        print("📱 SettingsManager - Initial isPro value: \(self.isPro)")
        
        if ProcessInfo.processInfo.arguments.contains("Is-Pro") {
            print("📱 SettingsManager - Setting Pro status to true due to Is-Pro argument")
            UserDefaults.standard.set(true, forKey: Keys.isPro)
        }
        
        Task {
            await setupInitialState()
        }
    }
    
    private func setupInitialState() async {
        print("📱 SettingsManager - Beginning setupInitialState")
        print("📱 SettingsManager - Is-Pro argument present: \(ProcessInfo.processInfo.arguments.contains("Is-Pro"))")
        
        // Check launch arguments first before loading any defaults
        if ProcessInfo.processInfo.arguments.contains("Is-Pro") {
            print("📱 SettingsManager - Setting isPro to true due to launch argument")
            self.isPro = true
            UserDefaults.standard.set(true, forKey: Keys.isPro)
            // Skip RevenueCat check entirely when Is-Pro is present
            print("📱 SettingsManager - Skipping RevenueCat check due to Is-Pro argument")
            return
        }
        
        // Load other values from UserDefaults
        self.aiModel = UserDefaults.standard.string(forKey: Keys.aiModel) ?? defaultAIModel
        self.temperature = UserDefaults.standard.double(forKey: Keys.temperature)
        self.maxTokens = UserDefaults.standard.integer(forKey: Keys.maxTokens)
        self.apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? defaultApiKey
        self.isHighDetail = UserDefaults.standard.bool(forKey: Keys.isHighDetail)
        self.hasLaunched = UserDefaults.standard.bool(forKey: Keys.hasLaunched)
        self.hasSeenPaywall = UserDefaults.standard.bool(forKey: Keys.hasSeenPaywall)
        
        if self.temperature == 0.0 { self.temperature = defaultTemperature }
        if self.maxTokens == 0 { self.maxTokens = defaultMaxTokens }
        
        // Only check RevenueCat if Is-Pro is NOT present
        if !ProcessInfo.processInfo.arguments.contains("Is-Pro") {
            do {
                print("📱 SettingsManager - Checking RevenueCat status")
                let customerInfo = try await Purchases.shared.customerInfo()
                let isPro = customerInfo.entitlements["Pro"]?.isActive == true
                print("📱 SettingsManager - RevenueCat status: \(isPro)")
                self.isPro = isPro
            } catch {
                print("⚠️ SettingsManager - Error fetching customer info: \(error)")
                self.isPro = UserDefaults.standard.bool(forKey: Keys.isPro)
            }
        }
        
        print("📱 SettingsManager - Final isPro value: \(self.isPro)")
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
        print("📱 SettingsManager - Checking hasReachedItemLimit")
        print("📱 SettingsManager - Current isPro: \(isPro)")
        print("📱 SettingsManager - Current count: \(currentCount)")
        return !isPro && currentCount >= SettingsManager.maxFreeItems
    }
    
    func hasReachedLocationLimit(currentCount: Int) -> Bool {
        !isPro && currentCount >= SettingsManager.maxFreeLocations
    }
    
    func shouldShowFirstTimePaywall(itemCount: Int) -> Bool {
        print("📱 SettingsManager - Checking shouldShowFirstTimePaywall")
        print("📱 SettingsManager - Current isPro: \(isPro)")
        print("📱 SettingsManager - Current itemCount: \(itemCount)")
        print("📱 SettingsManager - Current hasSeenPaywall: \(hasSeenPaywall)")
        return !isPro && itemCount == 0 && !hasSeenPaywall
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
