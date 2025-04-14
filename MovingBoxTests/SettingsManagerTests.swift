import Testing
import Foundation
@testable import MovingBox

@MainActor
@Suite struct SettingsManagerTests {
    
    // Helper class to mock UserDefaults
    final class TestUserDefaults {
        private var storage: [String: Any] = [:]
        
        func set(_ value: Any?, forKey defaultName: String) {
            storage[defaultName] = value
        }
        
        func bool(forKey defaultName: String) -> Bool {
            return storage[defaultName] as? Bool ?? false
        }
        
        func string(forKey defaultName: String) -> String? {
            return storage[defaultName] as? String
        }
        
        func double(forKey defaultName: String) -> Double {
            return storage[defaultName] as? Double ?? 0.0
        }
        
        func integer(forKey defaultName: String) -> Int {
            return storage[defaultName] as? Int ?? 0
        }
        
        func object(forKey defaultName: String) -> Any? {
            return storage[defaultName]
        }
        
        func removeObject(forKey defaultName: String) {
            storage.removeValue(forKey: defaultName)
        }
        
        func clear() {
            storage.removeAll()
        }
    }
    
    // Test wrapper for SettingsManager that uses our test defaults
    class TestSettingsManager: ObservableObject {
        private let defaults: TestUserDefaults
        
        @Published var aiModel: String {
            didSet { defaults.set(aiModel, forKey: "aiModel") }
        }
        
        @Published var temperature: Double {
            didSet { defaults.set(temperature, forKey: "temperature") }
        }
        
        @Published var maxTokens: Int {
            didSet { defaults.set(maxTokens, forKey: "maxTokens") }
        }
        
        @Published var apiKey: String {
            didSet { defaults.set(apiKey, forKey: "apiKey") }
        }
        
        @Published var isHighDetail: Bool {
            didSet { defaults.set(isHighDetail, forKey: "isHighDetail") }
        }
        
        @Published var hasLaunched: Bool {
            didSet { defaults.set(hasLaunched, forKey: "hasLaunched") }
        }
        
        @Published var isPro: Bool {
            didSet { defaults.set(isPro, forKey: "isPro") }
        }
        
        @Published var hasSeenPaywall: Bool {
            didSet { defaults.set(hasSeenPaywall, forKey: "hasSeenPaywall") }
        }
        
        init(defaults: TestUserDefaults) {
            self.defaults = defaults
            self.aiModel = "gpt-4o-mini"
            self.temperature = 0.7
            self.maxTokens = 300
            self.apiKey = ""
            self.isHighDetail = false
            self.hasLaunched = false
            self.isPro = false
            self.hasSeenPaywall = false
        }
        
        func resetToDefaults() {
            aiModel = "gpt-4o-mini"
            temperature = 0.7
            maxTokens = 300
            apiKey = ""
            isHighDetail = false
            isPro = false
            hasSeenPaywall = false
        }
        
        func shouldShowPaywall() -> Bool {
            return !isPro
        }
        
        func shouldShowPaywallForAI() -> Bool {
            return !isPro
        }
        
        func shouldShowPaywallForCamera() -> Bool {
            return !isPro
        }
        
        func shouldShowFirstTimePaywall(itemCount: Int) -> Bool {
            return !hasSeenPaywall && itemCount == 0 && !isPro
        }
        
        func shouldShowFirstLocationPaywall(locationCount: Int) -> Bool {
            return !hasSeenPaywall && locationCount == 0 && !isPro
        }
        
        func hasReachedItemLimit(currentCount: Int) -> Bool {
            return !isPro && currentCount >= SettingsManager.maxFreeItems
        }
        
        func hasReachedLocationLimit(currentCount: Int) -> Bool {
            return !isPro && currentCount >= SettingsManager.maxFreeLocations
        }
        
        func canAddMoreItems(currentCount: Int) -> Bool {
            return isPro || currentCount < SettingsManager.maxFreeItems
        }
        
        func canAddMorePhotos(currentCount: Int) -> Bool {
            return isPro || currentCount < SettingsManager.maxFreePhotosPerItem
        }
    }
    
    // Helper function to create clean test environment
    func createTestEnvironment() -> (manager: TestSettingsManager, defaults: TestUserDefaults) {
        let defaults = TestUserDefaults()
        let manager = TestSettingsManager(defaults: defaults)
        return (manager, defaults)
    }
    
    @Test("Test default initialization")
    func testDefaultInitialization() async {
        // Given
        let (manager, _) = createTestEnvironment()
        
        // Then
        #expect(manager.aiModel == "gpt-4o-mini")
        #expect(manager.temperature == 0.7)
        #expect(manager.maxTokens == 300)
        #expect(manager.apiKey == "")
        #expect(manager.isHighDetail == false)
        #expect(manager.hasLaunched == false)
        #expect(manager.isPro == false)
        #expect(manager.hasSeenPaywall == false)
    }
    
