import SwiftUI

struct OnboardingWelcomeView: View {
    @EnvironmentObject private var manager: OnboardingManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.disableAnimations) private var disableAnimations
    @State private var imageOpacity = 0.0
    @State private var welcomeOpacity = 0.0
    @State private var titleOpacity = 0.0
    @State private var descriptionOpacity = 0.0
    @State private var buttonOpacity = 0.0
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack {
                        Image(colorScheme == .dark ? "onboardingDark" : "onboardingLight")
                            .resizable()
                            .scaledToFit()
                            .frame(minHeight: 200, maxHeight: 400)
                            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                            .padding(.vertical)
                            .opacity(imageOpacity)
                            .offset(y: imageOpacity == 0 ? -20 : 0)
                        
                        VStack {
                            Text("Welcome to")
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .opacity(welcomeOpacity)
                                .offset(y: welcomeOpacity == 0 ? -20 : 0)
                            
                            Text("MovingBox")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .opacity(titleOpacity)
                                .offset(y: titleOpacity == 0 ? -20 : 0)
                        }
                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                        
                        OnboardingDescriptionText(text: "Your personal home inventory assistant. We'll help you catalog and protect your valuable possessions using the power of AI.")
                            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                            .opacity(descriptionOpacity)
                            .offset(y: descriptionOpacity == 0 ? -20 : 0)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                VStack {
                    OnboardingContinueButton(action: {
                        manager.moveToNext()
                    }, title: "Get Started")
                    .accessibilityIdentifier("onboarding-welcome-continue-button")
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                    .opacity(buttonOpacity)
                    .offset(y: buttonOpacity == 0 ? -20 : 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onboardingBackground()
        .onAppear {
            let animation: Animation? = disableAnimations ? nil : .easeOut(duration: 0.6)
            
            withAnimation(animation?.delay(0)) {
                imageOpacity = 1
            }
            
            withAnimation(animation?.delay(0.3)) {
                welcomeOpacity = 1
            }
            
            withAnimation(animation?.delay(0.6)) {
                titleOpacity = 1
            }
            
            withAnimation(animation?.delay(0.9)) {
                descriptionOpacity = 1
            }
            
            withAnimation(animation?.delay(1.2)) {
                buttonOpacity = 1
            }
        }
    }
}

#Preview {
    Group {
        OnboardingWelcomeView()
            .environmentObject(OnboardingManager())
    }
}
