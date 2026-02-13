//
//  AIAnalysisService.swift
//  MovingBoxAIAnalysis
//

import AIProxy
import Foundation

@MainActor
public class AIAnalysisService: AIAnalysisServiceProtocol {
    private var currentImageTask: Task<ImageDetails, Error>?
    private var currentMultiItemTask: Task<MultiItemAnalysisResponse, Error>?

    private let requestBuilder: AIRequestBuilder
    private let responseParser = AIResponseParser()
    private let telemetryTracker: AITelemetryTracker?

    public init(imageOptimizer: AIImageOptimizer, telemetryTracker: AITelemetryTracker? = nil) {
        self.requestBuilder = AIRequestBuilder(imageOptimizer: imageOptimizer)
        self.telemetryTracker = telemetryTracker
    }

    public func getImageDetails(
        from images: [AIImage], settings: AIAnalysisSettings, context: AIAnalysisContext
    ) async throws -> ImageDetails {
        currentImageTask?.cancel()
        currentMultiItemTask?.cancel()

        currentImageTask = Task {
            return try await performRequestWithRetry(images: images, settings: settings, context: context)
        }

        defer {
            currentImageTask = nil
        }

        return try await currentImageTask!.value
    }

    public func analyzeItem(
        from images: [AIImage], settings: AIAnalysisSettings, context: AIAnalysisContext
    ) async throws -> ImageDetails {
        return try await performRequestWithRetry(images: images, settings: settings, context: context)
    }

