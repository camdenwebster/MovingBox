import SwiftData
import SwiftUI

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager()
    @Binding var isPresented: Bool
    @State private var hasCheckedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            VStack {
                switch manager.currentStep {
                case .welcome:
                    OnboardingWelcomeView()
                        .transition(manager.transition)
                        .task {
                            // Wait briefly for SwiftData sync
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            hasCheckedOnboarding = true
                            
                            // Let data sync happen in background, but don't auto-dismiss
                            // Dismissal will be handled by the welcome view's "Get Started" button
                            do {
                                _ = try await OnboardingManager.checkAndUpdateOnboardingState(modelContext: modelContext)
                            } catch {
                                manager.showError(message: "Unable to check onboarding status. Please try again.")
                            }
                        }
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
                    OnboardingCompletionView(isPresented: $isPresented)
                        .transition(manager.transition)
                case .paywall:
                    MovingBoxPaywallView(isPresented: $isPresented)
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
        .onChange(of: manager.hasCompleted) { _, completed in
            if completed {
                isPresented = false
            }
        }
    }
    
    private var shouldShowSkipButton: Bool {
        switch manager.currentStep {
        case .welcome:
            return false
        case .homeDetails, .location, .item:
            return true
        case .completion, .paywall:
            return false
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
