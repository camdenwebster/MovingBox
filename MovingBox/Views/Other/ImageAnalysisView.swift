import SentrySwiftUI
import SwiftUI

struct ImageAnalysisView: View {
    let image: UIImage?
    let images: [UIImage]
    let onComplete: () -> Void

    @State private var optimizedImages: [UIImage] = []
    @State private var currentImageIndex = 0
    @State private var analysisTimeElapsed = false
    @State private var appearedTime = Date()
    @State private var currentQuoteIndex = 0
    @State private var quoteTimer: Timer?
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

    // Humorous quotes from JSX prototype
    private let quotes = [
        "Analyzing your precious cargo...",
        "Determining if that's actually valuable or just sentimental...",
        "Counting boxes. So many boxes...",
        "Identifying items you forgot you owned...",
        "Cataloging things you'll definitely use someday...",
        "Processing your life's accumulation...",
        "Teaching AI the difference between 'vintage' and 'old'...",
        "Recognizing items that spark joy (or don't)...",
        "Documenting proof that yes, you own that many cables...",
        "Scanning for things that should've been donated years ago...",
    ]

    var body: some View {
        ZStack {
            // Mesh gradient background
            AnimatedMeshGradient()
                .opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Photo preview section
                VStack(spacing: 16) {
                    Group {
                        if images.count > 1 {
                            VStack(spacing: 12) {
                                // Main image display
                                if currentImageIndex < optimizedImages.count {
                                    Image(uiImage: optimizedImages[currentImageIndex])
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 250)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: .black.opacity(0.2), radius: 10)
                                        .transition(
                                            .asymmetric(
                                                insertion: .scale.combined(with: .opacity),
                                                removal: .scale.combined(with: .opacity)
                                            ))
                                } else if let fallbackImage = images[safe: currentImageIndex] {
                                    Image(uiImage: fallbackImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 250)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: .black.opacity(0.2), radius: 10)
                                        .transition(
                                            .asymmetric(
                                                insertion: .scale.combined(with: .opacity),
                                                removal: .scale.combined(with: .opacity)
                                            ))
                                }
                            }
                        } else {
                            // Single image display (backward compatibility)
                            if let optimizedImage = optimizedImages.first {
                                Image(uiImage: optimizedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .black.opacity(0.2), radius: 10)
                                    .transition(.scale.combined(with: .opacity))
                            } else if let fallbackImage = image {
                                Image(uiImage: fallbackImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .black.opacity(0.2), radius: 10)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // AI Analysis section
                VStack(spacing: 24) {
                    // Apple Intelligence icon with pulse animation
                    //                    Image(systemName: "apple.intelligence")
                    //                        .font(.system(size: 64))
                    //                        .foregroundStyle(
                    //                            LinearGradient(
                    //                                colors: [.blue, .purple],
                    //                                startPoint: .topLeading,
                    //                                endPoint: .bottomTrailing
                    //                            )
                    //                        )
                    //                        .symbolEffect(.pulse)

                    // Photo count
                    if images.count > 1 {
                        Text("Analyzing \(images.count) \(images.count == 1 ? "photo" : "photos")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Rotating quote with fixed height to prevent layout shifts
                    VStack {
                        Text(quotes[currentQuoteIndex])
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .italic()
                            .id(currentQuoteIndex)  // Force re-render on quote change
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                    }
                    .frame(minHeight: 60)
                    .padding(.horizontal)

                    // Disclaimer
                    Text("AI can make mistakes. Check important info.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .frame(maxWidth: 600)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .interactiveDismissDisabled(true)
        .onAppear {
            print("ImageAnalysisView appeared with \(images.count) images")

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

            // Start quote cycling
            startQuoteCycling()

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
        .onDisappear {
            quoteTimer?.invalidate()
            quoteTimer = nil
        }
        .sentryTrace("ImageAnalysisView")
    }

    // Function to start cycling through quotes
    private func startQuoteCycling() {
        quoteTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [self] timer in
            withAnimation(.easeInOut(duration: 0.5)) {
                // Pick a random quote that's different from the current one
                var newIndex: Int
                repeat {
                    newIndex = Int.random(in: 0..<quotes.count)
                } while newIndex == currentQuoteIndex && quotes.count > 1
                currentQuoteIndex = newIndex
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
