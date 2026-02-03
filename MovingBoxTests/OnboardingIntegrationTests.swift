//
//  OnboardingIntegrationTests.swift
//  MovingBoxTests
//
//  Integration tests for the complete onboarding flow including survey
//

import Foundation
import SQLiteData
import Testing

@testable import MovingBox

@MainActor
@Suite struct OnboardingIntegrationTests {

    @Test("Complete onboarding flow with survey")
    func testCompleteOnboardingFlowWithSurvey() async throws {
        let manager = OnboardingManager()

        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedOnboardingKey)
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasLaunchedKey)
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedUsageSurveyKey)

        #expect(manager.currentStep == .welcome)
        #expect(!OnboardingManager.hasCompletedOnboarding())
        #expect(OnboardingManager.shouldShowWelcome())

        manager.moveToNext()
        #expect(manager.currentStep == .item)

        manager.moveToNext()
        #expect(manager.currentStep == .notifications)

        manager.moveToNext()
        #expect(manager.currentStep == .survey)

        manager.moveToNext()
        #expect(manager.currentStep == .completion)

        manager.markOnboardingComplete()

        UserDefaults.standard.set(true, forKey: OnboardingManager.hasLaunchedKey)

        #expect(manager.hasCompleted)
        #expect(OnboardingManager.hasCompletedOnboarding())
        #expect(!OnboardingManager.shouldShowWelcome())
    }

    @Test("Onboarding flow with survey skip")
    func testOnboardingFlowWithSurveySkip() async throws {
        let manager = OnboardingManager()

        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedUsageSurveyKey)

        manager.currentStep = .survey

        UserDefaults.standard.set(true, forKey: OnboardingManager.hasCompletedUsageSurveyKey)
        manager.moveToNext()

        #expect(UserDefaults.standard.bool(forKey: OnboardingManager.hasCompletedUsageSurveyKey))
        #expect(manager.currentStep == .completion)
    }

    @Test("Onboarding backward navigation")
    func testOnboardingBackwardNavigation() async throws {
        let manager = OnboardingManager()

        manager.currentStep = .survey

        manager.moveToPrevious()
        #expect(manager.currentStep == .notifications)

        manager.moveToPrevious()
        #expect(manager.currentStep == .item)

        manager.moveToPrevious()
        #expect(manager.currentStep == .welcome)

        manager.moveToPrevious()
        #expect(manager.currentStep == .welcome)
    }

    @Test("Onboarding step boundaries")
    func testOnboardingStepBoundaries() async throws {
        let manager = OnboardingManager()

        manager.currentStep = .completion
        manager.moveToNext()

        #expect(manager.currentStep == .completion)

        manager.currentStep = .welcome
        manager.moveToPrevious()

        #expect(manager.currentStep == .welcome)
    }

    @Test("Onboarding state persistence")
    func testOnboardingStatePersistence() async throws {
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedOnboardingKey)
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasLaunchedKey)
        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedUsageSurveyKey)

        let manager1 = OnboardingManager()

        manager1.markOnboardingComplete()

        UserDefaults.standard.set(true, forKey: OnboardingManager.hasCompletedUsageSurveyKey)

        _ = OnboardingManager()

        #expect(OnboardingManager.hasCompletedOnboarding())
        #expect(UserDefaults.standard.bool(forKey: OnboardingManager.hasCompletedUsageSurveyKey))
    }

    @Test("Onboarding with existing items skips flow")
    func testOnboardingWithExistingItems() async throws {
        let database = try makeInMemoryDatabase()

        UserDefaults.standard.removeObject(forKey: OnboardingManager.hasCompletedOnboardingKey)

        try await database.write { db in
            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(id: UUID(), title: "Existing Item")
            }.execute(db)
        }

        let shouldSkip = try await OnboardingManager.checkAndUpdateOnboardingState(
            database: database)

        #expect(shouldSkip)
        #expect(OnboardingManager.hasCompletedOnboarding())

        try await database.write { db in
            try SQLiteInventoryItem.delete().execute(db)
        }
    }

    @Test("Navigation steps configuration")
    func testNavigationStepsConfiguration() async throws {
        let navigationSteps = OnboardingManager.OnboardingStep.navigationSteps

        #expect(navigationSteps.count == 3)
        #expect(navigationSteps.contains(.item))
        #expect(navigationSteps.contains(.notifications))
        #expect(navigationSteps.contains(.survey))
        #expect(!navigationSteps.contains(.welcome))
        #expect(!navigationSteps.contains(.completion))
    }

    @Test("Step titles are correctly defined")
    func testStepTitles() async throws {
        let steps = OnboardingManager.OnboardingStep.allCases

        #expect(steps.count == 5)

        #expect(OnboardingManager.OnboardingStep.welcome.title == "Welcome")
        #expect(OnboardingManager.OnboardingStep.item.title == "Add Item")
        #expect(OnboardingManager.OnboardingStep.notifications.title == "Stay Updated")
        #expect(OnboardingManager.OnboardingStep.survey.title == "Usage Survey")
        #expect(OnboardingManager.OnboardingStep.completion.title == "Great Job!")
    }

    @Test("UserDefaults key constants are consistent")
    func testUserDefaultsKeyConstants() async throws {
        let keys = [
            OnboardingManager.hasCompletedOnboardingKey,
            OnboardingManager.hasLaunchedKey,
            OnboardingManager.hasCompletedUsageSurveyKey,
        ]

        let uniqueKeys = Set(keys)
        #expect(uniqueKeys.count == keys.count)

        for key in keys {
            #expect(!key.isEmpty)
        }

        #expect(OnboardingManager.hasCompletedOnboardingKey == "hasCompletedOnboardingKey")
        #expect(OnboardingManager.hasLaunchedKey == "hasLaunched")
        #expect(OnboardingManager.hasCompletedUsageSurveyKey == "hasCompletedUsageSurvey")
    }
}
