import Testing
import SwiftData
import Foundation
@testable import MovingBox

@Suite struct OnboardingManagerTests {
    
    // Helper function to create clean instance
    func createTestManager() -> OnboardingManager {
        let manager = OnboardingManager()
        return manager
    }
    
    // Helper to reset UserDefaults state
    func resetUserDefaults() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        UserDefaults.standard.synchronize()
    }
    
    @Test("Test default initialization")
    func testDefaultInitialization() {
        resetUserDefaults()
        // Given
        let manager = createTestManager()
        
        // Then
        #expect(manager.currentStep == .welcome)
        #expect(manager.showAlert == false)
        #expect(manager.alertMessage.isEmpty)
        #expect(manager.hasCompleted == false)
    }
    
    @Test("Test navigation between steps")
    func testStepNavigation() {
        resetUserDefaults()
        // Given
        let manager = createTestManager()
        
        // When - Move forward
        manager.moveToNext()
        #expect(manager.currentStep == .homeDetails)
        
        manager.moveToNext()
        #expect(manager.currentStep == .location)
        
        manager.moveToNext()
        #expect(manager.currentStep == .item)
        
        // When - Move backward
        manager.moveToPrevious()
        #expect(manager.currentStep == .location)
        
        manager.moveToPrevious()
        #expect(manager.currentStep == .homeDetails)
    }
    
    @Test("Test completion marking")
    func testCompletionMarking() async throws {
        // Given
        resetUserDefaults()
        let manager = createTestManager()
        let defaults = UserDefaults.standard
        
        // Then - Should start as not completed
        #expect(defaults.bool(forKey: OnboardingManager.hasCompletedOnboardingKey) == false, "Should start as not completed")
        
        // When - Mark as completed
        manager.markOnboardingComplete()
        
        // Then - Should be completed
        #expect(manager.hasCompleted, "Manager should be marked as completed")
    }
    
    @Test("Test welcome screen conditions")
    func testWelcomeScreenConditions() async throws {
        // Given - Reset state thoroughly
        resetUserDefaults()
        
        // Explicitly set initial state
        UserDefaults.standard.set(false, forKey: OnboardingManager.hasLaunchedKey)
        UserDefaults.standard.set(false, forKey: OnboardingManager.hasCompletedOnboardingKey)
        UserDefaults.standard.synchronize()
        
        // Verify initial state
        let initialShouldShow = OnboardingManager.shouldShowWelcome()
        #expect(initialShouldShow == true, "Should show welcome initially")
        #expect(UserDefaults.standard.bool(forKey: OnboardingManager.hasLaunchedKey) == false, "Should start with no launch flag")
        
        // Create manager after setting initial state
        let onboardingManager = OnboardingManager()
        onboardingManager.markOnboardingComplete()
        
        // Force synchronization
        UserDefaults.standard.synchronize()
        
        // Create new UserDefaults instance to force a fresh read
        let defaults = UserDefaults.standard
        defaults.synchronize()
        
        let finalHasLaunched = defaults.bool(forKey: OnboardingManager.hasLaunchedKey)
        #expect(finalHasLaunched == true, "Launch flag should be set")
        
        let finalShouldShow = OnboardingManager.shouldShowWelcome()
        #expect(finalShouldShow == false, "Should not show welcome after launch")
        
        // Additional verification
        #expect(defaults.bool(forKey: OnboardingManager.hasCompletedOnboardingKey) == true, "Completion flag should be set")
    }
    
    @Test("Test error handling")
    func testErrorHandling() async {
        resetUserDefaults()
        // Given
        let manager = createTestManager()
        
        // When
        await manager.showError(message: "Test error")
        
        // Then
        #expect(manager.showAlert == true)
        #expect(manager.alertMessage == "Test error")
    }
    
    @Test("Test onboarding state check")
    func testOnboardingStateCheck() async throws {
        resetUserDefaults()
        
        // Given
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Home.self, configurations: config)
        let context = ModelContext(container)
        
        // First clear any existing values
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedOnboardingKey)
        UserDefaults.standard.synchronize()
        
        // When - No homes
        let initialState = try await OnboardingManager.checkAndUpdateOnboardingState(modelContext: context)
        #expect(initialState == false, "Should be false with no homes")
        
        // When - Add a home
        let home = Home(name: "Test Home")
        context.insert(home)
        try context.save()
        
        // Function to verify home exists
        func verifyHomeExists() throws -> Bool {
            let descriptor = FetchDescriptor<Home>()
            return try context.fetch(descriptor).count > 0
        }
        
        // Wait for the save with verification
        for _ in 0...10 {
            if try verifyHomeExists() {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Verify the home was saved
        let homes = try context.fetch(FetchDescriptor<Home>())
        #expect(homes.count == 1, "Should have one home")
        
        // Then - Should complete onboarding
        let updatedState = try await OnboardingManager.checkAndUpdateOnboardingState(modelContext: context)
        #expect(updatedState == true, "Should be true after adding a home")
        
        // Cleanup
        try context.delete(model: Home.self)
    }
    
    @Test("Test step title mapping")
    func testStepTitles() {
        resetUserDefaults()
        // Given
        let steps = OnboardingManager.OnboardingStep.allCases
        
        // Then
        #expect(steps[0].title == "Welcome")
        #expect(steps[1].title == "Home Details")
        #expect(steps[2].title == "Add Location")
        #expect(steps[3].title == "Add Item")
        #expect(steps[4].title == "Great Job!")
    }
}
