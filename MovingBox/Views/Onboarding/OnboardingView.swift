import SwiftData
import SwiftUI

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager()
    @Binding var isPresented: Bool
    @State private var hasCheckedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Content
                VStack(spacing: 0) {
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
                    case .notifications:
                        OnboardingNotificationsView()
                            .transition(manager.transition)
                    case .completion:
                        OnboardingCompletionView(isPresented: $isPresented)
                            .transition(manager.transition)
                    }
                    
                    if OnboardingManager.OnboardingStep.navigationSteps.contains(manager.currentStep) {
                        StepIndicator(totalSteps: OnboardingManager.OnboardingStep.navigationSteps.count,
                                    currentStep: OnboardingManager.OnboardingStep.navigationSteps.firstIndex(of: manager.currentStep) ?? 0)
                    }
                }
            }
            .onboardingBackground()
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
        
        .alert(manager.alertMessage, isPresented: $manager.showAlert) {
            Button("OK", role: .cancel) { }
        }
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
        case .homeDetails, .location, .item, .notifications:
            return true
        }
    }
}

struct StepIndicator: View {
    let totalSteps: Int
    let currentStep: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? .green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: currentStep)
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
