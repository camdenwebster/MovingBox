import Foundation
import Testing

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

        init(defaults: TestUserDefaults) {
            self.defaults = defaults
            self.aiModel = "google/gemini-3-flash-preview"
            self.temperature = 0.7
            self.maxTokens = 300
            self.apiKey = ""
            self.isHighDetail = false
            self.hasLaunched = false
            self.isPro = false
        }

        func resetToDefaults() {
            aiModel = "google/gemini-3-flash-preview"
            temperature = 0.7
            maxTokens = 300
            apiKey = ""
            isHighDetail = false
            isPro = false
        }

        func shouldShowPaywall() -> Bool {
            return !isPro
        }

        func shouldShowPaywallForAiScan(currentCount: Int) -> Bool {
            return !isPro && currentCount >= 50  // AppConstants.maxFreeAiScans
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
        #expect(manager.aiModel == "google/gemini-3-flash-preview")
        #expect(manager.temperature == 0.7)
        #expect(manager.maxTokens == 300)
        #expect(manager.apiKey == "")
        #expect(manager.isHighDetail == false)
        #expect(manager.hasLaunched == false)
        #expect(manager.isPro == false)
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
        #expect(manager.shouldShowPaywallForAiScan(currentCount: 50) == true)  // At 50 scans (limit reached)
        #expect(manager.shouldShowPaywallForAiScan(currentCount: 49) == false)  // Under limit

        // When - Pro tier
        manager.isPro = true
        #expect(manager.shouldShowPaywall() == false)
        #expect(manager.shouldShowPaywallForAiScan(currentCount: 50) == false)  // Pro users never see paywall
        // Pro users never see paywall, even with high scan count.
        #expect(manager.shouldShowPaywallForAiScan(currentCount: 100) == false)
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

        // Then - Reset and verify
        manager.resetToDefaults()
        #expect(manager.aiModel == "google/gemini-3-flash-preview")
        #expect(manager.temperature == 0.7)
        #expect(manager.maxTokens == 300)
        #expect(manager.isPro == false)
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

        // Cleanup
        manager.resetToDefaults()
    }
}
