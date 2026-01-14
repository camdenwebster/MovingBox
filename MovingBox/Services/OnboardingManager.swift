import Foundation
import SwiftData
import SwiftUI
import UserNotifications

@MainActor
class OnboardingManager: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var hasCompleted = false
    @Published private var isMovingForward = true
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case item
        case notifications
        case survey
        case completion

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .item: return "Add Item"
            case .notifications: return "Stay Updated"
            case .survey: return "Usage Survey"
            case .completion: return "Great Job!"
            }
        }

        // Steps that should show in navigation dots (excluding welcome and completion)
        static var navigationSteps: [OnboardingStep] {
            [.item, .notifications, .survey]
        }
    }

    static let hasCompletedOnboardingKey = "hasCompletedOnboardingKey"
    static let hasLaunchedKey = "hasLaunched"
    static let hasCompletedUsageSurveyKey = "hasCompletedUsageSurvey"

    var transition: AnyTransition {
        if isMovingForward {
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading))
        } else {
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing))
        }
    }

    init() {
        print("⚡️ OnboardingManager initialized")
        Task {
            await checkNotificationStatus()
        }
    }

    func markOnboardingComplete() {
        print("⚡️ Marking onboarding as complete")
        UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
        hasCompleted = true
    }

    static func shouldShowWelcome() -> Bool {
        let hasLaunched = UserDefaults.standard.bool(forKey: Self.hasLaunchedKey)
        print("⚡️ shouldShowWelcome check - hasLaunched: \(hasLaunched)")

        if ProcessInfo.processInfo.arguments.contains("Show-Onboarding") {
            return true
        }

        if ProcessInfo.processInfo.arguments.contains("Skip-Onboarding") {
            return false
        }

        return !hasLaunched
    }

    static func hasCompletedOnboarding() -> Bool {
        if ProcessInfo.processInfo.arguments.contains("Show-Onboarding") {
            return false
        }

        if ProcessInfo.processInfo.arguments.contains("Skip-Onboarding") {
            return true
        }

        return UserDefaults.standard.bool(forKey: Self.hasCompletedOnboardingKey)
    }

    @MainActor
    static func checkAndUpdateOnboardingState(modelContext: ModelContext) async throws -> Bool {
        guard
            !hasCompletedOnboarding() && !ProcessInfo.processInfo.arguments.contains("Show-Onboarding")
        else {
            return false
        }

        do {
            let descriptor = FetchDescriptor<InventoryItem>()
            let items = try modelContext.fetch(descriptor)
            print("⚡️ Checking for existing items: \(items.count) found")

            if !items.isEmpty {
                UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
                return true
            }
            return false
        } catch let error as NSError {
            print("❌ Error checking for items: \(error), \(error.userInfo)")
            throw OnboardingError.itemCheckFailed(error)
        }
    }

    enum OnboardingError: LocalizedError {
        case itemCheckFailed(Error)

        var errorDescription: String? {
            switch self {
            case .itemCheckFailed(let error):
                return "Failed to check for existing items: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    func showError(message: String) {
        alertMessage = message
        showAlert = true
    }

    @MainActor
    func requestNotificationPermissions() async {
        do {
            let center = UNUserNotificationCenter.current()
            self.notificationStatus = await center.notificationSettings().authorizationStatus

            if self.notificationStatus == .notDetermined {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                self.notificationStatus = granted ? .authorized : .denied
                // ADD: Move to next step after user responds
                moveToNext()
            }
        } catch {
            print("❌ Error requesting notification permissions: \(error)")
            showError(message: "Could not request notification permissions")
        }
    }

    @MainActor
    func checkNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        self.notificationStatus = await center.notificationSettings().authorizationStatus
    }

    func moveToNext() {
        print("⚡️ Moving to next step from: \(currentStep)")

        if let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
            currentIndex + 1 < OnboardingStep.allCases.count
        {
            isMovingForward = true
            withAnimation(.easeInOut) {
                currentStep = OnboardingStep.allCases[currentIndex + 1]
            }
        }
    }

    func moveToPrevious() {
        print("⚡️ Moving to previous step from: \(currentStep)")

        if let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
            currentIndex > 0
        {
            isMovingForward = false
            withAnimation(.easeInOut) {
                currentStep = OnboardingStep.allCases[currentIndex - 1]
            }
        }
    }
}
