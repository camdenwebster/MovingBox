import RevenueCatUI
import SwiftUI

struct OnboardingCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    @Binding var isPresented: Bool
    @StateObject private var settingsManager = SettingsManager()
    @State private var showCheckmark = false
    @State private var showTransition = false
    @State private var showingPaywall = false
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                VStack {
                    VStack {
                        // Success Icon
                        Image(systemName: showCheckmark ? "checkmark.circle" : "circle" )
                            .font(.system(size: 100))
                            .foregroundStyle(.green)
                            .padding()
                            .animation(.default, value: showCheckmark)
                            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
                        
                        OnboardingHeaderText(text: "Great Job!")
                        
                        VStack(spacing: 16) {
                            OnboardingDescriptionText(text: "You've taken the first step in protecting what matters most.")
                            
                            // Tips Section
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Tips for Success")
                                        .font(.headline)
                                        .padding(.bottom, 4)
                                    
                                    OnboardingFeatureRow(
                                        icon: "tortoise.fill",
                                        title: "Take it at your own pace",
                                        description: "It's a marathon, not a sprint!"
                                    )
                                    
                                    OnboardingFeatureRow(
                                        icon: "clock.fill",
                                        title: "Add a few items each day",
                                        description: "Consistency is key"
                                    )
                                    
                                    OnboardingFeatureRow(
                                        icon: "house.fill",
                                        title: "Go room by room to stay organized",
                                        description: "You'll be done in no time"
                                    )
                                }
                                .padding(20)
                                .background {
                                    RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                                        .fill(.ultraThinMaterial)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
                
                OnboardingContinueButton(action: completeOnboarding, title: "Get Started")
                    .accessibilityIdentifier("onboarding-completion-continue-button")
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
            }
            .sheet(isPresented: $showingPaywall, onDismiss: {
                print("📱 OnboardingCompletionView - Paywall sheet dismissed")
                finishOnboarding()
            }) {
                revenueCatManager.presentPaywall(
                    isPresented: $showingPaywall,
                    onCompletion: {
                        print("📱 OnboardingCompletionView - Purchase completed")
                        finishOnboarding()
                    },
                    onDismiss: {
                        print("📱 OnboardingCompletionView - Paywall dismissed via close button")
                        finishOnboarding()
                    }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showCheckmark = true
            }
        }
    }
    
    private func completeOnboarding() {
        print("📱 OnboardingCompletionView - completeOnboarding called")
        if settingsManager.isPro {
            finishOnboarding()
        } else {
            showingPaywall = true
        }
    }
    
    private func finishOnboarding() {
        print("📱 OnboardingCompletionView - finishOnboarding called")
        withAnimation {
            manager.markOnboardingComplete()
            isPresented = false
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.customPrimary)
                .frame(width: 24, height: 12)
            Text(text)
                .font(.subheadline)
        }
    }
}

// Helper to conditionally apply view modifiers
struct AnyViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

#Preview {
    OnboardingCompletionView(isPresented: .constant(true))
        .environmentObject(OnboardingManager())
        .environmentObject(RevenueCatManager.shared)
}
