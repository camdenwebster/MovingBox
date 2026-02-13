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
    var homeName: String = "Home"

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

    var participantCount: Int {
        existingShare?.participants.filter { $0.role != .owner }.count ?? 0
    }

    var sharingTitle: String {
        if homeName.isEmpty {
            return "MovingBox Home"
        }
        return homeName
    }

    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.defaultSyncEngine) private var syncEngine

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    // MARK: - Initialization

    private let scopedHomeID: UUID?

    init(homeID: UUID? = nil) {
        self.scopedHomeID = homeID
    }

    // MARK: - Public Methods

    /// Fetches the current sharing state for the scoped home.
    /// If no home ID is scoped, falls back to primary home (or first home) for backward compatibility.
    func fetchSharingState() async {
        isLoading = true
        error = nil

        do {
            guard let home = try await loadTargetHome() else {
                isLoading = false
                return
            }
            homeName = resolvedHomeName(from: home)

            if let metadata = try await database.read({ db in
                try SyncMetadata.find(home.syncMetadataID).fetchOne(db)
            }) {
                existingShare = metadata.share
            } else {
                existingShare = nil
            }
        } catch {
            self.error = "Failed to fetch sharing state: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Creates a share for the scoped home.
    func createShare() async -> SharedRecord? {
        isLoading = true
        error = nil

        do {
            guard let home = try await loadTargetHome() else {
                error = "No home found to share"
                isLoading = false
                return nil
            }
            homeName = resolvedHomeName(from: home)
            let title = sharingTitle

            let sharedRecord = try await syncEngine.share(record: home) { share in
                share[CKShare.SystemFieldKey.title] = title
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
            guard let home = try await loadTargetHome() else {
                return nil
            }
            homeName = resolvedHomeName(from: home)

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
            guard let home = try await loadTargetHome() else {
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

    /// Leaves an existing share for the scoped home as the current participant.
    func leaveSharedHome() async {
        isLoading = true
        error = nil

        do {
            guard let home = try await loadTargetHome() else {
                isLoading = false
                return
            }

            try await syncEngine.unshare(record: home)
            existingShare = nil
            shareRecord = nil
        } catch {
            self.error = "Failed to leave shared home: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func loadTargetHome() async throws -> SQLiteHome? {
        try await database.read { db in
            if let scopedHomeID {
                return try SQLiteHome.find(scopedHomeID).fetchOne(db)
            }
            return try SQLiteHome.where { $0.isPrimary == true }.fetchOne(db)
                ?? SQLiteHome.fetchAll(db).first
        }
    }

    private func resolvedHomeName(from home: SQLiteHome) -> String {
        if !home.name.isEmpty { return home.name }
        if !home.address1.isEmpty { return home.address1 }
        return "Home"
    }
}
