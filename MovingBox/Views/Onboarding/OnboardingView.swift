import SwiftUI

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                switch manager.currentStep {
                case .welcome:
                    OnboardingWelcomeView()
                case .homeDetails:
                    OnboardingHomeView()
                case .location:
                    OnboardingLocationView()
                case .item:
                    OnboardingItemView()
                case .completion:
                    OnboardingCompletionView()
                }
            }
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
                    Button("Skip") {
                        manager.moveToNext()
                    }
                }
            }
        }
        .environmentObject(manager)
        .tint(Color.customPrimary)
    }
}

#Preview {
    OnboardingView()
}
