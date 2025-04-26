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
    @State private var statusMessage = ""
    
    private let minimumMessageDisplayTime: TimeInterval = 0.5
    
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
                
                VStack(spacing: 16) {
                    if isProcessing {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .font(.footnote)
                            .transition(.opacity)
                            .frame(height: 20)
                    }
                    
                    OnboardingContinueButton {
                        handleContinueButton()
                    } content: {
                        AnyView(
                            ZStack {
                                if isProcessing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Get Started")
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
                .animation(.easeInOut, value: isProcessing)
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
    
    private func updateStatusMessage(_ message: String) async {
        await MainActor.run {
            statusMessage = message
        }
        try? await Task.sleep(for: .seconds(minimumMessageDisplayTime))
    }
    
    private func handleContinueButton() {
        guard !isProcessing else { return }
        isProcessing = true
        
        Task {
            do {
                let isUiTesting = ProcessInfo.processInfo.arguments.contains("UI-Testing-Mock-Camera")
                
                await updateStatusMessage("Checking subscription status...")
                if !isUiTesting {
                    try await revenueCatManager.updateCustomerInfo()
                    try await revenueCatManager.syncPurchases()
                }
                
                await updateStatusMessage("Checking for existing data...")
                let shouldDismiss = try await OnboardingManager.checkAndUpdateOnboardingState(modelContext: modelContext)
                
                if shouldDismiss {
                    await updateStatusMessage("Complete! Redirecting...")
                    manager.markOnboardingComplete()
                } else {
                    await updateStatusMessage("Setting up default data...")
                    await DefaultDataManager.populateDefaultData(modelContext: modelContext)
                    manager.moveToNext()
                }
                
                await MainActor.run {
                    isProcessing = false
                    statusMessage = ""
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    statusMessage = ""
                    manager.showError(message: "Unable to check subscription status. Please make sure network connection is active and try again.")
                }
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
