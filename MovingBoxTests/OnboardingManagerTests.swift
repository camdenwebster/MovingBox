import Foundation
import SQLiteData
import Testing

@testable import MovingBox

@MainActor
@Suite struct OnboardingManagerTests {

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
        }
    }

    @MainActor
    class TestOnboardingManager: ObservableObject {
        @Published var currentStep: OnboardingManager.OnboardingStep = .welcome
        @Published var showAlert = false
        @Published var alertMessage = ""
        @Published private(set) var hasCompleted = false

        private let defaults: TestUserDefaults

        init(defaults: TestUserDefaults) {
            self.defaults = defaults
        }

        func markOnboardingComplete() {
            defaults.set(true, forKey: OnboardingManager.hasCompletedOnboardingKey)
            hasCompleted = true
        }

        func shouldShowWelcome() -> Bool {
            let hasLaunched = defaults.bool(forKey: OnboardingManager.hasLaunchedKey)
            return !hasLaunched
        }

        func moveToNext() {
            if let currentIndex = OnboardingManager.OnboardingStep.allCases.firstIndex(of: currentStep),
                currentIndex + 1 < OnboardingManager.OnboardingStep.allCases.count
            {
                currentStep = OnboardingManager.OnboardingStep.allCases[currentIndex + 1]
            }
        }

        func moveToPrevious() {
            if let currentIndex = OnboardingManager.OnboardingStep.allCases.firstIndex(of: currentStep),
                currentIndex > 0
            {
                currentStep = OnboardingManager.OnboardingStep.allCases[currentIndex - 1]
            }
        }

        func showError(message: String) {
            alertMessage = message
            showAlert = true
        }

        static func checkAndUpdateOnboardingState(
            database: any DatabaseReader, defaults: TestUserDefaults
        ) async throws -> Bool {
            let items = try await database.read { db in
                try SQLiteInventoryItem.fetchAll(db)
            }

            if !items.isEmpty {
                defaults.set(true, forKey: OnboardingManager.hasCompletedOnboardingKey)
                return true
            }
            return false
        }
    }

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

        manager.moveToNext()
        #expect(manager.currentStep == .item)

        manager.moveToNext()
        #expect(manager.currentStep == .notifications)

        manager.moveToNext()
        #expect(manager.currentStep == .survey)

        manager.moveToPrevious()
        #expect(manager.currentStep == .notifications)

        manager.moveToPrevious()
        #expect(manager.currentStep == .item)
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
        #expect(steps[1].title == "Add Item")
        #expect(steps[2].title == "Stay Updated")
        #expect(steps[3].title == "Usage Survey")
        #expect(steps[4].title == "Great Job!")
    }

    @Test("Test welcome screen conditions")
    func testWelcomeScreenConditions() async {
        let (manager, defaults) = createTestEnvironment()

        defaults.set(false, forKey: OnboardingManager.hasLaunchedKey)
        defaults.set(false, forKey: OnboardingManager.hasCompletedOnboardingKey)

        let initialShouldShow = manager.shouldShowWelcome()
        #expect(initialShouldShow, "Should show welcome initially")
        #expect(
            !defaults.bool(forKey: OnboardingManager.hasLaunchedKey), "Should start with no launch flag")

        manager.markOnboardingComplete()
        defaults.set(true, forKey: OnboardingManager.hasLaunchedKey)

        #expect(manager.hasCompleted, "Manager should be marked as completed")
        #expect(
            defaults.bool(forKey: OnboardingManager.hasCompletedOnboardingKey),
            "Completion flag should be set")

        let finalShouldShow = manager.shouldShowWelcome()

        #expect(!finalShouldShow, "Should not show welcome after completing onboarding")
    }

    @Test("Test onboarding state check")
    func testOnboardingStateCheck() async throws {
        let (_, defaults) = createTestEnvironment()

        let database = try makeInMemoryDatabase()

        defaults.removeObject(forKey: OnboardingManager.hasCompletedOnboardingKey)

        let initialState = try await TestOnboardingManager.checkAndUpdateOnboardingState(
            database: database,
            defaults: defaults
        )
        #expect(!initialState, "Should be false with no items")

        try await database.write { db in
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(id: UUID(), title: "Test Item")
            }.execute(db)
        }

        let items = try await database.read { db in
            try SQLiteInventoryItem.fetchAll(db)
        }
        #expect(items.count == 1, "Should have one item")

        let updatedState = try await TestOnboardingManager.checkAndUpdateOnboardingState(
            database: database,
            defaults: defaults
        )
        #expect(updatedState, "Should be true after adding an item")
        #expect(
            defaults.bool(forKey: OnboardingManager.hasCompletedOnboardingKey),
            "Completion flag should be set in defaults")

        try await database.write { db in
            try SQLiteInventoryItem.delete().execute(db)
        }
    }
}
