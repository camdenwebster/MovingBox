//
//  SceneDelegate.swift
//  MovingBox
//
//  Created by Camden Webster on 2/4/26.
//

import CloudKit
import Dependencies
import SQLiteData
import UIKit

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    @Dependency(\.defaultSyncEngine) var syncEngine

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Handle share acceptance when app launches from share invitation
        if let shareMetadata = connectionOptions.cloudKitShareMetadata {
            if OnboardingManager.shouldShowWelcome() {
                // First launch from share link — defer to joining flow
                MainActor.assumeIsolated {
                    ShareMetadataStore.shared.pendingShareMetadata = shareMetadata
                }
            } else {
                // Already onboarded — accept immediately
                Task {
                    try? await syncEngine.acceptShare(metadata: shareMetadata)
                }
            }
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        // Handle share acceptance when app is already running
        Task {
            try? await syncEngine.acceptShare(metadata: cloudKitShareMetadata)
        }
    }
}
