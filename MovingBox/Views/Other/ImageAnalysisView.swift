import SwiftUI

struct ImageAnalysisView: View {
    let image: UIImage
    let onComplete: () -> Void
    
    @State private var scannerOffset: CGFloat = -100
    @State private var optimizedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isOnboarding) private var isOnboarding
    
    var body: some View {
        NavigationStack {
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
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Rectangle()
                        .fill(.blue.opacity(0.8))
                        .frame(height: 2)
                        .blur(radius: 2)
                        .offset(y: scannerOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                scannerOffset = geometry.size.height
                            }
                        }
                }
            }
            .navigationTitle("Analyzing Photo")
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .interactiveDismissDisabled(true)
            .task {
                print("ImageAnalysisView appeared with image size: \(image.size)")
                optimizedImage = OptimizedImageManager.shared.optimizeImage(image)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                onComplete()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ImageAnalysisView(
        image: UIImage(systemName: "photo")!,
        onComplete: {}
    )
}
