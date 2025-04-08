import Foundation
import SwiftUI
import StoreKit

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
    
    // Pro feature constants
    static let maxFreeItems = 50
    static let maxFreeLocations = 5
    static let maxFreePhotosPerItem = 3
    
    // Pro status
    @AppStorage("isPro") var isPro: Bool = false
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false
    
    // Default values
    private let defaultAIModel = "gpt-4o-mini"
    private let defaultTemperature = 0.7
    private let defaultMaxTokens = 300
    private let defaultApiKey = ""
    private let isHighDetailDefault = false
    private let hasLaunchedDefault = false
    
    init() {
        // Configure for testing
        #if DEBUG
        // For UI testing, we just need to check the launch argument
        if ProcessInfo.processInfo.arguments.contains("Is-Pro") {
            print("⚠️ Running with UI-Testing-Pro flag enabled - All Pro features enabled")
            isPro = true
        }
        // Otherwise use AppConfig
        else if AppConfig.shared.isPro {
            isPro = true
        }
        #else
        if AppConfig.shared.isPro {
            isPro = true
        }
        #endif
        
        // Initialize properties from UserDefaults or use defaults
        self.aiModel = UserDefaults.standard.string(forKey: Keys.aiModel) ?? defaultAIModel
        self.temperature = UserDefaults.standard.double(forKey: Keys.temperature)
        self.maxTokens = UserDefaults.standard.integer(forKey: Keys.maxTokens)
        self.apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? defaultApiKey
        self.isHighDetail = UserDefaults.standard.bool(forKey: Keys.isHighDetail)
        self.hasLaunched = UserDefaults.standard.bool(forKey: Keys.hasLaunched)
        self.iCloudEnabled = UserDefaults.standard.bool(forKey: Keys.iCloudEnabled)
        
        // Initialize last sync date
        self.lastiCloudSync = UserDefaults.standard.object(forKey: Keys.lastSyncDate) as? Date ?? Date.distantPast
        
        if self.temperature == 0.0 { self.temperature = defaultTemperature }
        if self.maxTokens == 0 { self.maxTokens = defaultMaxTokens }
        
        // Set default value for iCloud if not set
        if !UserDefaults.standard.contains(key: Keys.iCloudEnabled) {
            self.iCloudEnabled = true  // Enable by default for Pro users
        }
        
        #if BETA
        if AppConfig.shared.configuration == .debug {
            print("⚠️ Running in BETA-DEBUG mode - All Pro features enabled")
        } else {
            print("⚠️ Running in BETA-RELEASE mode - All Pro features enabled")
        }
        #endif
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
    
    // TODO: Implement RevenueCat purchase flow
    func purchasePro() {
        // This would be replaced with RevenueCat purchase logic
        // Example:
        // Purchases.shared.purchasePackage(package) { (transaction, customerInfo, error, userCancelled) in
        //     self.isPro = customerInfo?.entitlements["pro"]?.isActive ?? false
        // }
        isPro = true
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

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
