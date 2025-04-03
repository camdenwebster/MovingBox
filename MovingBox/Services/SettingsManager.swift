import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    // Keys for UserDefaults
    private enum Keys {
        static let aiModel = "aiModel"
        static let temperature = "temperature"
        static let maxTokens = "maxTokens"
        static let apiKey = "apiKey"
        static let isHighDetail = "isHighDetail"
        static let hasLaunched = "hasLaunched"
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
        // Initialize properties from UserDefaults or use defaults
        self.aiModel = UserDefaults.standard.string(forKey: Keys.aiModel) ?? defaultAIModel
        self.temperature = UserDefaults.standard.double(forKey: Keys.temperature)
        self.maxTokens = UserDefaults.standard.integer(forKey: Keys.maxTokens)
        self.apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? defaultApiKey
        self.isHighDetail = UserDefaults.standard.bool(forKey: Keys.isHighDetail)
        self.hasLaunched = UserDefaults.standard.bool(forKey: Keys.hasLaunched)
        
        if self.temperature == 0.0 { self.temperature = defaultTemperature }
        if self.maxTokens == 0 { self.maxTokens = defaultMaxTokens }
        
        #if BETA
        if AppConfig.shared.configuration == .debug {
            print("⚠️ Running in BETA-DEBUG mode - All Pro features enabled")
        } else {
            print("⚠️ Running in BETA-RELEASE mode - All Pro features enabled")
        }
        #endif
    }
    
    func shouldShowPaywall() -> Bool {
        !isPro
    }
    
    func shouldShowPaywallForAI() -> Bool {
        !isPro
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
    
    // Reset settings to defaults
    func resetToDefaults() {
        aiModel = defaultAIModel
        temperature = defaultTemperature
        maxTokens = defaultMaxTokens
        apiKey = defaultApiKey
        isHighDetail = isHighDetailDefault
        hasLaunched = hasLaunchedDefault
        hasSeenPaywall = false
        isPro = false
    }
}
