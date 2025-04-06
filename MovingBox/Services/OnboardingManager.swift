import Foundation
import SwiftUI

class OnboardingManager: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published private var isMovingForward = true
    
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    
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
    
    func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedOnboardingKey)
    }
    
    static func hasCompletedOnboarding() -> Bool {
        UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }
    
    func moveToNext() {
        if let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
           currentIndex + 1 < OnboardingStep.allCases.count {
            isMovingForward = true
            withAnimation(.easeInOut) {
                currentStep = OnboardingStep.allCases[currentIndex + 1]
            }
        }
    }
    
    func moveToPrevious() {
        if let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
           currentIndex > 0 {
            isMovingForward = false
            withAnimation(.easeInOut) {
                currentStep = OnboardingStep.allCases[currentIndex - 1]
            }
        }
    }
    
    var transition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isMovingForward ? .trailing : .leading),
            removal: .move(edge: isMovingForward ? .leading : .trailing)
        )
    }
}
