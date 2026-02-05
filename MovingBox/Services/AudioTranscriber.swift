import AVFoundation
import Speech

enum TranscriptionError: Error {
    case speechRecognizerUnavailable
    case authorizationDenied
    case audioExtractionFailed
    case transcriptionFailed(Error)
}

struct TranscriptionSegment: Sendable {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

struct TranscriptionResult: Sendable {
    let fullText: String
    let segments: [TranscriptionSegment]
}

protocol AudioTranscriberProtocol: Sendable {
    func transcribe(
        asset: AVAsset,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> TranscriptionResult
}

final class AudioTranscriber: AudioTranscriberProtocol, @unchecked Sendable {
    func transcribe(
        asset: AVAsset,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> TranscriptionResult {
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            await MainActor.run {
                onProgress(1.0)
            }
            return TranscriptionResult(fullText: "", segments: [])
        }

        await MainActor.run {
            onProgress(0.05)
        }

        let authorization = await requestSpeechAuthorizationIfNeeded()
        guard authorization == .authorized else {
            throw TranscriptionError.authorizationDenied
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.speechRecognizerUnavailable
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        do {
            try await extractAudio(from: asset, track: audioTrack, to: tempURL, onProgress: onProgress)
        } catch {
            throw TranscriptionError.audioExtractionFailed
        }

        await MainActor.run {
            onProgress(0.6)
        }

        let request = SFSpeechURLRecognitionRequest(url: tempURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        do {
            let result = try await recognize(request: request, with: recognizer)
            let transcription = result.bestTranscription
            let segments = transcription.segments.map {
                TranscriptionSegment(
                    text: $0.substring,
                    startTime: $0.timestamp,
                    endTime: $0.timestamp + $0.duration
                )
            }

            await MainActor.run {
                onProgress(1.0)
            }

            let fullText = transcription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if fullText.isEmpty {
                return TranscriptionResult(fullText: "", segments: [])
            }

            return TranscriptionResult(fullText: fullText, segments: segments)
        } catch {
            throw TranscriptionError.transcriptionFailed(error)
        }
    }

    private func requestSpeechAuthorizationIfNeeded() async -> SFSpeechRecognizerAuthorizationStatus {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status != .notDetermined {
            return status
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { newStatus in
                continuation.resume(returning: newStatus)
            }
        }
    }

    private func extractAudio(
        from asset: AVAsset,
        track: AVAssetTrack,
        to url: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        readerOutput.alwaysCopiesSampleData = false

        guard reader.canAdd(readerOutput) else {
            throw TranscriptionError.audioExtractionFailed
        }
        reader.add(readerOutput)

        let writer = try AVAssetWriter(outputURL: url, fileType: .caf)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false

        guard writer.canAdd(writerInput) else {
            throw TranscriptionError.audioExtractionFailed
        }
        writer.add(writerInput)

        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let duration = asset.duration.seconds

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "audio.transcriber.writer")
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(sampleBuffer)
                        if duration.isFinite {
                            let presentationTime = sampleBuffer.presentationTimeStamp.seconds
                            let progress = min(0.5, max(0.1, presentationTime / duration * 0.5))
                            Task { @MainActor in
                                onProgress(progress)
                            }
                        }
                    } else {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            if reader.status == .failed || writer.status == .failed {
                                continuation.resume(throwing: TranscriptionError.audioExtractionFailed)
                            } else {
                                continuation.resume(returning: ())
                            }
                        }
                        break
                    }
                }
            }
        }
    }

    private func recognize(
        request: SFSpeechURLRecognitionRequest,
        with recognizer: SFSpeechRecognizer
    ) async throws -> SFSpeechRecognitionResult {
        try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result, result.isFinal {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}
