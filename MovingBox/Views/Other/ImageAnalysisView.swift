import SwiftUI

struct ImageAnalysisView: View {
    let images: [UIImage]
    let onComplete: () -> Void
    
    @State private var scannerOffset: CGFloat = -100
    @State private var optimizedImages: [UIImage] = []
    @State private var analysisTimeElapsed = false
    @State private var appearedTime = Date()
    @State private var scannerOpacity: Double = 0
    @State private var currentImageIndex: Int = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    
    // Minimum time to show analysis screen (for UX purposes)
    private let minimumAnalysisTime: Double = 2.0
    // Time between image transitions
    private let transitionTime: Double = 1.0
    
    var body: some View {
        ZStack {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer()
                    
                    Group {
                        if let currentImage = optimizedImages[safe: currentImageIndex] ?? images[safe: currentImageIndex] {
                            Image(uiImage: currentImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: min(geometry.size.width, geometry.size.height))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical)
                                .transition(.opacity)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(2.0)
                        Text("AI Image Analysis in Progress...")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Analyzing photo \(currentImageIndex + 1) of \(images.count)")
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
            print("ImageAnalysisView appeared with \(images.count) images")
            
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
            
            // Optimize all images
            Task {
                for image in images {
                    let optimized = await OptimizedImageManager.shared.optimizeImage(image)
                    optimizedImages.append(optimized)
                }
            }
            
            // Start image carousel
            if images.count > 1 {
                Timer.scheduledTimer(withTimeInterval: transitionTime, repeats: true) { timer in
                    withAnimation {
                        currentImageIndex = (currentImageIndex + 1) % images.count
                    }
                }
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ImageAnalysisView(
        images: [UIImage(systemName: "photo")!],
        onComplete: {}
    )
}