    public func getMultiItemDetails(
        from images: [AIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        narrationContext: String? = nil,
        onPartialResponse: ((MultiItemAnalysisResponse) -> Void)? = nil
    ) async throws -> MultiItemAnalysisResponse {
        currentImageTask?.cancel()
        currentMultiItemTask?.cancel()

        currentMultiItemTask = Task<MultiItemAnalysisResponse, Error> {
            return try await performMultiItemStructuredResponseWithRetry(
                images: images,
                settings: settings,
                context: context,
                narrationContext: narrationContext,
                onPartialResponse: onPartialResponse
            )
        }

        defer {
            currentMultiItemTask = nil
        }

        return try await currentMultiItemTask!.value
    }

    public func cancelCurrentRequest() {
        currentImageTask?.cancel()
        currentMultiItemTask?.cancel()
        currentImageTask = nil
        currentMultiItemTask = nil
    }

    // MARK: - Multi-Item Structured Response Implementation

    private func performMultiItemStructuredResponseWithRetry(
        images: [AIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        narrationContext: String?,
        onPartialResponse: ((MultiItemAnalysisResponse) -> Void)?,
        maxAttempts: Int = 3
    ) async throws -> MultiItemAnalysisResponse {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            try Task.checkCancellation()

            do {
                return try await performSingleMultiItemStructuredRequest(
                    images: images,
                    settings: settings,
                    context: context,
                    narrationContext: narrationContext,
                    onPartialResponse: onPartialResponse,
                    attempt: attempt,
                    maxAttempts: maxAttempts
                )
            } catch {
                lastError = error

                if error is CancellationError {
                    throw error
                }

                if let aiProxyError = error as? AIProxyError {
                    switch aiProxyError {
                    case .unsuccessfulRequest(let statusCode, _):
                        switch statusCode {
                        case 429:
                            if attempt < maxAttempts {
                                print("🔄 Multi-item rate limited, retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw AIAnalysisError.rateLimitExceeded
                            }
                        case 500...599:
                            if attempt < maxAttempts {
                                print(
                                    "🔄 Multi-item server error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)"
                                )
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw AIAnalysisError.serverError("Server error \(statusCode)")
                            }
                        default:
                            print(
                                "🔄 Multi-item other AIProxy error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)"
                            )
                            if attempt < maxAttempts {
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw AIAnalysisError.serverError("AIProxy error \(statusCode)")
                            }
                        }
                    case .assertion, .deviceCheckIsUnavailable, .deviceCheckBypassIsMissing:
                        throw AIAnalysisError.serverError("AIProxy configuration error")
                    }
                }

                if let urlError = error as? URLError {
                    if attempt < maxAttempts {
                        print("🔄 Multi-item network error, retrying attempt \(attempt + 1)/\(maxAttempts)")
                        let delay = min(pow(2.0, Double(attempt)), 8.0)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        try Task.checkCancellation()
                        continue
                    } else {
                        throw AIAnalysisError.networkUnavailable
                    }
                }

                throw error
            }
        }

        throw lastError ?? AIAnalysisError.invalidResponse(statusCode: 0, responseData: "Unknown error")
    }

    private func performSingleMultiItemStructuredRequest(
        images: [AIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        narrationContext: String?,
        onPartialResponse: ((MultiItemAnalysisResponse) -> Void)?,
        attempt: Int,
        maxAttempts: Int
    ) async throws -> MultiItemAnalysisResponse {
        let startTime = Date()
        let imageCount = images.count

        print("🔄 Multi-item structured response attempt \(attempt)/\(maxAttempts)")

        let multiItemSchema = createMultiItemJSONSchema()

        let baseRequestBody = await requestBuilder.buildMultiItemRequestBody(
            with: images,
            settings: settings,
            context: context,
            narrationContext: narrationContext
        )

        let adjustedMaxTokens = calculateAITokenLimit(
            imageCount: imageCount,
            isPro: settings.isPro,
            highQualityEnabled: settings.highQualityAnalysisEnabled,
            isMultiItem: true
        )
        let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled

        print("🚀 Sending multi-item structured response request via AIProxy")
        print("📊 Images: \(imageCount)")
        print("⚙️ Quality: \(isHighQuality ? "High" : "Standard")")
        print("📝 Max tokens: \(adjustedMaxTokens)")

        if let onPartialResponse {
            do {
                return try await performSingleMultiItemStructuredStreamingRequest(
                    images: images,
                    settings: settings,
                    context: context,
                    narrationContext: narrationContext,
                    multiItemSchema: multiItemSchema,
                    onPartialResponse: onPartialResponse,
                    startTime: startTime,
                    adjustedMaxTokens: adjustedMaxTokens
                )
            } catch {
                if shouldFallbackToFunctionCalling(error) {
                    print("⚠️ Structured streaming failed; falling back to function calling: \(error)")
                    return try await performSingleMultiItemFunctionRequest(
                        images: images,
                        settings: settings,
                        context: context,
                        narrationContext: narrationContext,
                        attempt: attempt,
                        maxAttempts: maxAttempts
                    )
                }
                throw error
            }
        }

        let response: OpenRouterChatCompletionResponseBody
        do {
            response = try await requestBuilder.openRouterService
                .chatCompletionRequest(
                    body: .init(
                        messages: baseRequestBody.messages,
                        maxTokens: adjustedMaxTokens,
                        model: baseRequestBody.model,
                        responseFormat: .jsonSchema(
                            name: "multi_item_analysis",
                            description: "Analysis of multiple inventory items in the image",
                            schema: multiItemSchema,
                            strict: true
                        )
                    ),
                    secondsToWait: 60
                )
        } catch {
            if shouldFallbackToFunctionCalling(error) {
                print("⚠️ Structured response failed; falling back to function calling: \(error)")
                return try await performSingleMultiItemFunctionRequest(
                    images: images,
                    settings: settings,
                    context: context,
                    narrationContext: narrationContext,
                    attempt: attempt,
                    maxAttempts: maxAttempts
                )
            }
            throw error
        }

        print("✅ Received multi-item structured response with \(response.choices.count) choices")

        guard let choice = response.choices.first,
            let content = choice.message.content
        else {
            throw AIAnalysisError.invalidResponse(statusCode: 200, responseData: "No content in response")
        }

        print("📄 Structured response content length: \(content.count) characters")

        guard let responseData = content.data(using: .utf8) else {
            throw AIAnalysisError.invalidData
        }

        let result: MultiItemAnalysisResponse
        do {
            let decoded = try JSONDecoder().decode(MultiItemAnalysisResponse.self, from: responseData)
            result = responseParser.sanitizeMultiItemResponse(decoded)
            print("✅ Successfully decoded MultiItemAnalysisResponse with \(result.safeItems.count) items")
        } catch {
            print("❌ Failed to decode multi-item response: \(error)")
            print("📄 Raw response: \(content)")
            print("↩️ Falling back to function calling for multi-item")
            return try await performSingleMultiItemFunctionRequest(
                images: images,
                settings: settings,
                context: context,
                narrationContext: narrationContext,
                attempt: attempt,
                maxAttempts: maxAttempts
            )
        }

        if let usage = response.usage {
            let totalTokens = usage.totalTokens ?? 0
            let usagePercentage = Double(totalTokens) / Double(adjustedMaxTokens) * 100.0
            print(
                "📦 Multi-item response: \(result.safeItems.count) items (detectedCount: \(result.detectedCount)); token usage \(String(format: "%.1f", usagePercentage))% (\(totalTokens)/\(adjustedMaxTokens))"
            )
            self.logAIProxyTokenUsage(
                usage: usage,
                elapsedTime: Date().timeIntervalSince(startTime),
                imageCount: imageCount,
                settings: settings
            )
        } else {
            print(
                "📦 Multi-item response: \(result.safeItems.count) items (detectedCount: \(result.detectedCount)); token usage unavailable"
            )
        }

        return result
    }

    private func createMultiItemJSONSchema() -> [String: AIProxyJSONValue] {
        return [
            "type": "object",
            "properties": [
                "items": [
                    "type": "array",
                    "description": "Array of detected inventory items (include ALL distinct items; do not cap at 10)",
                    "items": [
                        "type": "object",
                        "properties": [
                            "id": [
                                "type": "string",
                                "description": "Unique identifier for the item",
                            ],
                            "title": [
                                "type": "string",
                                "description": "Descriptive name of the item",
                            ],
                            "description": [
                                "type": "string",
                                "description": "Detailed description of the item",
                            ],
                            "category": [
                                "type": "string",
                                "description": "Category classification for the item",
                            ],
                            "make": [
                                "type": "string",
                                "description": "Manufacturer or brand name",
                            ],
                            "model": [
                                "type": "string",
                                "description": "Model number or name",
                            ],
                            "estimatedPrice": [
                                "type": "string",
                                "description": "Estimated price with currency symbol",
                            ],
                            "confidence": [
                                "type": "number",
                                "description": "Confidence score between 0.0 and 1.0",
                            ],
                            "detections": [
                                "type": "array",
                                "description": "Bounding box detections for this item across source images",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "sourceImageIndex": [
                                            "type": "integer",
                                            "description": "0-indexed image number this detection is from",
                                        ],
                                        "boundingBox": [
                                            "type": "array",
                                            "description": "[ymin, xmin, ymax, xmax] normalized 0-1000",
                                            "items": ["type": "integer"],
                                        ],
                                    ],
                                    "required": ["sourceImageIndex", "boundingBox"],
                                    "additionalProperties": false,
                                ],
                            ],
                        ],
                        "required": [
                            "id", "title", "description", "category", "make", "model", "estimatedPrice", "confidence",
                            "detections",
                        ],
                        "additionalProperties": false,
                    ],
                ],
                "detectedCount": [
                    "type": "integer",
                    "description": "Total number of items detected (must match items array length)",
                ],
                "analysisType": [
                    "type": "string",
                    "description": "Must be 'multi_item'",
                ],
                "confidence": [
                    "type": "number",
                    "description": "Overall confidence in the analysis between 0.0 and 1.0",
                ],
            ],
            "required": ["items", "detectedCount", "analysisType", "confidence"],
            "additionalProperties": false,
        ]
    }

    private func performSingleMultiItemStructuredStreamingRequest(
        images: [AIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        narrationContext: String?,
        multiItemSchema: [String: AIProxyJSONValue],
        onPartialResponse: (MultiItemAnalysisResponse) -> Void,
        startTime: Date,
        adjustedMaxTokens: Int
    ) async throws -> MultiItemAnalysisResponse {
        let imageCount = images.count
        let baseRequestBody = await requestBuilder.buildMultiItemRequestBody(
            with: images,
            settings: settings,
            context: context,
            narrationContext: narrationContext
        )

        let stream = try await requestBuilder.openRouterService
            .streamingChatCompletionRequest(
                body: .init(
                    messages: baseRequestBody.messages,
                    maxTokens: adjustedMaxTokens,
                    model: baseRequestBody.model,
                    responseFormat: .jsonSchema(
                        name: "multi_item_analysis",
                        description: "Analysis of multiple inventory items in the image",
                        schema: multiItemSchema,
                        strict: true
                    )
                ),
                secondsToWait: 60
            )

        var contentBuffer = ""
        var toolArgumentsBuffer = ""
        var usage: OpenRouterChatCompletionResponseBody.Usage?
        var lastEmittedFingerprint: String?

        for try await chunk in stream {
            if let chunkUsage = chunk.usage {
                usage = chunkUsage
            }

            for choice in chunk.choices {
                if let content = choice.delta.content, !content.isEmpty {
                    contentBuffer += content
                }

                if let toolCalls = choice.delta.toolCalls {
                    for toolCall in toolCalls {
                        if let arguments = toolCall.function?.arguments, !arguments.isEmpty {
                            toolArgumentsBuffer += arguments
                        }
                    }
                }
            }

            let payload = contentBuffer.isEmpty ? toolArgumentsBuffer : contentBuffer
            if let partial = extractPartialMultiItemResponse(from: payload) {
                let fingerprint = partialFingerprint(for: partial)
                if fingerprint != lastEmittedFingerprint {
                    lastEmittedFingerprint = fingerprint
                    onPartialResponse(partial)
                }
            }
        }

        let finalPayload = contentBuffer.isEmpty ? toolArgumentsBuffer : contentBuffer
        guard let responseData = finalPayload.data(using: .utf8) else {
            throw AIAnalysisError.invalidData
        }

        let decoded = try JSONDecoder().decode(MultiItemAnalysisResponse.self, from: responseData)
        let result = responseParser.sanitizeMultiItemResponse(decoded)
        onPartialResponse(result)

        if let usage {
            let totalTokens = usage.totalTokens ?? 0
            let usagePercentage = Double(totalTokens) / Double(adjustedMaxTokens) * 100.0
            print(
                "📦 Multi-item streamed response: \(result.safeItems.count) items (detectedCount: \(result.detectedCount)); token usage \(String(format: "%.1f", usagePercentage))% (\(totalTokens)/\(adjustedMaxTokens))"
            )
            self.logAIProxyTokenUsage(
                usage: usage,
                elapsedTime: Date().timeIntervalSince(startTime),
                imageCount: imageCount,
                settings: settings
            )
        } else {
            print(
                "📦 Multi-item streamed response: \(result.safeItems.count) items (detectedCount: \(result.detectedCount)); token usage unavailable"
            )
        }

        return result
    }

    private func extractPartialMultiItemResponse(from payload: String) -> MultiItemAnalysisResponse? {
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPayload.isEmpty else { return nil }

        if let complete = decodeMultiItemResponse(from: trimmedPayload) {
            return complete
        }

        let itemJSONObjects = extractCompleteItemObjects(from: trimmedPayload)
        guard !itemJSONObjects.isEmpty else { return nil }

        let decodedItems: [DetectedInventoryItem] = itemJSONObjects.compactMap { itemJSON in
            guard let data = itemJSON.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(DetectedInventoryItem.self, from: data)
        }

        guard !decodedItems.isEmpty else { return nil }

        let inferredConfidence = extractTopLevelNumber(forKey: "confidence", in: trimmedPayload) ?? 0.7
        return responseParser.sanitizeMultiItemResponse(
            MultiItemAnalysisResponse(
                items: decodedItems,
                detectedCount: decodedItems.count,
                analysisType: "multi_item",
                confidence: inferredConfidence
            )
        )
    }

    private func decodeMultiItemResponse(from payload: String) -> MultiItemAnalysisResponse? {
        guard let data = payload.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(MultiItemAnalysisResponse.self, from: data)
        else {
            return nil
        }

        return responseParser.sanitizeMultiItemResponse(decoded)
    }

    private func partialFingerprint(for response: MultiItemAnalysisResponse) -> String {
        response.safeItems
            .map {
                "\($0.id)|\($0.title)|\($0.make)|\($0.model)|\($0.estimatedPrice)|\($0.detections?.count ?? 0)"
            }
            .joined(separator: "||")
    }

    private func extractTopLevelNumber(forKey key: String, in payload: String) -> Double? {
        let pattern = "\"\(NSRegularExpression.escapedPattern(for: key))\"\\s*:\\s*([0-9]+(?:\\.[0-9]+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(payload.startIndex..<payload.endIndex, in: payload)
        guard
            let match = regex.firstMatch(in: payload, options: [], range: range),
            let valueRange = Range(match.range(at: 1), in: payload)
        else {
            return nil
        }

        return Double(payload[valueRange])
    }

    private func extractCompleteItemObjects(from payload: String) -> [String] {
        guard let itemsKeyRange = payload.range(of: "\"items\""),
            let arrayStart = payload[itemsKeyRange.upperBound...].firstIndex(of: "[")
        else {
            return []
        }

        var itemObjects: [String] = []
        var depth = 0
        var inString = false
        var isEscaping = false
        var currentObjectStart: String.Index?
        var index = payload.index(after: arrayStart)

        while index < payload.endIndex {
            let character = payload[index]

            if inString {
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    if depth == 0 {
                        currentObjectStart = index
                    }
                    depth += 1
                } else if character == "}" {
                    if depth > 0 {
                        depth -= 1
                        if depth == 0, let objectStart = currentObjectStart {
                            itemObjects.append(String(payload[objectStart...index]))
                            currentObjectStart = nil
                        }
                    }
                } else if character == "]", depth == 0 {
                    break
                }
            }

            index = payload.index(after: index)
        }

        return itemObjects
    }

    private func performSingleMultiItemFunctionRequest(
        images: [AIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        narrationContext: String?,
        attempt: Int,
        maxAttempts: Int
    ) async throws -> MultiItemAnalysisResponse {
        let startTime = Date()
        let imageCount = images.count

        let requestBody = await requestBuilder.buildMultiItemRequestBody(
            with: images,
            settings: settings,
            context: context,
            narrationContext: narrationContext
        )

        if attempt == 1 {
            let adjustedMaxTokens = calculateAITokenLimit(
                imageCount: imageCount,
                isPro: settings.isPro,
                highQualityEnabled: settings.highQualityAnalysisEnabled,
                isMultiItem: true
            )
            let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
            print("🚀 Sending multi-item function request via AIProxy (fallback)")
            print("📊 Images: \(imageCount)")
            print("⚙️ Quality: \(isHighQuality ? "High" : "Standard")")
            print("📝 Max tokens: \(adjustedMaxTokens)")
        } else {
            print("🔄 Retry attempt \(attempt)/\(maxAttempts) (fallback)")
        }

        let response: OpenRouterChatCompletionResponseBody = try await requestBuilder.openRouterService
            .chatCompletionRequest(body: requestBody, secondsToWait: 60)

        print("✅ Received multi-item function response with \(response.choices.count) choices")

        let parseResult = try responseParser.parseAIProxyMultiItemResponse(
            response: response,
            imageCount: imageCount,
            startTime: startTime,
            settings: settings
        )

        if let usage = response.usage {
            let adjustedMaxTokens = calculateAITokenLimit(
                imageCount: imageCount,
                isPro: settings.isPro,
                highQualityEnabled: settings.highQualityAnalysisEnabled,
                isMultiItem: true
            )
            let totalTokens = usage.totalTokens ?? 0
            let usagePercentage = Double(totalTokens) / Double(adjustedMaxTokens) * 100.0
            let formattedUsage = String(format: "%.1f", usagePercentage)
            print(
                "📦 Multi-item response (fallback): \(parseResult.response.safeItems.count) items (detectedCount: \(parseResult.response.detectedCount)); token usage \(formattedUsage)% (\(totalTokens)/\(adjustedMaxTokens))"
            )
            self.logAIProxyTokenUsage(
                usage: usage,
                elapsedTime: Date().timeIntervalSince(startTime),
                imageCount: imageCount,
                settings: settings
            )
        } else {
            print(
                "📦 Multi-item response (fallback): \(parseResult.response.safeItems.count) items (detectedCount: \(parseResult.response.detectedCount)); token usage unavailable"
            )
        }

        return parseResult.response
    }

    private func shouldFallbackToFunctionCalling(_ error: Error) -> Bool {
        if error is DecodingError {
            return true
        }

        if let aiProxyError = error as? AIProxyError {
            switch aiProxyError {
            case .unsuccessfulRequest(_, let responseBody):
                let lowerBody = responseBody.lowercased()
                if lowerBody.contains("response_format")
                    || lowerBody.contains("json_schema")
                    || lowerBody.contains("json schema")
                    || (lowerBody.contains("schema") && lowerBody.contains("unsupported"))
                    || (lowerBody.contains("stream") && lowerBody.contains("unsupported"))
                    || lowerBody.contains("cannot stream")
                {
                    return true
                }
            default:
                break
            }
        }

        let lowerDescription = error.localizedDescription.lowercased()
        if lowerDescription.contains("choices") && lowerDescription.contains("keynotfound") {
            return true
        }

        return false
    }

    // MARK: - Single-Item Analysis

    private func performRequestWithRetry(
        images: [AIImage], settings: AIAnalysisSettings, context: AIAnalysisContext, maxAttempts: Int = 3
    ) async throws -> ImageDetails {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            try Task.checkCancellation()

            do {
                return try await performSingleRequest(
                    images: images, settings: settings, context: context, attempt: attempt,
                    maxAttempts: maxAttempts)
            } catch {
                lastError = error

                if error is CancellationError {
                    throw error
                }

                if let aiProxyError = error as? AIProxyError {
                    switch aiProxyError {
                    case .unsuccessfulRequest(let statusCode, let responseBody):
                        print("🌐 AIProxy error \(statusCode): \(responseBody)")

                        switch statusCode {
                        case 429:
                            if attempt < maxAttempts {
                                print("⏱️ Rate limited, retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw AIAnalysisError.rateLimitExceeded
                            }
                        case 413:
                            throw AIAnalysisError.invalidResponse(statusCode: statusCode, responseData: responseBody)
                        case 500...599:
                            if attempt < maxAttempts {
                                print("🔄 Server error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)")
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw AIAnalysisError.serverError("Server error \(statusCode)")
                            }
                        case 400...499:
                            throw AIAnalysisError.invalidResponse(statusCode: statusCode, responseData: responseBody)
                        default:
                            if attempt < maxAttempts {
                                print(
                                    "🔄 Unknown AIProxy error \(statusCode), retrying attempt \(attempt + 1)/\(maxAttempts)"
                                )
                                let delay = min(pow(2.0, Double(attempt)), 8.0)
                                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                try Task.checkCancellation()
                                continue
                            } else {
                                throw AIAnalysisError.serverError("Unknown AIProxy error occurred")
                            }
                        }
                    case .assertion, .deviceCheckIsUnavailable, .deviceCheckBypassIsMissing:
                        throw AIAnalysisError.serverError("AIProxy configuration error")
                    }
                }

                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .cancelled:
                        if attempt < maxAttempts {
                            print("🔄 Request cancelled, retrying attempt \(attempt + 1)/\(maxAttempts)")
                            let delay = min(pow(2.0, Double(attempt)), 8.0)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation()
                            continue
                        } else {
                            throw AIAnalysisError.networkCancelled
                        }
                    case .timedOut:
                        if attempt < maxAttempts {
                            print("⏱️ Request timed out, retrying attempt \(attempt + 1)/\(maxAttempts)")
                            let delay = min(pow(2.0, Double(attempt)), 8.0)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation()
                            continue
                        } else {
                            throw AIAnalysisError.networkTimeout
                        }
                    case .notConnectedToInternet, .networkConnectionLost:
                        if attempt < maxAttempts {
                            print(
                                "🌐 Network error: \(urlError.localizedDescription), retrying attempt \(attempt + 1)/\(maxAttempts)"
                            )
                            let delay = min(pow(2.0, Double(attempt)), 8.0)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            try Task.checkCancellation()
                            continue
                        } else {
                            throw AIAnalysisError.networkUnavailable
                        }
                    default:
                        throw AIAnalysisError.serverError(urlError.localizedDescription)
                    }
                }

                throw error
            }
        }

        throw lastError ?? AIAnalysisError.invalidResponse(statusCode: 0, responseData: "Unknown error")
    }

