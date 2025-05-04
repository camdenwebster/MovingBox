import SwiftUI

struct ImageAnalysisView: View {
    let image: UIImage
    let onComplete: () -> Void
    
    @State private var scannerOffset: CGFloat = -100
    @State private var optimizedImage: UIImage?
    @State private var analysisTimeElapsed = false
    @State private var appearedTime = Date()
    @State private var scannerOpacity: Double = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    
    // Minimum time to show analysis screen (for UX purposes)
    private let minimumAnalysisTime: Double = 2.0
    
    var body: some View {
        ZStack {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer()
                    
                    Group {
                        Image(uiImage: optimizedImage ?? image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: min(geometry.size.width, geometry.size.height))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                            .transition(.opacity)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(2.0)
                        Text("AI Image Analysis in Progress...")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Please wait while we analyze your photo")
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Rectangle()
                    .fill(.blue.opacity(0.8))
                    .frame(height: 2)
                    .blur(radius: 2)
                    .opacity(scannerOpacity)
                    .offset(y: scannerOffset)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .interactiveDismissDisabled(true)
        .onAppear {
            print("ImageAnalysisView appeared")
            
            // Fade in the scanner
            withAnimation(.easeIn(duration: 0.5)) {
                scannerOpacity = 1.0
            }
            
            // Start scanner animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                scannerOffset = UIScreen.main.bounds.height
            }
            
            // Store the time we appeared
            appearedTime = Date()
            
            // Optimize the image for display
            Task {
                optimizedImage = await OptimizedImageManager.shared.optimizeImage(image)
            }
            
            // Ensure we show the analysis screen for at least the minimum time
            DispatchQueue.main.asyncAfter(deadline: .now() + minimumAnalysisTime) {
                analysisTimeElapsed = true
                checkAndComplete()
            }
        }
    }
    
    // Function to check if we can complete and move on
    private func checkAndComplete() {
        if analysisTimeElapsed {
            print("ImageAnalysisView: minimum time elapsed, calling onComplete")
            onComplete()
        }
    }
}

#Preview {
    ImageAnalysisView(
        image: UIImage(systemName: "photo")!,
        onComplete: {}
    )
}
