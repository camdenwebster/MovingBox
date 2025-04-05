import SwiftUI

struct OnboardingItemView: View {
    @EnvironmentObject private var manager: OnboardingManager
    @State private var showCameraSheet = false
    @State private var showPrivacyAlert = false
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        OnboardingHeaderText(text: "Add Your First Item")
                        
                        VStack(spacing: 16) {
                            OnboardingDescriptionText(text: "MovingBox uses artificial intelligence to automatically identify and catalog your items.")
                            
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                                .padding()
                                .symbolEffect(.bounce.up.byLayer, options: .nonRepeating)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                PrivacyBulletPoint(icon: "checkmark.shield", text: "Your photos are analyzed instantly")
                                PrivacyBulletPoint(icon: "xmark.shield", text: "We do not store your photos")
                                PrivacyBulletPoint(icon: "exclamationmark.triangle", text: "OpenAI will process your photos")
                            }
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            }
                            .padding(.horizontal)
                            
                            Button("Read OpenAI's Privacy Policy") {
                                if let url = URL(string: "https://openai.com/policies/privacy-policy") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        
                        // Add some bottom padding to ensure content doesn't get hidden behind the button
                        Spacer()
                            .frame(height: 100)
                    }
                }
                
                // Take Photo button in its own VStack outside of ScrollView
                VStack {
                    OnboardingContinueButton(action: {
                        showPrivacyAlert = true
                    }, title: "Take a Photo")
                }
            }
        }
        .onboardingBackground()
        .sheet(isPresented: $showCameraSheet) {
            CameraView { image, needsAIAnalysis, completion in
                // After successfully creating an item, move to the next screen
                completion()
                manager.moveToNext()
            }
            .onboardingCamera()
        }
        .alert("Privacy Notice", isPresented: $showPrivacyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                showCameraSheet = true
            }
        } message: {
            Text("Photos you take will be processed by OpenAI's vision API. Please ensure no sensitive information is visible in your photos.")
        }
    }
}

struct PrivacyBulletPoint: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            Text(text)
                .font(.subheadline)
        }
    }
    
    private var iconColor: Color {
        switch icon {
        case "checkmark.shield":
            return .green
        case "xmark.shield":
            return .red
        case "exclamationmark.triangle":
            return .orange
        default:
            return .primary
        }
    }
}

#Preview {
    OnboardingItemView()
        .environmentObject(OnboardingManager())
}
