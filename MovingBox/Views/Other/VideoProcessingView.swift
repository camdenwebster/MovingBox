import SwiftUI
import UIKit

enum VideoAnalysisPhase: Sendable {
    case extractingFrames
    case transcribingAudio
    case analyzingBatch(current: Int, total: Int)
    case deduplicating
}

struct SimpleVideoAnalysisProgress: Sendable {
    let phase: VideoAnalysisPhase
    let progress: Double
    let overallProgress: Double
}

struct VideoProcessingView: View {
    let thumbnail: UIImage?
    let progress: SimpleVideoAnalysisProgress?
    let onComplete: () -> Void

    @State private var hasCompleted = false

    var body: some View {
        ZStack {
            AnimatedMeshGradient()
                .opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 10)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 240, height: 180)
                        .overlay(
                            Image(systemName: "video")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.7))
                        )
                }

                VStack(spacing: 12) {
                    Text(phaseText)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    ProgressView(value: progress?.overallProgress ?? 0.0)
                        .progressViewStyle(.linear)
                        .tint(.blue)

                    Text("AI can make mistakes. Check important info.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .frame(maxWidth: 600)
        }
        .onChange(of: progress?.overallProgress ?? 0.0) { _, newValue in
            guard !hasCompleted, newValue >= 1.0 else { return }
            hasCompleted = true
            onComplete()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .interactiveDismissDisabled(true)
    }

    private var phaseText: String {
        guard let progress else { return "Preparing video analysis..." }
        switch progress.phase {
        case .extractingFrames:
            return "Extracting frames..."
        case .transcribingAudio:
            return "Transcribing narration..."
        case .analyzingBatch(let current, let total):
            return "Analyzing items (batch \(current) of \(total))..."
        case .deduplicating:
            return "Removing duplicates..."
        }
    }
}
