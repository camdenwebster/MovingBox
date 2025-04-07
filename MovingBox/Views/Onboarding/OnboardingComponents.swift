import SwiftUI

struct OnboardingContinueButton: View {
    let action: () -> Void
    var title: String = "Continue"
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.customPrimary)
                .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
}

struct OnboardingHeaderText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.title2)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.top)
    }
}

struct OnboardingDescriptionText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.body)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
}

struct OnboardingContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack {
//            Spacer()
            content
//            Spacer()
        }
        .tint(Color.customPrimary)

    }

}

// MARK: - Animated Gradient Background

struct AnimatedMeshGradient: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase = 0.0
    
    private var colors: [Color] {
        colorScheme == .dark ? [
            Color(hex: 0x1A1B2E),  // Deep purple-blue
            Color(hex: 0x2B2F4B),  // Rich navy
            Color(hex: 0x393B63),  // Medium purple
            Color(hex: 0x252B43)   // Dark slate purple
        ] : [
            Color(hex: 0xFFE4BC),  // Warm sand
            Color(hex: 0xFFD4B8),  // Peach
            Color(.white),         //  white
            Color(hex: 0xE6F0C4)   // Sage
        ]
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let timeNow = timeline.date.timeIntervalSinceReferenceDate
                let animation = timeNow.remainder(dividingBy: 60)
                let phase = animation / 60
                
                context.addFilter(.blur(radius: 45))  // Reduced blur for more definition
                
                for index in 0..<4 {
                    let offsetX = size.width * 0.8 * cos(phase * 2 * .pi + Double(index) * .pi / 2)
                    let offsetY = size.height * 0.8 * sin(phase * 2 * .pi + Double(index) * .pi / 2)
                    
                    context.fill(
                        Circle().path(in: CGRect(x: size.width / 2 + offsetX - 400,
                                               y: size.height / 2 + offsetY - 400,
                                               width: 1000,
                                               height: 1000)),
                        with: .color(colors[index])
                    )
                }
            }
        }
    }
}

// MARK: - View Modifier

struct OnboardingBackgroundModifier: ViewModifier {
    @Environment(\.isSnapshotTesting) private var isSnapshotTesting
    
    func body(content: Content) -> some View {
        content
            .background {
                if isSnapshotTesting {
                    // Use static gradient for snapshots
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(0.2)
                    .ignoresSafeArea()
                } else {
                    // Use animated mesh gradient for normal use
                    AnimatedMeshGradient()
                        .opacity(0.7)
                        .ignoresSafeArea()
                }
            }
    }
}

// MARK: - View Extension

extension View {
    func onboardingBackground() -> some View {
        self.modifier(OnboardingBackgroundModifier())
    }
}
