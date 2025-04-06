import SwiftUI

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager()
    @Environment(\.dismiss) private var dismiss
    @State private var isProSubscriber = false
    
    var body: some View {
        NavigationStack {
            VStack {
                switch manager.currentStep {
                case .welcome:
                    OnboardingWelcomeView()
                        .transition(manager.transition)
                case .homeDetails:
                    OnboardingHomeView()
                        .transition(manager.transition)
                case .location:
                    OnboardingLocationView()
                        .transition(manager.transition)
                case .item:
                    OnboardingItemView()
                        .transition(manager.transition)
                case .completion:
                    OnboardingCompletionView()
                        .transition(manager.transition)
                case .paywall:
                    MovingBoxPaywallView()
                        .transition(manager.transition)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if manager.currentStep != .welcome {
                        Button("Back") {
                            manager.moveToPrevious()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if shouldShowSkipButton {
                        Button("Skip") {
                            manager.moveToNext()
                        }
                    }
                }
            }
        }
        .environmentObject(manager)
        .tint(Color.customPrimary)
    }
    
    private var shouldShowSkipButton: Bool {
        switch manager.currentStep {
        case .welcome, .homeDetails, .location, .item:
            return true
        case .completion, .paywall:
            return false
        }
    }
}

#Preview {
    OnboardingView()
}
