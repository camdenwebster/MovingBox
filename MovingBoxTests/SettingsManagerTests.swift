import Testing
import Foundation

@testable import MovingBox

@Suite struct SettingsManagerTests {
    
    // Helper function to create clean instance
    func createTestManager() -> SettingsManager {
        let manager = SettingsManager()
        manager.resetToDefaults()
        return manager
    }
    
    @Test("Test default initialization")
    func testDefaultInitialization() {
        // Given
        let manager = createTestManager()
        
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
        let manager = createTestManager()
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
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then verify the values were saved
        #expect(manager.aiModel == "test-model")
        #expect(manager.temperature == 0.9)
        #expect(manager.maxTokens == 500)
        #expect(manager.apiKey == "test-key")
        #expect(manager.isHighDetail == true)
        #expect(manager.hasLaunched == true)
        #expect(manager.iCloudEnabled == false)
    }
    
    @Test("Test Pro feature checks")
    func testProFeatureChecks() {
        // Given
        let manager = createTestManager()
        
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
    func testResetToDefaults() {
        // Given
        let manager = createTestManager()
        
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
    func testPaywallTriggers() {
        // Given
        let manager = createTestManager()
        
        // When/Then - First time triggers
        #expect(manager.shouldShowFirstTimePaywall(itemCount: 0) == true)
        #expect(manager.shouldShowFirstLocationPaywall(locationCount: 0) == true)
        
        // When - Mark paywall as seen
        manager.hasSeenPaywall = true
        
        // Then - Should not show first time paywalls
        #expect(manager.shouldShowFirstTimePaywall(itemCount: 0) == false)
        #expect(manager.shouldShowFirstLocationPaywall(locationCount: 0) == false)
    }
}
