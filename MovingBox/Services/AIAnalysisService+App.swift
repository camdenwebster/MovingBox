//
//  AIAnalysisService+App.swift
//  MovingBox
//
//  Protocol conformances bridging app types to MovingBoxAIAnalysis package.
//

import Foundation
import MovingBoxAIAnalysis
import SwiftData
import UIKit

// MARK: - SettingsManager conforms to AIAnalysisSettings

extension SettingsManager: @retroactive AIAnalysisSettings {}

// MARK: - OptimizedImageManager conforms to AIImageOptimizer

extension OptimizedImageManager: @retroactive AIImageOptimizer {
    public func optimizeImage(_ image: UIImage, maxDimension: CGFloat) async -> UIImage {
        await optimizeImage(image, maxDimension: Optional(maxDimension))
    }
}

// MARK: - TelemetryManager conforms to AITelemetryTracker

extension TelemetryManager: @retroactive AITelemetryTracker {}

// MARK: - AIAnalysisContext Builder

extension AIAnalysisContext {
    /// Build an `AIAnalysisContext` from a SwiftData `ModelContext` and `SettingsManager`,
    /// pre-fetching labels and locations filtered by the active home.
    @MainActor
    static func from(modelContext: ModelContext, settings: SettingsManager) -> AIAnalysisContext {
        let homeDescriptor = FetchDescriptor<Home>(sortBy: [SortDescriptor(\Home.purchaseDate)])
        let homes = (try? modelContext.fetch(homeDescriptor)) ?? []

        let activeHome: Home?
        if let activeIdString = settings.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        {
            activeHome = homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
        } else {
            activeHome = homes.first { $0.isPrimary }
        }

        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        let allLabelObjects = (try? modelContext.fetch(labelDescriptor)) ?? []
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        let allLocationObjects = (try? modelContext.fetch(locationDescriptor)) ?? []

        let filteredLocationObjects =
            activeHome != nil
            ? allLocationObjects.filter { $0.home?.id == activeHome?.id }
            : allLocationObjects

        let labels = allLabelObjects.map { $0.name }
        let locations = filteredLocationObjects.map { $0.name }

        return AIAnalysisContext(labels: labels, locations: locations)
    }
}
