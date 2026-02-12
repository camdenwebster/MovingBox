import AVFoundation
import MovingBoxAIAnalysis
import SwiftData
import UIKit

struct VideoAnalysisProgress: Sendable {
    enum Phase: Sendable {
        case extractingFrames
        case transcribingAudio
        case analyzingBatch(current: Int, total: Int)
        case deduplicating
    }

    let phase: Phase
    let progress: Double
    let overallProgress: Double
}

protocol VideoAnalysisCoordinatorProtocol: Sendable {
    func analyze(
        videoAsset: AVAsset,
        settings: SettingsManager,
        modelContext: ModelContext,
        aiService: AIAnalysisServiceProtocol,
        onProgress: @escaping @Sendable (VideoAnalysisProgress) -> Void
    ) async throws -> MultiItemAnalysisResponse
}

final class VideoAnalysisCoordinator: VideoAnalysisCoordinatorProtocol, @unchecked Sendable {
    private let frameExtractor: VideoFrameExtractorProtocol
    private let audioTranscriber: AudioTranscriberProtocol

    private(set) var extractedFrames: [TimestampedFrame] = []
    private(set) var progressiveMergedResponse: MultiItemAnalysisResponse?
    private(set) var totalBatchCount: Int = 0
    private(set) var completedBatchCount: Int = 0

    init(
        frameExtractor: VideoFrameExtractorProtocol = VideoFrameExtractor(),
        audioTranscriber: AudioTranscriberProtocol = AudioTranscriber()
    ) {
        self.frameExtractor = frameExtractor
        self.audioTranscriber = audioTranscriber
    }

