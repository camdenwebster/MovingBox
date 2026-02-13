//
//  AIResponseParser.swift
//  MovingBoxAIAnalysis
//

import AIProxy
import Foundation

// MARK: - Token Usage Types

struct TokenUsage: Decodable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
    let prompt_tokens_details: PromptTokensDetails?
    let completion_tokens_details: CompletionTokensDetails?
}

struct PromptTokensDetails: Decodable {
    let cached_tokens: Int?
    let audio_tokens: Int?
}

struct CompletionTokensDetails: Decodable {
    let reasoning_tokens: Int?
    let audio_tokens: Int?
    let accepted_prediction_tokens: Int?
    let rejected_prediction_tokens: Int?
}

// MARK: - Parse Results

public struct ParseResult {
    public let imageDetails: ImageDetails
    let usage: TokenUsage?
}

public struct MultiItemParseResult {
    public let response: MultiItemAnalysisResponse
    let usage: TokenUsage?
}

// MARK: - Response Parser

public struct AIResponseParser {

    public init() {}

    func sanitizeString(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ""
        }

        let normalized = trimmed.lowercased()
        let badExactValues: Set<String> = [
            "unknown",
            "unknown item",
            "n/a",
            "na",
            "none",
            "not available",
            "not specified",
            "unavailable",
            "not found",
        ]

        if badExactValues.contains(normalized) {
            return ""
        }

        let badSubstrings = [
            "no serial number",
            "serial number not found",
            "serial not found",
            "not visible",
            "unable to determine",
            "could not determine",
        ]

        if badSubstrings.contains(where: { normalized.contains($0) }) {
            return ""
        }

