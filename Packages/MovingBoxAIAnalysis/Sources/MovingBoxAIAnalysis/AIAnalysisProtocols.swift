//
//  AIAnalysisProtocols.swift
//  MovingBoxAIAnalysis
//

import CoreGraphics
import Foundation

// MARK: - Service Protocol

public protocol AIAnalysisServiceProtocol {
    func getImageDetails(from images: [AIImage], settings: AIAnalysisSettings, context: AIAnalysisContext) async throws
        -> ImageDetails
    func analyzeItem(from images: [AIImage], settings: AIAnalysisSettings, context: AIAnalysisContext) async throws
        -> ImageDetails
    func getMultiItemDetails(
        from images: [AIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        narrationContext: String?,
        onPartialResponse: ((MultiItemAnalysisResponse) -> Void)?
    ) async throws -> MultiItemAnalysisResponse
    func cancelCurrentRequest()
}

extension AIAnalysisServiceProtocol {
    public func getMultiItemDetails(
        from images: [AIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        narrationContext: String?
    ) async throws -> MultiItemAnalysisResponse {
        return try await getMultiItemDetails(
            from: images,
            settings: settings,
            context: context,
            narrationContext: narrationContext,
            onPartialResponse: nil
        )
    }
}

// MARK: - Settings Abstraction

public protocol AIAnalysisSettings: Sendable {
    var isPro: Bool { get }
    var highQualityAnalysisEnabled: Bool { get }
    var effectiveAIModel: String { get }
    var effectiveImageResolution: CGFloat { get }
    var effectiveDetailLevel: String { get }
}

// MARK: - Image Optimizer Abstraction

public protocol AIImageOptimizer: Sendable {
    func optimizeImage(_ image: AIImage, maxDimension: CGFloat) async -> AIImage
}

// MARK: - Telemetry Abstraction

public protocol AITelemetryTracker: Sendable {
    func trackAITokenUsage(
        totalTokens: Int, promptTokens: Int, completionTokens: Int,
        requestTimeSeconds: Double, imageCount: Int, isProUser: Bool, model: String
    )
}

// MARK: - Analysis Context

public struct AIAnalysisContext: Sendable {
    public let labels: [String]
    public let locations: [String]

    public init(labels: [String], locations: [String]) {
        self.labels = labels
        self.locations = locations
    }
}
