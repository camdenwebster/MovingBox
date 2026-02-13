import AVFoundation
import UIKit

enum VideoExtractionError: Error {
    case noVideoTrack
    case extractionFailed
    case videoTooLong(duration: TimeInterval)
    case cancelled
}

struct TimestampedFrame: @unchecked Sendable {
    let image: UIImage
    let timestamp: TimeInterval
}

protocol VideoFrameExtractorProtocol: Sendable {
    func extractFrames(
        from asset: AVAsset,
        interval: TimeInterval,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> [TimestampedFrame]
}

final class VideoFrameExtractor: VideoFrameExtractorProtocol, @unchecked Sendable {
    private let maxDuration: TimeInterval = 180

    func extractFrames(
        from asset: AVAsset,
        interval: TimeInterval,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> [TimestampedFrame] {
        guard asset.tracks(withMediaType: .video).isEmpty == false else {
            throw VideoExtractionError.noVideoTrack
        }

        let duration = asset.duration.seconds
        guard duration.isFinite else {
            throw VideoExtractionError.extractionFailed
        }

        if duration > maxDuration {
            throw VideoExtractionError.videoTooLong(duration: duration)
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let frameTimes = stride(from: 0.0, to: duration, by: interval).map {
            CMTime(seconds: $0, preferredTimescale: 600)
        }

        if frameTimes.isEmpty {
            return []
        }

        var frames: [TimestampedFrame] = []
        frames.reserveCapacity(frameTimes.count)

        for (index, time) in frameTimes.enumerated() {
            try Task.checkCancellation()

            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                let optimizedImage = await OptimizedImageManager.shared.optimizeImage(uiImage)
                frames.append(TimestampedFrame(image: optimizedImage, timestamp: time.seconds))
            } catch {
                print("❌ VideoFrameExtractor - Failed to extract frame at \(time.seconds): \(error)")
            }

            let progress = Double(index + 1) / Double(frameTimes.count)
            await MainActor.run {
                onProgress(progress)
            }
        }

        if Task.isCancelled {
            throw VideoExtractionError.cancelled
        }

        if frames.isEmpty, duration > 0 {
            throw VideoExtractionError.extractionFailed
        }

        return frames
    }
}
