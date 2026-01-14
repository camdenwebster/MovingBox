//
//  OnboardingIntegrationTests.swift
//  MovingBoxTests
//
//  Integration tests for the complete onboarding flow including survey
//

import Foundation
import SwiftData
import Testing

@testable import MovingBox

@MainActor
@Suite struct OnboardingIntegrationTests {

    // Test the complete onboarding flow with survey completion
    @Test("Complete onboarding flow with survey")
    func testCompleteOnboardingFlowWithSurvey() async throws {
        // Given - Clean environment
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, configurations: config)
        _ = ModelContext(container)

        let manager = OnboardingManager()

        // Reset UserDefaults to clean state
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedOnboardingKey)
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasLaunchedKey)
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedUsageSurveyKey)

        // Verify initial state
        #expect(manager.currentStep == .welcome)
        #expect(!OnboardingManager.hasCompletedOnboarding())
        #expect(OnboardingManager.shouldShowWelcome())

        // When - Navigate through complete flow

        // Step 1: Welcome -> Item
        manager.moveToNext()
        #expect(manager.currentStep == .item)

        // Step 2: Item -> Notifications
        manager.moveToNext()
        #expect(manager.currentStep == .notifications)

        // Step 3: Notifications -> Survey
        manager.moveToNext()
        #expect(manager.currentStep == .survey)

        // Step 4: Survey -> Completion
        manager.moveToNext()
        #expect(manager.currentStep == .completion)

        // Step 5: Complete onboarding
        manager.markOnboardingComplete()

        // Mark as launched to complete the welcome flow
        UserDefaults.standard.set(true, forKey: OnboardingManager.hasLaunchedKey)

        // Then - Verify final state
        #expect(manager.hasCompleted)
        #expect(OnboardingManager.hasCompletedOnboarding())
        #expect(!OnboardingManager.shouldShowWelcome())  // Should be false after marking launched
    }

    @Test("Onboarding flow with survey skip")
    func testOnboardingFlowWithSurveySkip() async throws {
        // Given - Clean environment
        let manager = OnboardingManager()

        // Reset UserDefaults
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedUsageSurveyKey)

        // Navigate to survey step
        manager.currentStep = .survey

        // When - Skip survey (simulating handleSkip behavior)
        UserDefaults.standard.set(true, forKey: OnboardingManager.hasCompletedUsageSurveyKey)
        manager.moveToNext()

        // Then - Verify survey was marked as completed even when skipped
        #expect(UserDefaults.standard.bool(forKey: OnboardingManager.hasCompletedUsageSurveyKey))
        #expect(manager.currentStep == .completion)
    }

    @Test("Onboarding backward navigation")
    func testOnboardingBackwardNavigation() async throws {
        // Given
        let manager = OnboardingManager()

        // Navigate to survey step
        manager.currentStep = .survey

        // When - Move backward
        manager.moveToPrevious()
        #expect(manager.currentStep == .notifications)

        manager.moveToPrevious()
        #expect(manager.currentStep == .item)

        manager.moveToPrevious()
        #expect(manager.currentStep == .welcome)

        // Then - Verify cannot go before welcome
        manager.moveToPrevious()
        #expect(manager.currentStep == .welcome)  // Should remain at welcome
    }

    @Test("Onboarding step boundaries")
    func testOnboardingStepBoundaries() async throws {
        // Given
        let manager = OnboardingManager()

        // When - At completion, cannot move forward
        manager.currentStep = .completion
        manager.moveToNext()

        // Then - Should remain at completion
        #expect(manager.currentStep == .completion)

        // When - At welcome, cannot move backward
        manager.currentStep = .welcome
        manager.moveToPrevious()

        // Then - Should remain at welcome
        #expect(manager.currentStep == .welcome)
    }

    @Test("Onboarding state persistence")
    func testOnboardingStatePersistence() async throws {
        // Given - Clean state
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedOnboardingKey)
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasLaunchedKey)
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedUsageSurveyKey)

        let manager1 = OnboardingManager()

        // When - Complete onboarding with first manager
        manager1.markOnboardingComplete()

        // Mark survey as completed
        UserDefaults.standard.set(true, forKey: OnboardingManager.hasCompletedUsageSurveyKey)

        // Create new manager instance
        _ = OnboardingManager()

        // Then - State should persist
        #expect(OnboardingManager.hasCompletedOnboarding())
        #expect(UserDefaults.standard.bool(forKey: OnboardingManager.hasCompletedUsageSurveyKey))
    }

    @Test("Onboarding with existing items skips flow")
    func testOnboardingWithExistingItems() async throws {
        // Given - Environment with existing items
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryItem.self, configurations: config)
        let context = ModelContext(container)

        // Reset onboarding state
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedOnboardingKey)

        // Add an item to skip onboarding
        let item = InventoryItem(title: "Existing Item")
        context.insert(item)
        try context.save()

        // When - Check onboarding state
        let shouldSkip = try await OnboardingManager.checkAndUpdateOnboardingState(
            modelContext: context)

        // Then - Should automatically complete onboarding
        #expect(shouldSkip)
        #expect(OnboardingManager.hasCompletedOnboarding())

        // Cleanup
        try context.delete(model: InventoryItem.self)
    }

    @Test("Navigation steps configuration")
    func testNavigationStepsConfiguration() async throws {
        // Given
        let navigationSteps = OnboardingManager.OnboardingStep.navigationSteps

        // Then - Should only include steps that show in navigation
        #expect(navigationSteps.count == 3)
        #expect(navigationSteps.contains(.item))
        #expect(navigationSteps.contains(.notifications))
        #expect(navigationSteps.contains(.survey))
        #expect(!navigationSteps.contains(.welcome))  // Welcome should not show in navigation
        #expect(!navigationSteps.contains(.completion))  // Completion should not show in navigation
    }

    @Test("Step titles are correctly defined")
    func testStepTitles() async throws {
        let steps = OnboardingManager.OnboardingStep.allCases

        #expect(steps.count == 5)  // Verify we have all expected steps

        #expect(OnboardingManager.OnboardingStep.welcome.title == "Welcome")
        #expect(OnboardingManager.OnboardingStep.item.title == "Add Item")
        #expect(OnboardingManager.OnboardingStep.notifications.title == "Stay Updated")
        #expect(OnboardingManager.OnboardingStep.survey.title == "Usage Survey")
        #expect(OnboardingManager.OnboardingStep.completion.title == "Great Job!")
    }

    @Test("UserDefaults key constants are consistent")
    func testUserDefaultsKeyConstants() async throws {
        // Verify all key constants are properly defined and don't conflict
        let keys = [
            OnboardingManager.hasCompletedOnboardingKey,
            OnboardingManager.hasLaunchedKey,
            OnboardingManager.hasCompletedUsageSurveyKey,
        ]

        // All keys should be unique
        let uniqueKeys = Set(keys)
        #expect(uniqueKeys.count == keys.count)

        // Keys should not be empty
        for key in keys {
            #expect(!key.isEmpty)
        }

        // Verify specific expected values
        #expect(OnboardingManager.hasCompletedOnboardingKey == "hasCompletedOnboardingKey")
        #expect(OnboardingManager.hasLaunchedKey == "hasLaunched")
        #expect(OnboardingManager.hasCompletedUsageSurveyKey == "hasCompletedUsageSurvey")
    }
}
