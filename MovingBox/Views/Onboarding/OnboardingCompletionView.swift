import SwiftUI

struct OnboardingCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var manager: OnboardingManager
    
    @StateObject private var settingsManager = SettingsManager()
    @State private var showCheckmark = false
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack {
                        // Success Icon
                        Image(systemName: showCheckmark ? "checkmark.circle" : "circle" )
                            .font(.system(size: 100))
                            .foregroundStyle(.green)
                            .padding()
                            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
                        OnboardingHeaderText(text: "Great Job!")
                        
                        VStack(spacing: 16) {
                            OnboardingDescriptionText(text: "You've taken the first step in protecting what matters most.")
                            
                            // Tips Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tips for Success")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                TipRow(icon: "tortoise.fill",
                                      text: "Take it at your own pace")
                                
                                TipRow(icon: "clock.fill",
                                      text: "Add a few items each day")
                                
                                TipRow(icon: "house.fill",
                                      text: "Go room by room to stay organized")
                            }
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        }
                    }
                }
                
                Spacer()
                
                OnboardingContinueButton(action: completeOnboarding, title: "Get Started")
            }
        }
        .onboardingBackground()
        .onAppear {
            showCheckmark = true
        }
    }
    
    private func completeOnboarding() {
        if settingsManager.isPro {
            manager.markOnboardingComplete()
            dismiss()
        } else {
            manager.currentStep = .paywall
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

#Preview {
    OnboardingCompletionView()
        .environmentObject(OnboardingManager())
}
