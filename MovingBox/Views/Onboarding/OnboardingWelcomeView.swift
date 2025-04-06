import SwiftUI

struct OnboardingWelcomeView: View {
    @EnvironmentObject private var manager: OnboardingManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack {
                        Image(colorScheme == .dark ? "onboardingDark" : "onboardingLight")
                            .resizable()
                            .scaledToFit()
                            .frame(minHeight: 200, maxHeight: 400)
                            .padding(.horizontal, 32)
                            .padding(.vertical)
                        
                        VStack {
                            Text("Welcome to")
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Text("MovingBox")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        OnboardingDescriptionText(text: "Your personal home inventory assistant. We'll help you catalog and protect your valuable possessions using the power of AI.")
                        

                    }
                }
                
                VStack {
                    OnboardingContinueButton(action: {
                        manager.moveToNext()
                    }, title: "Get Started")
                    .accessibilityIdentifier("onboarding-welcome-continue-button")
                }
            }
        }
        .onboardingBackground()
    }
}


#Preview {
    Group {
        OnboardingWelcomeView()
            .environmentObject(OnboardingManager())
    }
}
