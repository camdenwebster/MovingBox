import SwiftData
import SwiftUI

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager()
    @Binding var isPresented: Bool
    @State private var hasCheckedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: SettingsManager
    
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
                            
                            // Check for existing homes and complete onboarding if found
                            do {
                                let hasExistingData = try await OnboardingManager.checkAndUpdateOnboardingState(modelContext: modelContext)
                                if hasExistingData {
                                    manager.markOnboardingComplete()
                                }
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
        .environmentObject(settings)
        .tint(Color.customPrimary)
        .onChange(of: manager.hasCompleted) { _, completed in
            if completed {
                settings.hasLaunched = true
                isPresented = false
            }
        }
    }
    
    private var shouldShowSkipButton: Bool {
        switch manager.currentStep {
        case .welcome, .completion:
            return false
        case .homeDetails, .location, .item:
            return true
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
