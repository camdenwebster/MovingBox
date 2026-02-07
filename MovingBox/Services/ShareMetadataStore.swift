//
//  ShareMetadataStore.swift
//  MovingBox
//
//  Created by Camden Webster on 2/6/26.
//

import CloudKit

@MainActor
final class ShareMetadataStore {
    static let shared = ShareMetadataStore()

    var pendingShareMetadata: CKShare.Metadata?

    private init() {}

    /// Reads and clears the pending metadata in one call.
    func consumeMetadata() -> CKShare.Metadata? {
        let metadata = pendingShareMetadata
        pendingShareMetadata = nil
        return metadata
    }
}
