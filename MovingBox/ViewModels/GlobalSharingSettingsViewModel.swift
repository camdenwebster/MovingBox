import CloudKit
import Dependencies
import Foundation
import SQLiteData

@Observable
@MainActor
final class GlobalSharingSettingsViewModel {
    var isLoading = false
    var errorMessage: String?
    var household: SQLiteHousehold?
    var currentUserMember: SQLiteHouseholdMember?
    var members: [SQLiteHouseholdMember] = []
    var invites: [SQLiteHouseholdInvite] = []
    var homes: [SQLiteHome] = []
    var overrides: [SQLiteHomeAccessOverride] = []
    var hasCloudShare = false

    private let service = HouseholdSharingService()
    @ObservationIgnored
    @Dependency(\.defaultSyncEngine) private var syncEngine
    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    var defaultAccessPolicy: HouseholdDefaultAccessPolicy {
        get {
            guard let raw = household?.defaultAccessPolicy else { return .allHomesShared }
            return HouseholdDefaultAccessPolicy(rawValue: raw) ?? .allHomesShared
        }
        set {
            Task {
                await setDefaultAccessPolicy(newValue)
            }
        }
    }

    var nonOwnerMembers: [SQLiteHouseholdMember] {
        members.filter {
            $0.status == HouseholdMemberStatus.active.rawValue
                && $0.role != HouseholdMemberRole.owner.rawValue
        }
    }

    var pendingInvites: [SQLiteHouseholdInvite] {
        invites.filter { $0.status == HouseholdInviteStatus.pending.rawValue }
    }

    var privateHomeCount: Int {
        homes.filter(\.isPrivate).count
    }

    var isSharingEnabled: Bool {
        household?.sharingEnabled ?? false
    }

    var shareStatusText: String {
        if hasCloudShare {
            return "System iCloud share configured"
        }
        return "\(nonOwnerMembers.count) members, \(pendingInvites.count) pending invites"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await service.loadSnapshot()
            household = snapshot.household
            currentUserMember = snapshot.currentUserMember
            members = snapshot.members
            invites = snapshot.invites
            homes = snapshot.homes
            overrides = snapshot.overrides
            await refreshCloudShareStatus()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load sharing settings: \(error.localizedDescription)"
        }
    }

    func createInvite(displayName: String, email: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Email is required."
            return
        }

        do {
            if !isSharingEnabled {
                try await service.setSharingEnabled(true)
            }
            _ = try await service.createInvite(displayName: displayName, email: trimmedEmail)
            await load()
        } catch {
            errorMessage = "Failed to create invite: \(error.localizedDescription)"
        }
    }

    func acceptInvite(inviteID: UUID) async {
        do {
            _ = try await service.acceptInvite(inviteID: inviteID)
            await load()
        } catch {
            errorMessage = "Failed to accept invite: \(error.localizedDescription)"
        }
    }

    func revokeMember(memberID: UUID) async {
        do {
            try await service.revokeMember(memberID: memberID)
            try await service.reconcileStaleOverrides()
            await load()
        } catch {
            errorMessage = "Failed to revoke member: \(error.localizedDescription)"
        }
    }

    func setSharingEnabled(_ enabled: Bool) async {
        do {
            if enabled {
                try await service.setSharingEnabled(true)
                await load()
            } else {
                if hasCloudShare, let household {
                    try await syncEngine.unshare(record: household)
                }
                try await service.setSharingEnabled(false)
                hasCloudShare = false
                await load()
            }
        } catch {
            errorMessage = "Failed to update sharing status: \(error.localizedDescription)"
        }
    }

    func prepareShareRecord() async throws -> SharedRecord {
        if household == nil {
            await load()
        }
        guard let household else {
            throw HouseholdSharingServiceError.noHousehold
        }

        let sharedRecord = try await syncEngine.share(record: household) { share in
            let title = household.name.isEmpty ? "MovingBox Household" : household.name
            share[CKShare.SystemFieldKey.title] = title
        }
        hasCloudShare = true
        return sharedRecord
    }

    func handleCloudShareStopped() async {
        do {
            try await service.setSharingEnabled(false)
            hasCloudShare = false
            await load()
        } catch {
            errorMessage = "Failed to update sharing status: \(error.localizedDescription)"
        }
    }

    private func setDefaultAccessPolicy(_ policy: HouseholdDefaultAccessPolicy) async {
        do {
            try await service.updateDefaultAccessPolicy(policy)
            await load()
        } catch {
            errorMessage = "Failed to update sharing policy: \(error.localizedDescription)"
        }
    }

    private func refreshCloudShareStatus() async {
        guard let household else {
            hasCloudShare = false
            return
        }

        do {
            hasCloudShare = try await database.read { db in
                do {
                    return try SyncMetadata.find(household.syncMetadataID)
                        .select(\.share)
                        .fetchOne(db) != nil
                } catch {
                    if isMissingSyncMetadataTableError(error) {
                        return false
                    }
                    throw error
                }
            }
        } catch {
            hasCloudShare = false
        }
    }
}