    func analyze(
        videoAsset: AVAsset,
        settings: SettingsManager,
        modelContext: ModelContext,
        aiService: AIAnalysisServiceProtocol,
        onProgress: @escaping @Sendable (VideoAnalysisProgress) -> Void
    ) async throws -> MultiItemAnalysisResponse {
        progressiveMergedResponse = nil
        totalBatchCount = 0
        completedBatchCount = 0
        await updateProgress(.extractingFrames, progress: 0.0, overall: 0.0, onProgress: onProgress)

        async let framesResult: [TimestampedFrame] = frameExtractor.extractFrames(
            from: videoAsset,
            interval: 1.0,
            onProgress: { progress in
                Task { @MainActor in
                    let overall = min(0.35, progress * 0.35)
                    onProgress(
                        VideoAnalysisProgress(
                            phase: .extractingFrames,
                            progress: progress,
                            overallProgress: overall
                        ))
                }
            }
        )

        async let transcriptionResult: TranscriptionResult = audioTranscriber.transcribe(
            asset: videoAsset,
            onProgress: { progress in
                Task { @MainActor in
                    let overall = 0.35 + min(0.2, progress * 0.2)
                    onProgress(
                        VideoAnalysisProgress(
                            phase: .transcribingAudio,
                            progress: progress,
                            overallProgress: overall
                        ))
                }
            }
        )

        let frames = try await framesResult
        extractedFrames = frames

        let transcription: TranscriptionResult
        do {
            transcription = try await transcriptionResult
        } catch {
            print("⚠️ VideoAnalysisCoordinator - Transcription failed, continuing without narration: \(error)")
            transcription = TranscriptionResult(fullText: "", segments: [])
        }

        if frames.isEmpty {
            return MultiItemAnalysisResponse(
                items: [],
                detectedCount: 0,
                analysisType: "multi_item",
                confidence: 0.0
            )
        }

        let batchSize = 5
        let totalBatches = Int(ceil(Double(frames.count) / Double(batchSize)))
        totalBatchCount = totalBatches
        var batchResults: [(response: MultiItemAnalysisResponse, batchOffset: Int)] = []
        batchResults.reserveCapacity(totalBatches)

        for batchIndex in 0..<totalBatches {
            let start = batchIndex * batchSize
            let end = min(start + batchSize, frames.count)
            let batchFrames = Array(frames[start..<end])
            let batchImages = batchFrames.map { $0.image }

            let narrationContext = buildNarrationContext(
                for: batchFrames,
                segments: transcription.segments
            )

            await updateProgress(
                .analyzingBatch(current: batchIndex + 1, total: totalBatches),
                progress: Double(batchIndex) / Double(totalBatches),
                overall: 0.55 + Double(batchIndex) / Double(max(totalBatches, 1)) * 0.4,
                onProgress: onProgress
            )

            let completedBatchResults = batchResults
            let aiContext = await MainActor.run {
                AIAnalysisContext.from(modelContext: modelContext, settings: settings)
            }
            let response = try await aiService.getMultiItemDetails(
                from: batchImages,
                settings: settings,
                context: aiContext,
                narrationContext: narrationContext,
                onPartialResponse: { [weak self] partialResponse in
                    guard let self else { return }

                    let progressivelyMergedBatchResults =
                        completedBatchResults + [
                            (response: partialResponse, batchOffset: start)
                        ]
                    self.progressiveMergedResponse = VideoItemDeduplicator.deduplicate(
                        batchResults: progressivelyMergedBatchResults
                    )

                    let inBatchProgress = max(0.12, min(0.92, Double(partialResponse.safeItems.count) * 0.18))
                    Task {
                        await self.updateProgress(
                            .analyzingBatch(current: batchIndex + 1, total: totalBatches),
                            progress: (Double(batchIndex) + inBatchProgress) / Double(totalBatches),
                            overall: 0.55
                                + (Double(batchIndex) + inBatchProgress) / Double(max(totalBatches, 1)) * 0.4,
                            onProgress: onProgress
                        )
                    }
                }
            )

            batchResults.append((response: response, batchOffset: start))
            completedBatchCount = batchIndex + 1
            progressiveMergedResponse = VideoItemDeduplicator.deduplicate(batchResults: batchResults)

            await updateProgress(
                .analyzingBatch(current: batchIndex + 1, total: totalBatches),
                progress: Double(batchIndex + 1) / Double(totalBatches),
                overall: 0.55 + Double(batchIndex + 1) / Double(max(totalBatches, 1)) * 0.4,
                onProgress: onProgress
            )
        }

        await updateProgress(.deduplicating, progress: 0.2, overall: 0.95, onProgress: onProgress)
        let mergedResponse = VideoItemDeduplicator.deduplicate(batchResults: batchResults)
        await updateProgress(.deduplicating, progress: 1.0, overall: 1.0, onProgress: onProgress)

        return mergedResponse
    }

    private func updateProgress(
        _ phase: VideoAnalysisProgress.Phase,
        progress: Double,
        overall: Double,
        onProgress: @escaping @Sendable (VideoAnalysisProgress) -> Void
    ) async {
        await MainActor.run {
            onProgress(VideoAnalysisProgress(phase: phase, progress: progress, overallProgress: overall))
        }
    }

    private func buildNarrationContext(
        for frames: [TimestampedFrame],
        segments: [TranscriptionSegment]
    ) -> String? {
        guard !segments.isEmpty else { return nil }

        let timestamps = frames.map { $0.timestamp }
        var seen = Set<String>()
        var texts: [String] = []

        for segment in segments {
            let isRelevant = timestamps.contains { timestamp in
                let withinSegment = segment.startTime <= timestamp && timestamp <= segment.endTime
                let closeToStart = abs(segment.startTime - timestamp) <= 0.5
                let closeToEnd = abs(segment.endTime - timestamp) <= 0.5
                return withinSegment || closeToStart || closeToEnd
            }

            if isRelevant {
                let trimmed = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !seen.contains(trimmed) {
                    seen.insert(trimmed)
                    texts.append(trimmed)
                }
            }
        }

        let combined = texts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? nil : combined
    }
}
