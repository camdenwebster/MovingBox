import SwiftUI

struct MovingBoxPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding(.top, 32)
                
                Text("Upgrade to MovingBox Pro")
                    .font(.title)
                    .bold()
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "photo", text: "AI Image Analysis")
                    FeatureRow(icon: "infinity", text: "Unlimited Items")
                    FeatureRow(icon: "rectangle.stack", text: "Unlimited Locations")
                    FeatureRow(icon: "icloud", text: "iCloud Sync")
                }
                .padding(.horizontal)
                
                Button(action: {
                    // TODO: Implement purchase flow
                    settingsManager.isPro = true
                    dismiss()
                }) {
                    Text("Upgrade Now - $4.99")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .accessibilityIdentifier("upgradeButton")
                .padding(.horizontal)
                
                Spacer()
                
                Text("All features • One-time purchase")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .navigationBarItems(
                trailing: Button(action: {
                    settingsManager.hasSeenPaywall = true
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .accessibilityIdentifier("dismissPaywall")
            )
        }
        .accessibilityIdentifier("paywallView")
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
            Spacer()
        }
    }
}

#Preview {
    MovingBoxPaywallView()
        .environmentObject(SettingsManager())
}