    @Test("Test settings persistence")
    func testSettingsPersistence() async {
        // Given
        let (manager, defaults) = createTestEnvironment()
        
        // When - Clear any existing values
        defaults.clear()
        
        // Then set new values
        manager.aiModel = "test-model"
        manager.temperature = 0.9
        manager.maxTokens = 500
        manager.apiKey = "test-key"
        manager.isHighDetail = true
        manager.hasLaunched = true
        
        // Then verify the values were saved
        #expect(defaults.string(forKey: "aiModel") == "test-model")
        #expect(defaults.double(forKey: "temperature") == 0.9)
        #expect(defaults.integer(forKey: "maxTokens") == 500)
        #expect(defaults.string(forKey: "apiKey") == "test-key")
        #expect(defaults.bool(forKey: "isHighDetail") == true)
        #expect(defaults.bool(forKey: "hasLaunched") == true)
    }
    
    @Test("Test Pro feature checks")
    func testProFeatureChecks() async {
        // Given
        let (manager, _) = createTestEnvironment()
        
        // When - Free tier
        #expect(manager.shouldShowPaywall() == true)
        #expect(manager.shouldShowPaywallForAI() == true)
        #expect(manager.shouldShowPaywallForCamera() == true)
        #expect(manager.hasReachedItemLimit(currentCount: SettingsManager.maxFreeItems) == true)
        #expect(manager.hasReachedLocationLimit(currentCount: SettingsManager.maxFreeLocations) == true)
        #expect(manager.canAddMoreItems(currentCount: SettingsManager.maxFreeItems - 1) == true)
        #expect(manager.canAddMoreItems(currentCount: SettingsManager.maxFreeItems) == false)
        #expect(manager.canAddMorePhotos(currentCount: SettingsManager.maxFreePhotosPerItem) == false)
        
        // When - Pro tier
        manager.isPro = true
        #expect(manager.shouldShowPaywall() == false)
        #expect(manager.shouldShowPaywallForAI() == false)
        #expect(manager.shouldShowPaywallForCamera() == false)
        #expect(manager.hasReachedItemLimit(currentCount: 100) == false)
        #expect(manager.hasReachedLocationLimit(currentCount: 10) == false)
        #expect(manager.canAddMoreItems(currentCount: 1000) == true)
        #expect(manager.canAddMorePhotos(currentCount: 10) == true)
    }
    
    @Test("Test reset functionality")
    func testResetToDefaults() async {
        // Given
        let (manager, _) = createTestEnvironment()
        
        // When - Change some settings
        manager.aiModel = "test-model"
        manager.temperature = 0.9
        manager.maxTokens = 500
        manager.isPro = true
        manager.hasSeenPaywall = true
        
        // Then - Reset and verify
        manager.resetToDefaults()
        #expect(manager.aiModel == "gpt-4o-mini")
        #expect(manager.temperature == 0.7)
        #expect(manager.maxTokens == 300)
        #expect(manager.isPro == false)
        #expect(manager.hasSeenPaywall == false)
    }
    
    @Test("Test paywall trigger conditions")
    func testPaywallTriggers() async {
        // Given
        let (manager, _) = createTestEnvironment()
        
        // When/Then - First time triggers
        #expect(manager.shouldShowFirstTimePaywall(itemCount: 0) == true)
        #expect(manager.shouldShowFirstLocationPaywall(locationCount: 0) == true)
        
        // When - Mark paywall as seen
        manager.hasSeenPaywall = true
        
        // Then - Should not show first time paywalls
        #expect(manager.shouldShowFirstTimePaywall(itemCount: 0) == false)
        #expect(manager.shouldShowFirstLocationPaywall(locationCount: 0) == false)
    }
    
    @Test("Test edge cases for first-time paywall")
    func testFirstTimePaywallEdgeCases() async {
        // Given
        let (manager, _) = createTestEnvironment()
        
        // When/Then - Free user, first time
        #expect(manager.shouldShowFirstTimePaywall(itemCount: 0) == true)
        #expect(manager.shouldShowFirstLocationPaywall(locationCount: 0) == true)
        
        // When - User has seen paywall
        manager.hasSeenPaywall = true
        #expect(manager.shouldShowFirstTimePaywall(itemCount: 0) == false)
        #expect(manager.shouldShowFirstLocationPaywall(locationCount: 0) == false)
        
        // When - User is Pro
        manager.isPro = true
        #expect(manager.shouldShowFirstTimePaywall(itemCount: 0) == false)
        #expect(manager.shouldShowFirstLocationPaywall(locationCount: 0) == false)
        
        // When - Has items but not Pro
        manager.isPro = false
        #expect(manager.shouldShowFirstTimePaywall(itemCount: 1) == false)
        #expect(manager.shouldShowFirstLocationPaywall(locationCount: 1) == false)
    }
    
    @Test("Test Pro feature access with UI testing flag")
    func testProFeatureUITestingFlag() async {
        // Given
        let (manager, _) = createTestEnvironment()
        
        // When - Simulate UI testing environment
        #if DEBUG
        manager.isPro = true
        #endif
        
        // Then
        #expect(manager.isPro == true, "Pro status should be true")
        #expect(manager.canAddMorePhotos(currentCount: 10) == true, "Should be able to add more photos")
        
        // Cleanup
        manager.resetToDefaults()
    }
}
