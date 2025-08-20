import SwiftUI

struct ImageAnalysisView: View {
    let image: UIImage?
    let images: [UIImage]
    let onComplete: () -> Void
    
    @State private var scannerOffset: CGFloat = -100
    @State private var optimizedImages: [UIImage] = []
    @State private var currentImageIndex = 0
    @State private var analysisTimeElapsed = false
    @State private var appearedTime = Date()
    @State private var scannerOpacity: Double = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    
    // Convenience initializer for single image (backward compatibility)
    init(image: UIImage, onComplete: @escaping () -> Void) {
        self.image = image
        self.images = [image]
        self.onComplete = onComplete
    }
    
    // New initializer for multiple images
    init(images: [UIImage], onComplete: @escaping () -> Void) {
        self.image = images.first
        self.images = images
        self.onComplete = onComplete
    }
    
    // Minimum time to show analysis screen (for UX purposes)
    private let minimumAnalysisTime: Double = 2.0
    
    var body: some View {
        ZStack {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer()
                    
                    Group {
                        if images.count > 1 {
                            VStack(spacing: 12) {
                                // Main image display
                                if currentImageIndex < optimizedImages.count {
                                    Image(uiImage: optimizedImages[currentImageIndex])
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: min(geometry.size.width, geometry.size.height) * 0.8)
                                        .frame(maxWidth: .infinity)
                                        .transition(.slide)
                                } else if let fallbackImage = images[safe: currentImageIndex] {
                                    Image(uiImage: fallbackImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: min(geometry.size.width, geometry.size.height) * 0.8)
                                        .frame(maxWidth: .infinity)
                                        .transition(.slide)
                                }
                                
                                // Photo indicator dots
                                HStack(spacing: 8) {
                                    ForEach(0..<images.count, id: \.self) { index in
                                        Circle()
                                            .fill(index == currentImageIndex ? .blue : .gray.opacity(0.4))
                                            .frame(width: 8, height: 8)
                                            .animation(.easeInOut(duration: 0.2), value: currentImageIndex)
                                    }
                                }
                                .transition(.slide)
                                
                                Text("\(currentImageIndex + 1) of \(images.count) photos")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .transition(.slide)
                            }
                        } else {
                            // Single image display (backward compatibility)
                            if let optimizedImage = optimizedImages.first {
                                Image(uiImage: optimizedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: min(geometry.size.width, geometry.size.height))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical)
                                    .transition(.slide)
                            } else if let fallbackImage = image {
                                Image(uiImage: fallbackImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: min(geometry.size.width, geometry.size.height))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical)
                                    .transition(.slide)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "brain" )
                            .font(.largeTitle)
                            .foregroundStyle(Color.customPrimary)
                            .symbolEffect(.pulse)
                        Text("AI Image Analysis in Progress...")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(images.count > 1 ? "Please wait while we analyze your \(images.count) photos" : "Please wait while we analyze your photo")
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
            
            // Optimize all images for display
            Task {
                optimizedImages = []
                for image in images {
                    let optimized = await OptimizedImageManager.shared.optimizeImage(image)
                    optimizedImages.append(optimized)
                }
            }
            
            // If multiple images, cycle through them during analysis
            if images.count > 1 {
                startImageCycling()
            }
            
            // Ensure we show the analysis screen for at least the minimum time
            DispatchQueue.main.asyncAfter(deadline: .now() + minimumAnalysisTime) {
                analysisTimeElapsed = true
                checkAndComplete()
            }
        }
    }
    
    // Function to start cycling through images during analysis
    private func startImageCycling() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            if !analysisTimeElapsed {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentImageIndex = (currentImageIndex + 1) % images.count
                }
            } else {
                timer.invalidate()
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

// Extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ImageAnalysisView(
        image: UIImage(systemName: "photo")!,
        onComplete: {}
    )
}