    private func performSingleRequest(
        images: [AIImage], settings: AIAnalysisSettings, context: AIAnalysisContext, attempt: Int, maxAttempts: Int
    ) async throws -> ImageDetails {
        let startTime = Date()
        let imageCount = images.count

        let requestBody = await requestBuilder.buildRequestBody(
            with: images,
            settings: settings,
            context: context
        )

        if attempt == 1 {
            let adjustedMaxTokens = calculateAITokenLimit(
                imageCount: imageCount,
                isPro: settings.isPro,
                highQualityEnabled: settings.highQualityAnalysisEnabled
            )
            let isHighQuality = settings.isPro && settings.highQualityAnalysisEnabled

            print("🚀 Sending \(imageCount == 1 ? "single" : "multi") image request via AIProxy")
            print("📊 Images: \(imageCount)")
            print("⚙️ Quality: \(isHighQuality ? "High" : "Standard")")
            print("📝 Max tokens: \(adjustedMaxTokens)")
        } else {
            print("🔄 Retry attempt \(attempt)/\(maxAttempts)")
        }

        let response: OpenRouterChatCompletionResponseBody = try await requestBuilder.openRouterService
            .chatCompletionRequest(
                body: requestBody, secondsToWait: 60)

        print("✅ Received AIProxy response with \(response.choices.count) choices")

        do {
            let parseResult = try await responseParser.parseAIProxyResponse(
                response: response,
                imageCount: imageCount,
                startTime: startTime,
                settings: settings
            )

            return parseResult.imageDetails
        } catch {
            print("❌ Failed to parse response: \(error)")
            throw error
        }
    }

