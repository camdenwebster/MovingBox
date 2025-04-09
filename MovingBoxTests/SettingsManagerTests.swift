import Testing
import Foundation
@testable import MovingBox

@MainActor
@Suite struct SettingsManagerTests {
    
    // Helper function to create clean instance and wait for setup
    func createTestManager() async -> SettingsManager {
        let manager = SettingsManager()
        // Wait for next runloop to ensure setupInitialState completes
        try? await Task.sleep(for: .milliseconds(100))
        manager.resetToDefaults()
        return manager
    }
    
    @Test("Test default initialization")
    func testDefaultInitialization() async {
        // Given
        let manager = await createTestManager()
        
        // Then
        #expect(manager.aiModel == "gpt-4o-mini")
        #expect(manager.temperature == 0.7)
        #expect(manager.maxTokens == 300)
        #expect(manager.apiKey == "")
        #expect(manager.isHighDetail == false)
        #expect(manager.hasLaunched == false)
        #expect(manager.iCloudEnabled == true)
        #expect(manager.isPro == false)
        #expect(manager.hasSeenPaywall == false)
    }
    
    @Test("Test settings persistence")
    func testSettingsPersistence() async throws {
        // Given
        let manager = await createTestManager()
        let defaults = UserDefaults.standard
        
        // When - First clear any existing values
        defaults.removeObject(forKey: "aiModel")
        defaults.removeObject(forKey: "temperature")
        defaults.removeObject(forKey: "maxTokens")
        defaults.removeObject(forKey: "apiKey")
        defaults.removeObject(forKey: "isHighDetail")
        defaults.removeObject(forKey: "hasLaunched")
        defaults.removeObject(forKey: "iCloudEnabled")
        
        // Then set new values
        manager.aiModel = "test-model"
        manager.temperature = 0.9
        manager.maxTokens = 500
        manager.apiKey = "test-key"
        manager.isHighDetail = true
        manager.hasLaunched = true
        manager.iCloudEnabled = false
        
        // Wait for UserDefaults to sync
        try await Task.sleep(for: .milliseconds(100))
        
        // Then verify the values were saved
        let savedAiModel = defaults.string(forKey: "aiModel")
        let savedTemperature = defaults.double(forKey: "temperature")
        let savedMaxTokens = defaults.integer(forKey: "maxTokens")
        let savedApiKey = defaults.string(forKey: "apiKey")
        let savedIsHighDetail = defaults.bool(forKey: "isHighDetail")
        let savedHasLaunched = defaults.bool(forKey: "hasLaunched")
        let savedICloudEnabled = defaults.bool(forKey: "iCloudEnabled")
        
        #expect(savedAiModel == "test-model")
        #expect(savedTemperature == 0.9)
        #expect(savedMaxTokens == 500)
        #expect(savedApiKey == "test-key")
        #expect(savedIsHighDetail == true)
        #expect(savedHasLaunched == true)
        #expect(savedICloudEnabled == false)
    }
    
    @Test("Test Pro feature checks")
    func testProFeatureChecks() async {
        // Given
        let manager = await createTestManager()
        
        // When - Free tier
        #expect(manager.shouldShowPaywall() == true)
        #expect(manager.shouldShowPaywallForAI() == true)
        #expect(manager.shouldShowPaywallForCamera() == true)
        #expect(manager.hasReachedItemLimit(currentCount: SettingsManager.maxFreeItems) == true)
        #expect(manager.hasReachedLocationLimit(currentCount: SettingsManager.maxFreeLocations) == true)
        #expect(manager.canAddMoreItems(currentCount: SettingsManager.maxFreeItems - 1) == true)
        #expect(manager.canAddMoreItems(currentCount: SettingsManager.maxFreeItems) == false)
        #expect(manager.canAddMorePhotos(currentCount: SettingsManager.maxFreePhotosPerItem) == false)
        #expect(manager.canAccessICloudSync() == false)
        
        // When - Pro tier
        manager.isPro = true
        #expect(manager.shouldShowPaywall() == false)
        #expect(manager.shouldShowPaywallForAI() == false)
        #expect(manager.shouldShowPaywallForCamera() == false)
        #expect(manager.hasReachedItemLimit(currentCount: 100) == false)
        #expect(manager.hasReachedLocationLimit(currentCount: 10) == false)
        #expect(manager.canAddMoreItems(currentCount: 1000) == true)
        #expect(manager.canAddMorePhotos(currentCount: 10) == true)
        #expect(manager.canAccessICloudSync() == true)
    }
    
    @Test("Test reset functionality")
    func testResetToDefaults() async {
        // Given
        let manager = await createTestManager()
        
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
        let manager = await createTestManager()
        
        // When/Then - First time triggers
        #expect(manager.shouldShowFirstTimePaywall(itemCount: 0) == true)
        #expect(manager.shouldShowFirstLocationPaywall(locationCount: 0) == true)
        
        // When - Mark paywall as seen
        manager.hasSeenPaywall = true
        
        // Then - Should not show first time paywalls
        #expect(manager.shouldShowFirstTimePaywall(itemCount: 0) == false)
        #expect(manager.shouldShowFirstLocationPaywall(locationCount: 0) == false)
    }
    
    @Test("Test last sync date persistence")
    func testLastSyncDatePersistence() async throws {
        // Given
        let manager = await createTestManager()
        let testDate = Date()
        
        // When
        manager.lastiCloudSync = testDate
        
        // Wait for UserDefaults to sync
        try await Task.sleep(for: .milliseconds(100))
        
        // Then - Compare the actual saved date to the test date
        if let savedDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            let timeIntervalDifference = abs(savedDate.timeIntervalSince1970 - testDate.timeIntervalSince1970)
            #expect(timeIntervalDifference < 1.0, "Dates should be within 1 second of each other")
        } else {
            #expect(false, "No date was saved")
        }
        #expect(UserDefaults.standard.object(forKey: "lastSyncDate") as? Date != nil)
    }
    
    @Test("Test API key validation")
    func testAPIKeyValidation() async {
        // Given
        let manager = await createTestManager()
        
        // When - Set empty key
        manager.apiKey = ""
        #expect(manager.apiKey.isEmpty)
        
        // When - Set valid key
        manager.apiKey = "sk-1234567890"
        #expect(manager.apiKey == "sk-1234567890")
    }
    
    @Test("Test Pro feature access with UI testing flag")
    func testProFeatureUITestingFlag() async {
        // Given
        let manager = await createTestManager()
        
        // When - Simulate UI testing environment
        let arguments = ["Is-Pro"]
        #if DEBUG
        if arguments.contains("Is-Pro") {
            manager.isPro = true
        }
        #endif
        
        // Then
        #expect(manager.isPro == true, "Pro status should be true")
        #expect(manager.canAccessICloudSync() == true, "Should have iCloud access")
        #expect(manager.canAddMorePhotos(currentCount: 10) == true, "Should be able to add more photos")
        
        // Cleanup
        manager.resetToDefaults()
    }
    
    @Test("Test edge cases for first-time paywall")
    func testFirstTimePaywallEdgeCases() async {
        // Given
        let manager = await createTestManager()
        
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
}
