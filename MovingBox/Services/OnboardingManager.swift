import Foundation
import SwiftUI
import SwiftData

class OnboardingManager: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var hasCompleted = false
    @Published private var isMovingForward = true
    
    static let hasCompletedOnboardingKey = "hasCompletedOnboardingKey"
    static let hasLaunchedKey = "hasLaunchedKey"
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case homeDetails
        case location
        case item
        case completion
        case paywall
        
        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .homeDetails: return "Home Details"
            case .location: return "Add Location"
            case .item: return "Add Item"
            case .completion: return "Great Job!"
            case .paywall: return "MovingBox Pro"
            }
        }
    }
    
    var transition: AnyTransition {
        if isMovingForward {
            return .asymmetric(insertion: .move(edge: .trailing),
                              removal: .move(edge: .leading))
        } else {
            return .asymmetric(insertion: .move(edge: .leading),
                              removal: .move(edge: .trailing))
        }
    }
    
    init() {
        print("⚡️ OnboardingManager initialized")
    }
    
    func markOnboardingComplete() {
        print("⚡️ Marking onboarding as complete")
        UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
        hasCompleted = true
    }
    
    static func shouldShowWelcome() -> Bool {
        if ProcessInfo.processInfo.arguments.contains("Show-Onboarding") {
            return true
        }
        
        if ProcessInfo.processInfo.arguments.contains("Skip-Onboarding") {
            return false
        }
        
        return !UserDefaults.standard.bool(forKey: hasLaunchedKey)
    }
    
    static func hasCompletedOnboarding() -> Bool {
        if ProcessInfo.processInfo.arguments.contains("Show-Onboarding") {
            return false
        }
        
        if ProcessInfo.processInfo.arguments.contains("Skip-Onboarding") {
            return true
        }
        
        return UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }
    
    @MainActor
    static func checkAndUpdateOnboardingState(modelContext: ModelContext) async throws -> Bool {
        // Only check homes if onboarding hasn't been completed yet
        if !hasCompletedOnboarding() {
            do {
                let descriptor = FetchDescriptor<Home>()
                let homes = try modelContext.fetch(descriptor)
                print("⚡️ Checking for existing homes: \(homes.count) found")
                
                // If we found homes, we should complete onboarding
                return !homes.isEmpty
            } catch {
                print("❌ Error checking for homes: \(error)")
                throw OnboardingError.homeCheckFailed(error)
            }
        }
        return false
    }
    
    enum OnboardingError: LocalizedError {
        case homeCheckFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .homeCheckFailed(let error):
                return "Failed to check for existing homes: \(error.localizedDescription)"
            }
        }
    }
    
    @MainActor
    func showError(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    func moveToNext() {
        print("⚡️ Moving to next step from: \(currentStep)")
        
        if let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
           currentIndex + 1 < OnboardingStep.allCases.count {
            isMovingForward = true
            withAnimation(.easeInOut) {
                currentStep = OnboardingStep.allCases[currentIndex + 1]
            }
        }
    }
    
    func moveToPrevious() {
        print("⚡️ Moving to previous step from: \(currentStep)")
        
        if let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
           currentIndex > 0 {
            isMovingForward = false
            withAnimation(.easeInOut) {
                currentStep = OnboardingStep.allCases[currentIndex - 1]
            }
        }
    }
}
