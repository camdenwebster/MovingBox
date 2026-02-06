import SwiftData
import SwiftUI

struct OnboardingItemView: View {
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.modelContext) var modelContext
    @Query private var locations: [InventoryLocation]

    @State private var showPrivacyAlert = false
    @State private var showItemCreationFlow = false
    @State private var isProcessingImage = false

    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                                .padding()
                                .symbolEffect(.bounce.up.byLayer, options: .nonRepeating)

                            OnboardingHeaderText(text: "Add Your First Item")

                            VStack(spacing: 16) {
                                OnboardingDescriptionText(
                                    text:
                                        "MovingBox uses artificial intelligence to automatically identify and catalog your items."
                                )

                                VStack(alignment: .leading, spacing: 12) {
                                    OnboardingFeatureRow(
                                        icon: "checkmark.shield",
                                        iconColor: .green,
                                        title: "Instant Analysis",
                                        description: "Your photos are analyzed instantly"
                                    )

                                    OnboardingFeatureRow(
                                        icon: "xmark.shield",
                                        iconColor: .red,
                                        title: "Privacy First",
                                        description: "We do not store your photos"
                                    )

                                    OnboardingFeatureRow(
                                        icon: "exclamationmark.triangle",
                                        iconColor: .orange,
                                        title: "AI Processing",
                                        description: "OpenAI will process your photos"
                                    )
                                }
                                .padding(20)
                                .background {
                                    RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                                        .fill(.ultraThinMaterial)
                                }

                                Button("Read OpenAI's Privacy Policy") {
                                    if let url = URL(string: "https://openai.com/policies/privacy-policy") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                        }
                        .frame(maxWidth: .infinity)

                        Spacer()
                            .frame(height: 100)
                    }
                }

                VStack {
                    OnboardingContinueButton(
                        action: {
                            showPrivacyAlert = true
                        }, title: "Take a Photo"
                    )
                    .accessibilityIdentifier("onboarding-item-take-photo-button")
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .movingBoxFullScreenCoverCompat(isPresented: $showItemCreationFlow) {
            EnhancedItemCreationFlowView(
                captureMode: .singleItem,
                location: locations.first
            ) {
                manager.moveToNext()
            }
            .environment(\.isOnboarding, true)
            .interactiveDismissDisabled(isProcessingImage)
            .tint(.green)
        }
        .alert("Privacy Notice", isPresented: $showPrivacyAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") {
                showItemCreationFlow = true
            }
        } message: {
            Text(
                "Photos you take will be processed by OpenAI's vision API. Please ensure no sensitive information is visible in your photos.\n\nAI can make mistakes and may not always accurately identify items."
            )
        }
    }
}

#Preview {
    OnboardingItemView()
        .environmentObject(OnboardingManager())
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