        return trimmed
    }

    private func sanitizeOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let sanitized = sanitizeString(value)
        return sanitized.isEmpty ? nil : sanitized
    }

    private func sanitizeCategories(_ categories: [String]) -> [String] {
        categories
            .map { sanitizeString($0) }
            .filter { !$0.isEmpty }
    }

    func sanitizeImageDetails(_ details: ImageDetails) -> ImageDetails {
        let sanitizedCategories = sanitizeCategories(details.categories)
        let sanitizedCategory = sanitizeString(details.category)
        let finalCategory = sanitizedCategory.isEmpty ? (sanitizedCategories.first ?? "") : sanitizedCategory

        return ImageDetails(
            title: sanitizeString(details.title),
            quantity: sanitizeString(details.quantity),
            description: sanitizeString(details.description),
            make: sanitizeString(details.make),
            model: sanitizeString(details.model),
            category: finalCategory,
            categories: sanitizedCategories,
            location: sanitizeString(details.location),
            price: sanitizeString(details.price),
            serialNumber: sanitizeString(details.serialNumber),
            condition: sanitizeOptional(details.condition),
            color: sanitizeOptional(details.color),
            dimensions: sanitizeOptional(details.dimensions),
            dimensionLength: sanitizeOptional(details.dimensionLength),
            dimensionWidth: sanitizeOptional(details.dimensionWidth),
            dimensionHeight: sanitizeOptional(details.dimensionHeight),
            dimensionUnit: sanitizeOptional(details.dimensionUnit),
            weightValue: sanitizeOptional(details.weightValue),
            weightUnit: sanitizeOptional(details.weightUnit),
            purchaseLocation: sanitizeOptional(details.purchaseLocation),
            replacementCost: sanitizeOptional(details.replacementCost),
            depreciationRate: sanitizeOptional(details.depreciationRate),
            storageRequirements: sanitizeOptional(details.storageRequirements),
            isFragile: sanitizeOptional(details.isFragile)
        )
    }

    func sanitizeDetectedItem(_ item: DetectedInventoryItem) -> DetectedInventoryItem {
        return DetectedInventoryItem(
            id: item.id,
            title: sanitizeString(item.title),
            description: sanitizeString(item.description),
            category: sanitizeString(item.category),
            make: sanitizeString(item.make),
            model: sanitizeString(item.model),
            estimatedPrice: sanitizeString(item.estimatedPrice),
            confidence: item.confidence,
            detections: item.detections
        )
    }

    public func sanitizeMultiItemResponse(_ response: MultiItemAnalysisResponse) -> MultiItemAnalysisResponse {
        let sanitizedItems = response.items?.map { sanitizeDetectedItem($0) }
        return MultiItemAnalysisResponse(
            items: sanitizedItems,
            detectedCount: response.detectedCount,
            analysisType: response.analysisType,
            confidence: response.confidence
        )
    }

    @MainActor
    public func parseAIProxyResponse(
        response: OpenRouterChatCompletionResponseBody,
        imageCount: Int,
        startTime: Date,
        settings: AIAnalysisSettings
    ) throws -> ParseResult {
        print("✅ Processing AIProxy response with \(response.choices.count) choices")

        if response.usage == nil {
            print("⚠️ No token usage information in response")
        }

        guard let choice = response.choices.first else {
            print("❌ No choices in response")
            throw AIAnalysisError.invalidData
        }

        guard let toolCalls = choice.message.toolCalls, !toolCalls.isEmpty else {
            print("❌ No tool calls in response")
            print("📝 Response message: \(choice.message)")
            throw AIAnalysisError.invalidData
        }

        let toolCall = toolCalls[0]
        guard let function = toolCall.function else {
            print("❌ Tool call missing function payload")
            throw AIAnalysisError.invalidData
        }
        print("🎯 Tool call received: \(function.name)")

        let argumentsString = function.argumentsRaw ?? ""
        print("📄 Arguments length: \(argumentsString.count) characters")

        guard let responseData = argumentsString.data(using: String.Encoding.utf8) else {
            print("❌ Cannot convert function arguments to data")
            print("📄 Raw arguments: \(argumentsString)")
            throw AIAnalysisError.invalidData
        }

        let decoded = try JSONDecoder().decode(ImageDetails.self, from: responseData)
        let result = sanitizeImageDetails(decoded)

        let tokenUsage = response.usage != nil ? convertAIProxyUsage(response.usage!) : nil

        return ParseResult(imageDetails: result, usage: tokenUsage)
    }

    @MainActor
    public func parseAIProxyMultiItemResponse(
        response: OpenRouterChatCompletionResponseBody,
        imageCount: Int,
        startTime: Date,
        settings: AIAnalysisSettings
    ) throws -> MultiItemParseResult {
        print("✅ Processing multi-item AIProxy response with \(response.choices.count) choices")

        if response.usage == nil {
            print("⚠️ No token usage information in response")
        }

        guard let choice = response.choices.first else {
            print("❌ No choices in response")
            throw AIAnalysisError.invalidData
        }

        guard let toolCalls = choice.message.toolCalls, !toolCalls.isEmpty else {
            print("❌ No tool calls in response")
            print("📝 Response message: \(choice.message)")
            throw AIAnalysisError.invalidData
        }

        let toolCall = toolCalls[0]
        guard let function = toolCall.function else {
            print("❌ Tool call missing function payload")
            throw AIAnalysisError.invalidData
        }
        print("🎯 Tool call received: \(function.name)")

        let argumentsString = function.argumentsRaw ?? ""
        print("📄 Arguments length: \(argumentsString.count) characters")

        guard let responseData = argumentsString.data(using: String.Encoding.utf8) else {
            print("❌ Cannot convert function arguments to data")
            print("📄 Raw arguments: \(argumentsString)")
            throw AIAnalysisError.invalidData
        }

        let decoded = try JSONDecoder().decode(MultiItemAnalysisResponse.self, from: responseData)
        let result = sanitizeMultiItemResponse(decoded)
        let tokenUsage = response.usage != nil ? convertAIProxyUsage(response.usage!) : nil

        return MultiItemParseResult(response: result, usage: tokenUsage)
    }

    private func convertAIProxyUsage(_ aiProxyUsage: OpenRouterChatCompletionResponseBody.Usage) -> TokenUsage {
        return TokenUsage(
            prompt_tokens: aiProxyUsage.promptTokens ?? 0,
            completion_tokens: aiProxyUsage.completionTokens ?? 0,
            total_tokens: aiProxyUsage.totalTokens ?? 0,
            prompt_tokens_details: nil,
            completion_tokens_details: nil
        )
    }

    @MainActor
    func logTokenUsage(
        usage: TokenUsage,
        elapsedTime: TimeInterval,
        requestSize: Int,
        imageCount: Int,
        settings: AIAnalysisSettings,
        telemetryTracker: AITelemetryTracker?
    ) {
        let requestSizeMB = Double(requestSize) / 1_000_000.0

        print("💰 TOKEN USAGE REPORT")
        print("   📊 Total tokens: \(usage.total_tokens)")
        print("   📝 Prompt tokens: \(usage.prompt_tokens)")
        print("   🤖 Completion tokens: \(usage.completion_tokens)")
        print("   ⏱️ Request time: \(String(format: "%.2f", elapsedTime))s")
        print("   📦 Request size: \(String(format: "%.2f", requestSizeMB))MB")
        print("   🖼️ Images: \(imageCount) (\(imageCount == 1 ? "single" : "multi")-photo analysis)")

        let tokensPerSecond = Double(usage.total_tokens) / elapsedTime
        let tokensPerMB = Double(usage.total_tokens) / max(requestSizeMB, 0.001)
        print(
            "   🚀 Efficiency: \(String(format: "%.1f", tokensPerSecond)) tokens/sec, \(String(format: "%.0f", tokensPerMB)) tokens/MB"
        )

        if let promptDetails = usage.prompt_tokens_details {
            print("   📋 Prompt details:")
            if let cached = promptDetails.cached_tokens {
                print("      🗄️ Cached tokens: \(cached)")
            }
            if let audio = promptDetails.audio_tokens {
                print("      🎵 Audio tokens: \(audio)")
            }
        }

        if let completionDetails = usage.completion_tokens_details {
            print("   📝 Completion details:")
            if let reasoning = completionDetails.reasoning_tokens {
                print("      🧠 Reasoning tokens: \(reasoning)")
            }
            if let audio = completionDetails.audio_tokens {
                print("      🎵 Audio tokens: \(audio)")
            }
            if let accepted = completionDetails.accepted_prediction_tokens {
                print("      ✅ Accepted prediction tokens: \(accepted)")
            }
            if let rejected = completionDetails.rejected_prediction_tokens {
                print("      ❌ Rejected prediction tokens: \(rejected)")
            }
        }

        let adjustedMaxTokens = calculateAITokenLimit(
            imageCount: imageCount,
            isPro: settings.isPro,
            highQualityEnabled: settings.highQualityAnalysisEnabled
        )
        let usagePercentage = Double(usage.total_tokens) / Double(adjustedMaxTokens) * 100.0

        if usagePercentage > 90.0 {
            print(
                "⚠️ WARNING: Token usage at \(String(format: "%.1f", usagePercentage))% of limit (\(usage.total_tokens)/\(adjustedMaxTokens))"
            )
        } else if usagePercentage > 75.0 {
            print(
                "⚡ High token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(usage.total_tokens)/\(adjustedMaxTokens))"
            )
        } else {
            print(
                "✅ Token usage: \(String(format: "%.1f", usagePercentage))% of limit (\(usage.total_tokens)/\(adjustedMaxTokens))"
            )
        }

        telemetryTracker?.trackAITokenUsage(
            totalTokens: usage.total_tokens,
            promptTokens: usage.prompt_tokens,
            completionTokens: usage.completion_tokens,
            requestTimeSeconds: elapsedTime,
            imageCount: imageCount,
            isProUser: settings.isPro,
            model: settings.effectiveAIModel
        )
    }
}
