//
//  AIAnalysisProtocols.swift
//  MovingBoxAIAnalysis
//

import Foundation
import UIKit

// MARK: - Service Protocol

public protocol AIAnalysisServiceProtocol {
    func getImageDetails(from images: [UIImage], settings: AIAnalysisSettings, context: AIAnalysisContext) async throws
        -> ImageDetails
    func analyzeItem(from images: [UIImage], settings: AIAnalysisSettings, context: AIAnalysisContext) async throws
        -> ImageDetails
    func getMultiItemDetails(
        from images: [UIImage],
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        narrationContext: String?,
        onPartialResponse: ((MultiItemAnalysisResponse) -> Void)?
    ) async throws -> MultiItemAnalysisResponse
    func cancelCurrentRequest()
}

extension AIAnalysisServiceProtocol {
    public func getMultiItemDetails(
        from images: [UIImage],
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
}

// MARK: - Image Optimizer Abstraction

public protocol AIImageOptimizer: Sendable {
    func optimizeImage(_ image: UIImage, maxDimension: CGFloat) async -> UIImage
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
