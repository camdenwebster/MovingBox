import Testing
import SwiftData
import Foundation
@testable import MovingBox

@MainActor
@Suite struct OnboardingManagerTests {
    
    // Helper class to mock UserDefaults
    final class TestUserDefaults {
        private var storage: [String: Any] = [:]
        
        func set(_ value: Any?, forKey defaultName: String) {
            storage[defaultName] = value
        }
        
        func bool(forKey defaultName: String) -> Bool {
            return storage[defaultName] as? Bool ?? false
        }
        
        func object(forKey defaultName: String) -> Any? {
            return storage[defaultName]
        }
        
        func removeObject(forKey defaultName: String) {
            storage.removeValue(forKey: defaultName)
        }
        
        func synchronize() {
            // No-op for test environment
        }
    }
    
    // Test wrapper for OnboardingManager that uses our test defaults
    @MainActor
    class TestOnboardingManager: ObservableObject {
        @Published var currentStep: OnboardingManager.OnboardingStep = .welcome
        @Published var showAlert = false
        @Published var alertMessage = ""
        @Published private(set) var hasCompleted = false
        
        private let defaults: TestUserDefaults
        
        init(defaults: TestUserDefaults) {
            self.defaults = defaults
            print("⚡️ TestOnboardingManager initialized")
        }
        
        func markOnboardingComplete() {
            print("⚡️ Marking onboarding as complete")
            defaults.set(true, forKey: OnboardingManager.hasCompletedOnboardingKey)
            hasCompleted = true
        }
        
        func shouldShowWelcome() -> Bool {
            let hasLaunched = defaults.bool(forKey: OnboardingManager.hasLaunchedKey)
            print("⚡️ shouldShowWelcome check - hasLaunched: \(hasLaunched)")
            return !hasLaunched
        }
        
        func moveToNext() {
            if let currentIndex = OnboardingManager.OnboardingStep.allCases.firstIndex(of: currentStep),
               currentIndex + 1 < OnboardingManager.OnboardingStep.allCases.count {
                currentStep = OnboardingManager.OnboardingStep.allCases[currentIndex + 1]
            }
        }
        
        func moveToPrevious() {
            if let currentIndex = OnboardingManager.OnboardingStep.allCases.firstIndex(of: currentStep),
               currentIndex > 0 {
                currentStep = OnboardingManager.OnboardingStep.allCases[currentIndex - 1]
            }
        }
        
        func showError(message: String) {
            alertMessage = message
            showAlert = true
        }
        
        static func checkAndUpdateOnboardingState(modelContext: ModelContext, defaults: TestUserDefaults) throws -> Bool {
            do {
                let descriptor = FetchDescriptor<Home>()
                let homes = try modelContext.fetch(descriptor)
                print("⚡️ Checking for existing homes: \(homes.count) found")
                
                if !homes.isEmpty {
                    defaults.set(true, forKey: OnboardingManager.hasCompletedOnboardingKey)
                    return true
                }
                return false
            } catch let error as NSError {
                print("❌ Error checking for homes: \(error), \(error.userInfo)")
                throw OnboardingManager.OnboardingError.homeCheckFailed(error)
            }
        }
    }
    
    // Helper function to create clean test environment
    func createTestEnvironment() -> (manager: TestOnboardingManager, defaults: TestUserDefaults) {
        let defaults = TestUserDefaults()
        let manager = TestOnboardingManager(defaults: defaults)
        return (manager, defaults)
    }
    
    @Test("Test default initialization")
    func testDefaultInitialization() async {
        let (manager, _) = createTestEnvironment()
        
        #expect(manager.currentStep == .welcome)
        #expect(!manager.showAlert)
        #expect(manager.alertMessage.isEmpty)
        #expect(!manager.hasCompleted)
    }
    
    @Test("Test navigation between steps")
    func testStepNavigation() async {
        let (manager, _) = createTestEnvironment()
        
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
    
    @Test("Test error handling")
    func testErrorHandling() async {
        let (manager, _) = createTestEnvironment()
        
        manager.showError(message: "Test error")
        
        #expect(manager.showAlert)
        #expect(manager.alertMessage == "Test error")
    }
    
    @Test("Test step title mapping")
    func testStepTitles() async {
        let steps = OnboardingManager.OnboardingStep.allCases
        
        #expect(steps[0].title == "Welcome")
        #expect(steps[1].title == "Home Details")
        #expect(steps[2].title == "Add Location")
        #expect(steps[3].title == "Add Item")
        #expect(steps[4].title == "Stay Updated")
        #expect(steps[5].title == "Great Job!")
    }
    
    @Test("Test welcome screen conditions")
    func testWelcomeScreenConditions() async {
        // Given - Create test environment
        let (manager, defaults) = createTestEnvironment()
        
        // Set initial state explicitly to false
        defaults.set(false, forKey: OnboardingManager.hasLaunchedKey)
        defaults.set(false, forKey: OnboardingManager.hasCompletedOnboardingKey)
        
        // When/Then - Check initial state
        let initialShouldShow = manager.shouldShowWelcome()
        #expect(initialShouldShow, "Should show welcome initially")
        #expect(!defaults.bool(forKey: OnboardingManager.hasLaunchedKey), "Should start with no launch flag")
        
        // When - Complete onboarding
        manager.markOnboardingComplete()
        defaults.set(true, forKey: OnboardingManager.hasLaunchedKey)
        
        // Then - Verify states are updated
        #expect(manager.hasCompleted, "Manager should be marked as completed")
        #expect(defaults.bool(forKey: OnboardingManager.hasCompletedOnboardingKey), "Completion flag should be set")
        
        // When - Check final welcome screen state
        let finalShouldShow = manager.shouldShowWelcome()
        
        // Then - Should not show welcome anymore
        #expect(!finalShouldShow, "Should not show welcome after completing onboarding")
    }
    
    @Test("Test onboarding state check")
    func testOnboardingStateCheck() async throws {
        // Given
        let (_, defaults) = createTestEnvironment()
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Home.self, configurations: config)
        let context = ModelContext(container)
        
        defaults.removeObject(forKey: OnboardingManager.hasCompletedOnboardingKey)
        
        // Test with no homes
        let initialState = try TestOnboardingManager.checkAndUpdateOnboardingState(
            modelContext: context,
            defaults: defaults
        )
        #expect(!initialState, "Should be false with no homes")
        
        // Add a home
        let home = Home(name: "Test Home")
        context.insert(home)
        try context.save()
        
        // Verify home was saved
        let homes = try context.fetch(FetchDescriptor<Home>())
        #expect(homes.count == 1, "Should have one home")
        
        // Test with home
        let updatedState = try TestOnboardingManager.checkAndUpdateOnboardingState(
            modelContext: context,
            defaults: defaults
        )
        #expect(updatedState, "Should be true after adding a home")
        #expect(defaults.bool(forKey: OnboardingManager.hasCompletedOnboardingKey),
               "Completion flag should be set in defaults")
        
        // Cleanup
        try context.delete(model: Home.self)
    }
}
