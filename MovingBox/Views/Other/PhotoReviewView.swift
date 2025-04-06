import SwiftUI

struct PhotoReviewView: View {
    let image: UIImage
    let onAccept: ((UIImage, Bool, @escaping () -> Void) -> Void)
    let onRetake: () -> Void
    let isOnboarding: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var isAnalyzing = false
    @State private var scannerOffset: CGFloat = -100
    @State private var scannerMovingDown = true
    @State private var localImage: UIImage?
    @State private var showingPaywall = false

    init(image: UIImage,
         onAccept: @escaping ((UIImage, Bool, @escaping () -> Void) -> Void),
         onRetake: @escaping () -> Void,
         isOnboarding: Bool = false) {
        self.image = image
        self.onAccept = onAccept
        self.onRetake = onRetake
        self.isOnboarding = isOnboarding
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let displayImage = localImage {
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.all)
                
                    if isAnalyzing {
                        Rectangle()
                            .fill(.red.opacity(0.8))
                            .frame(height: 2)
                            .blur(radius: 2)
                            .offset(y: scannerOffset)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                    scannerOffset = UIScreen.main.bounds.height
                                }
                            }
                        
                        VStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Analyzing image...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(height: 100)
                        .transition(.opacity)
                        .padding()
                        .foregroundStyle(.secondary)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        
                    } else {
                        VStack {
                            Spacer()
                            
                            HStack(spacing: 40) {
                                Button(action: {
                                    onRetake()
                                }) {
                                    VStack {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.title)
                                        Text("Retake")
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                                    .foregroundColor(.red)
                                }
                                .accessibilityIdentifier("retakePhoto")
                                
                                Button(action: {
                                    guard let displayImage = localImage else { return }
                                    let needsAnalysis = settings.isPro || isOnboarding
                                    if needsAnalysis {
                                        isAnalyzing = true
                                    }
                                    onAccept(displayImage, needsAnalysis) {
                                        DispatchQueue.main.async {
                                            isAnalyzing = false
                                            print("[DEBUG] PhotoReviewView - Completing photo review, isOnboarding: \(isOnboarding)")
                                            // Only dismiss if not in onboarding
                                            if !isOnboarding {
                                                dismiss()
                                            }
                                        }
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: "checkmark.circle")
                                            .font(.title)
                                        Text("Use Photo")
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                                    .foregroundColor(.green)
                                }
                                .accessibilityIdentifier("usePhoto")
                            }
                            .padding(.bottom, 30)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            .navigationTitle("Review Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isOnboarding {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("cancelPhotoReview")
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isAnalyzing)
            .interactiveDismissDisabled(isAnalyzing)
            .onAppear {
                localImage = image
                print("[DEBUG] PhotoReviewView appeared, isOnboarding: \(isOnboarding)")
            }
            .onDisappear {
                localImage = nil
                print("[DEBUG] PhotoReviewView disappeared, isOnboarding: \(isOnboarding)")
            }
            .sheet(isPresented: $showingPaywall) {
                MovingBoxPaywallView()
            }
        }
    }
}

#Preview {
    let settings = SettingsManager()

    print(" All Environment Variables:")
    ProcessInfo.processInfo.environment.forEach { key, value in
        print("\(key): \(value.prefix(4))...")
    }

    return PhotoReviewView(
        image: PreviewData.sampleImage,
        onAccept: { image, useAI, completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                completion()
            }
        },
        onRetake: {
            print("Retake tapped")
        }
    )
    .environmentObject(settings)
}

private struct PreviewData {
    static var sampleImage: UIImage {
        guard let url = URL(string: "https://m.media-amazon.com/images/I/41XyL-vTYBL._AC_SL1000_.jpg"),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600)).image { context in
                UIColor.gray.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
            }
        }
        return image
    }
}
