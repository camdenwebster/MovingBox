//
//  SceneDelegate.swift
//  MovingBox
//
//  Created by Camden Webster on 2/4/26.
//

import CloudKit
import Dependencies
import OSLog
import SQLiteData
import UIKit

private let logger = Logger(subsystem: "com.mothersound.movingbox", category: "SceneDelegate")

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    @Dependency(\.defaultSyncEngine) var syncEngine
    @Dependency(\.defaultDatabase) var database

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Handle share acceptance when app launches from share invitation
        if let shareMetadata = connectionOptions.cloudKitShareMetadata {
            handleShareMetadata(shareMetadata)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        // Handle share acceptance when app is already running
        handleShareMetadata(cloudKitShareMetadata)
    }

    private func handleShareMetadata(_ shareMetadata: CKShare.Metadata) {
        if OnboardingManager.shouldShowWelcome() {
            // First launch from share link — defer to joining flow.
            MainActor.assumeIsolated {
                ShareMetadataStore.shared.pendingShareMetadata = shareMetadata
            }
            return
        }

        Task {
            let hasExistingData = await Self.hasExistingDataForShareAcceptance(database: database)
            if hasExistingData {
                await MainActor.run {
                    ShareMetadataStore.shared.queueExistingUserMetadata(shareMetadata)
                }
            } else {
                do {
                    try await syncEngine.acceptShare(metadata: shareMetadata)
                } catch {
                    logger.error("Failed to silently accept empty-state share: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Existing-user acceptance flow should appear only when the user has
    /// actual local inventory data to reconcile.
    static func hasExistingDataForShareAcceptance(database: any DatabaseReader) async -> Bool {
        do {
            let counts = try await database.read { db in
                (
                    homes: try SQLiteHome.count().fetchOne(db) ?? 0,
                    items: try SQLiteInventoryItem.count().fetchOne(db) ?? 0
                )
            }
            return counts.homes > 0 && counts.items > 0
        } catch {
            logger.error("Failed to inspect local data before share acceptance: \(error.localizedDescription)")
            // Be conservative: prefer showing explicit flow over silent accept.
            return true
        }
    }
}
