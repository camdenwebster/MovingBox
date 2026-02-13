//
//  AIAnalysisService+Database.swift
//  MovingBox
//
//  Protocol conformances bridging app types to MovingBoxAIAnalysis package using sqlite-data.
//

import Foundation
import MovingBoxAIAnalysis
import SQLiteData
import UIKit

// MARK: - SettingsManager conforms to AIAnalysisSettings

extension SettingsManager: AIAnalysisSettings {}

// MARK: - OptimizedImageManager conforms to AIImageOptimizer

extension OptimizedImageManager: AIImageOptimizer {
    public func optimizeImage(_ image: UIImage, maxDimension: CGFloat) async -> UIImage {
        await optimizeImage(image, maxDimension: Optional(maxDimension))
    }
}

// MARK: - TelemetryManager conforms to AITelemetryTracker

extension TelemetryManager: AITelemetryTracker {}

// MARK: - AIAnalysisContext Builder for sqlite-data

extension AIAnalysisContext {
    /// Build an `AIAnalysisContext` from a SQLite database reader and SettingsManager,
    /// pre-fetching labels and locations filtered by the active home.
    @MainActor
    static func from(database: any DatabaseReader, settings: SettingsManager) async -> AIAnalysisContext {
        let homes =
            (try? await database.read { db in
                try SQLiteHome.order(by: \.purchaseDate).fetchAll(db)
            }) ?? []

        let activeHome: SQLiteHome?
        if let activeIdString = settings.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        {
            activeHome = homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
        } else {
            activeHome = homes.first { $0.isPrimary }
        }

        let allLabelObjects =
            (try? await database.read { db in
                try SQLiteInventoryLabel.all.fetchAll(db)
            }) ?? []

        let allLocationObjects =
            (try? await database.read { db in
                try SQLiteInventoryLocation.all.fetchAll(db)
            }) ?? []

        let filteredLocationObjects: [SQLiteInventoryLocation]
        if let home = activeHome {
            filteredLocationObjects = allLocationObjects.filter { $0.homeID == home.id }
        } else {
            filteredLocationObjects = allLocationObjects
        }

        let labels = allLabelObjects.map { $0.name }
        let locations = filteredLocationObjects.map { $0.name }

        return AIAnalysisContext(labels: labels, locations: locations)
    }
}
