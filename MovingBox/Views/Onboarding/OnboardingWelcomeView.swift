import SwiftUI

struct OnboardingWelcomeView: View {
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.disableAnimations) private var disableAnimations
    @Environment(\.modelContext) private var modelContext
    
    @State private var imageOpacity = 0.0
    @State private var welcomeOpacity = 0.0
    @State private var titleOpacity = 0.0
    @State private var descriptionOpacity = 0.0
    @State private var buttonOpacity = 0.0
    @State private var isProcessing = false
    
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
                        guard !isProcessing else { return }
                        isProcessing = true
                        
                        Task {
                            do {
                                let isUiTesting = ProcessInfo.processInfo.arguments.contains("UI-Testing-Mock-Camera")
                                if !isUiTesting {
                                    // First check RevenueCat status and sync purchases
                                    try await revenueCatManager.updateCustomerInfo()
                                    try await revenueCatManager.syncPurchases()
                                }
                                
                                let shouldDismiss = try await OnboardingManager.checkAndUpdateOnboardingState(modelContext: modelContext)
                                
                                await MainActor.run {
                                    isProcessing = false
                                    if shouldDismiss {
                                        manager.markOnboardingComplete()
                                    } else {
                                        // Populate default data before moving to next step
                                        Task {
                                            await DefaultDataManager.populateDefaultData(modelContext: modelContext)
                                            manager.moveToNext()
                                        }
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    isProcessing = false
                                    manager.showError(message: "Unable to check subscription status. Please make sure network connection is active and try again.")
                                }
                            }
                        }
                    }) {
                        AnyView(
                            ZStack {
                                Text(isProcessing ? "" : "Get Started")
                                if isProcessing {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                        )
                    }
                    .disabled(isProcessing)
                    .accessibilityIdentifier("onboarding-welcome-continue-button")
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                    .opacity(buttonOpacity)
                    .offset(y: buttonOpacity == 0 ? -20 : 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onboardingBackground()
        .alert("Error", isPresented: $manager.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(manager.alertMessage)
        }
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
