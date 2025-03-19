import Foundation

class SettingsManager: ObservableObject {
    // Keys for UserDefaults
    private enum Keys {
        static let aiModel = "aiModel"
        static let temperature = "temperature"
        static let maxTokens = "maxTokens"
        static let apiKey = "apiKey"
        static let isHighDetail = "isHighDetail"
        static let isFirstLaunch = "isFirstLaunch"
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
    
    @Published var isFirstLaunch: Bool {
        didSet {
            UserDefaults.standard.set(isFirstLaunch, forKey: Keys.isFirstLaunch)
        }
    }
    
    // Default values
    private let defaultAIModel = "gpt-4o-mini"
    private let defaultTemperature = 0.7
    private let defaultMaxTokens = 300
    private let defaultApiKey = "Enter API Key"
    private let isHighDetailDefault = false
    
    init() {
        // Initialize properties from UserDefaults or use defaults
        self.aiModel = UserDefaults.standard.string(forKey: Keys.aiModel) ?? defaultAIModel
        self.temperature = UserDefaults.standard.double(forKey: Keys.temperature)
        self.maxTokens = UserDefaults.standard.integer(forKey: Keys.maxTokens)
        self.apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? defaultApiKey
        self.isHighDetail = UserDefaults.standard.bool(forKey: Keys.isHighDetail)
        
        // Initialize isFirstLaunch
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: Keys.isFirstLaunch)
        
        // Set defaults if not already set
        if self.temperature == 0.0 { self.temperature = defaultTemperature }
        if self.maxTokens == 0 { self.maxTokens = defaultMaxTokens }
    }
    
    // Reset settings to defaults
    func resetToDefaults() {
        aiModel = defaultAIModel
        temperature = defaultTemperature
        maxTokens = defaultMaxTokens
        apiKey = defaultApiKey
        isHighDetail = isHighDetailDefault
    }
}