    @MainActor
    private func logAIProxyTokenUsage(
        usage: OpenRouterChatCompletionResponseBody.Usage,
        elapsedTime: TimeInterval,
        imageCount: Int,
        settings: AIAnalysisSettings
    ) {
        print("💰 TOKEN USAGE REPORT")
        print("   📊 Total tokens: \(usage.totalTokens ?? 0)")
        print("   📝 Prompt tokens: \(usage.promptTokens ?? 0)")
        print("   🤖 Completion tokens: \(usage.completionTokens ?? 0)")
        print("   ⏱️ Request time: \(String(format: "%.2f", elapsedTime))s")
        print("   🖼️ Images: \(imageCount) (\(imageCount == 1 ? "single" : "multi")-photo analysis)")

        let totalTokens = usage.totalTokens ?? 0
        let tokensPerSecond = Double(totalTokens) / elapsedTime
        print("   🚀 Efficiency: \(String(format: "%.1f", tokensPerSecond)) tokens/sec")

        let adjustedMaxTokens = calculateAITokenLimit(
            imageCount: imageCount,
            isPro: settings.isPro,
            highQualityEnabled: settings.highQualityAnalysisEnabled,
            isMultiItem: true
        )
        let usagePercentage = Double(totalTokens) / Double(adjustedMaxTokens) * 100.0

        if usagePercentage > 90.0 {
            print(
                "⚠️ WARNING: Token usage at \(String(format: "%.1f", usagePercentage))% of limit (\(totalTokens)/\(adjustedMaxTokens))"
            )
        } else if usagePercentage > 75.0 {
            print(
                "⚡ High token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(totalTokens)/\(adjustedMaxTokens))"
            )
        } else {
            print(
                "✅ Token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(totalTokens)/\(adjustedMaxTokens))"
            )
        }

        telemetryTracker?.trackAITokenUsage(
            totalTokens: usage.totalTokens ?? 0,
            promptTokens: usage.promptTokens ?? 0,
            completionTokens: usage.completionTokens ?? 0,
            requestTimeSeconds: elapsedTime,
            imageCount: imageCount,
            isProUser: settings.isPro,
            model: settings.effectiveAIModel
        )
    }
}
