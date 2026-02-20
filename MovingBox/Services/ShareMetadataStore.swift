//
//  ShareMetadataStore.swift
//  MovingBox
//
//  Created by Camden Webster on 2/6/26.
//

import CloudKit
import Foundation

@MainActor
final class ShareMetadataStore {
    static let shared = ShareMetadataStore()
    static let existingUserShareMetadataDidChange = Notification.Name(
        "ShareMetadataStore.existingUserShareMetadataDidChange"
    )

    var pendingShareMetadata: CKShare.Metadata?
    var pendingExistingUserShareMetadata: CKShare.Metadata?

    private init() {}

    /// Reads and clears the pending metadata in one call.
    func consumeMetadata() -> CKShare.Metadata? {
        let metadata = pendingShareMetadata
        pendingShareMetadata = nil
        return metadata
    }

    /// Queues metadata for an already-onboarded user so the app can route into
    /// the existing-user acceptance flow.
    func queueExistingUserMetadata(_ metadata: CKShare.Metadata) {
        pendingExistingUserShareMetadata = metadata
        NotificationCenter.default.post(name: Self.existingUserShareMetadataDidChange, object: nil)
    }

    /// Reads and clears pending existing-user metadata in one call.
    func consumeExistingUserMetadata() -> CKShare.Metadata? {
        let metadata = pendingExistingUserShareMetadata
        pendingExistingUserShareMetadata = nil
        return metadata
    }
}
