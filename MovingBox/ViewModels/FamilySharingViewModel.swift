//
//  FamilySharingViewModel.swift
//  MovingBox
//
//  Created by Camden Webster on 2/4/26.
//

import CloudKit
import Dependencies
import Foundation
import SQLiteData

@Observable
@MainActor
final class FamilySharingViewModel {

    // MARK: - State

    var isLoading = false
    var error: String?
    var existingShare: CKShare?
    var shareRecord: SharedRecord?

    // MARK: - Computed Properties

    var isSharing: Bool {
        existingShare != nil
    }

    var isOwner: Bool {
        guard let share = existingShare else { return false }
        return share.currentUserParticipant?.role == .owner
    }

    var participants: [CKShare.Participant] {
        existingShare?.participants ?? []
    }

    var ownerName: String {
        guard let owner = existingShare?.participants.first(where: { $0.role == .owner }) else {
            return "Unknown"
        }
        return owner.userIdentity.nameComponents?.formatted() ?? "Owner"
    }

    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.defaultSyncEngine) private var syncEngine

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Fetches the current sharing state for the first home (used as the share root)
    func fetchSharingState() async {
        isLoading = true
        error = nil

        do {
            // Get the first home to use as the share root
            guard
                let home = try await database.read({ db in
                    try SQLiteHome.where { $0.isPrimary == true }.fetchOne(db)
                        ?? SQLiteHome.fetchAll(db).first
                })
            else {
                isLoading = false
                return
            }

            // Check if this home has an existing share
            if let metadata = try await database.read({ db in
                try SyncMetadata.find(home.syncMetadataID).fetchOne(db)
            }) {
                existingShare = metadata.share
            }
        } catch {
            self.error = "Failed to fetch sharing state: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Creates a share for all data by sharing the primary home
    func createShare() async -> SharedRecord? {
        isLoading = true
        error = nil

        do {
            // Get the primary home (or first home) to share
            guard
                let home = try await database.read({ db in
                    try SQLiteHome.where { $0.isPrimary == true }.fetchOne(db)
                        ?? SQLiteHome.fetchAll(db).first
                })
            else {
                error = "No home found to share"
                isLoading = false
                return nil
            }

            // Create the share
            let sharedRecord = try await syncEngine.share(record: home) { share in
                share[CKShare.SystemFieldKey.title] = "MovingBox Data"
            }

            self.shareRecord = sharedRecord
            self.existingShare = sharedRecord.share
            isLoading = false
            return sharedRecord

        } catch {
            self.error = "Failed to create share: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }

    /// Gets an existing share record for presenting the sharing UI
    func getShareRecord() async -> SharedRecord? {
        do {
            guard
                let home = try await database.read({ db in
                    try SQLiteHome.where { $0.isPrimary == true }.fetchOne(db)
                        ?? SQLiteHome.fetchAll(db).first
                })
            else {
                return nil
            }

            // If we already have a share, return it
            if let existingRecord = shareRecord {
                return existingRecord
            }

            // Check for existing share metadata
            if let metadata = try await database.read({ db in
                try SyncMetadata.find(home.syncMetadataID).fetchOne(db)
            }), metadata.share != nil {
                // Create SharedRecord from existing share
                let sharedRecord = try await syncEngine.share(record: home) { _ in }
                self.shareRecord = sharedRecord
                return sharedRecord
            }

            return nil
        } catch {
            self.error = "Failed to get share: \(error.localizedDescription)"
            return nil
        }
    }

    /// Stops sharing
    func stopSharing() async {
        isLoading = true
        error = nil

        do {
            guard
                let home = try await database.read({ db in
                    try SQLiteHome.where { $0.isPrimary == true }.fetchOne(db)
                        ?? SQLiteHome.fetchAll(db).first
                })
            else {
                isLoading = false
                return
            }

            try await syncEngine.unshare(record: home)
            existingShare = nil
            shareRecord = nil
        } catch {
            self.error = "Failed to stop sharing: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
