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
        static let syncServiceType = "syncServiceType"
        static let homeBoxServerURL = "homeBoxServerURL"
        static let homeBoxUsername = "homeBoxUsername"
        static let syncEnabled = "syncEnabled"
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
    
    // MARK: - Sync Properties
    
    @Published var syncServiceType: SyncServiceType {
        didSet {
            UserDefaults.standard.set(syncServiceType.rawValue, forKey: Keys.syncServiceType)
            updateSyncManager()
        }
    }
    
    @Published var homeBoxServerURL: String {
        didSet {
            UserDefaults.standard.set(homeBoxServerURL, forKey: Keys.homeBoxServerURL)
        }
    }
    
    @Published var homeBoxUsername: String {
        didSet {
            UserDefaults.standard.set(homeBoxUsername, forKey: Keys.homeBoxUsername)
        }
    }
    
    @Published var syncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(syncEnabled, forKey: Keys.syncEnabled)
        }
    }
    
    // Pro feature constants
    public struct AppConstants: Sendable {
        static let maxFreeAiScans = 50
    }
    
    private let revenueCatManager = RevenueCatManager.shared
    
    // Default values
    private let defaultAIModel = "gpt-4o-mini"
    private let defaultTemperature = 0.7
    private let defaultMaxTokens = 300
    private let defaultApiKey = ""
    private let isHighDetailDefault = false
    private let hasLaunchedDefault = false
    private let defaultSyncServiceType = SyncServiceType.icloud
    private let defaultHomeBoxServerURL = ""
    private let defaultHomeBoxUsername = ""
    private let defaultSyncEnabled = true
    
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
        self.syncServiceType = defaultSyncServiceType
        self.homeBoxServerURL = defaultHomeBoxServerURL
        self.homeBoxUsername = defaultHomeBoxUsername
        self.syncEnabled = defaultSyncEnabled
        
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
        
        // Load sync properties from UserDefaults
        let syncServiceString = UserDefaults.standard.string(forKey: Keys.syncServiceType) ?? defaultSyncServiceType.rawValue
        self.syncServiceType = SyncServiceType(rawValue: syncServiceString) ?? defaultSyncServiceType
        self.homeBoxServerURL = UserDefaults.standard.string(forKey: Keys.homeBoxServerURL) ?? defaultHomeBoxServerURL
        self.homeBoxUsername = UserDefaults.standard.string(forKey: Keys.homeBoxUsername) ?? defaultHomeBoxUsername
        self.syncEnabled = UserDefaults.standard.object(forKey: Keys.syncEnabled) as? Bool ?? defaultSyncEnabled
        
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
    
    func shouldShowPaywallForAiScan(currentCount: Int) -> Bool {
        print("📱 SettingsManager - Checking hasReachedAiScanLimit")
        print("📱 SettingsManager - Current isPro: \(isPro)")
        print("📱 SettingsManager - Current count of items which have used AI scan: \(currentCount)")
        return !isPro && currentCount >= AppConstants.maxFreeAiScans
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

    // MARK: - Sync Management
    
    /// Update the sync manager when sync service type changes
    private func updateSyncManager() {
        Task {
            do {
                try await SyncManager.shared.configureSyncService(syncServiceType)
                print("📱 SettingsManager - Successfully configured sync service: \(syncServiceType)")
            } catch {
                print("⚠️ SettingsManager - Failed to configure sync service: \(error)")
            }
        }
    }
    
    // MARK: - Reset Settings
    
    func resetToDefaults() {
        aiModel = defaultAIModel
        temperature = defaultTemperature
        maxTokens = defaultMaxTokens
        apiKey = defaultApiKey
        isHighDetail = isHighDetailDefault
        hasLaunched = hasLaunchedDefault
        isPro = false
        
        // Reset sync properties
        syncServiceType = defaultSyncServiceType
        homeBoxServerURL = defaultHomeBoxServerURL
        homeBoxUsername = defaultHomeBoxUsername
        syncEnabled = defaultSyncEnabled
        
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
