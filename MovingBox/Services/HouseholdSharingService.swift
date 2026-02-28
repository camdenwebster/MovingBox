import Dependencies
import Foundation
import SQLiteData

struct MemberHomeAccessState: Hashable, Identifiable, Sendable {
    let id: UUID
    let member: SQLiteHouseholdMember
    let homeID: UUID
    let isAccessible: Bool
    let source: HomeAccessSource
    let overrideDecision: HomeAccessOverrideDecision?
}

struct HouseholdSharingSnapshot: Sendable {
    let household: SQLiteHousehold
    let currentUserMember: SQLiteHouseholdMember
    let members: [SQLiteHouseholdMember]
    let invites: [SQLiteHouseholdInvite]
    let homes: [SQLiteHome]
    let overrides: [SQLiteHomeAccessOverride]
}

enum HouseholdSharingServiceError: LocalizedError {
    case noHousehold
    case noCurrentUserMembership
    case inviteNotFound
    case inviteNotPending
    case invalidInviteRole
    case cannotRevokeOwner
    case memberNotFound
    case memberNotActive
    case homeNotFound
    case permissionDeniedForMove

    var errorDescription: String? {
        switch self {
        case .noHousehold:
            return "No household exists."
        case .noCurrentUserMembership:
            return "Current user membership is missing."
        case .inviteNotFound:
            return "Invite was not found."
        case .inviteNotPending:
            return "Invite is no longer pending."
        case .invalidInviteRole:
            return "Invite role is invalid."
        case .cannotRevokeOwner:
            return "Owner membership cannot be revoked."
        case .memberNotFound:
            return "Member was not found."
        case .memberNotActive:
            return "Member is not active."
        case .homeNotFound:
            return "Home was not found."
        case .permissionDeniedForMove:
            return "You do not have access to move this item to the selected home."
        }
    }
}

struct HouseholdSharingService {
    @Dependency(\.defaultDatabase) private var database
    private let featureFlags: FeatureFlags

    init(featureFlags: FeatureFlags = FeatureFlags(distribution: .current)) {
        self.featureFlags = featureFlags
    }

    @discardableResult
    func ensureBootstrap() async throws -> UUID {
        try await database.write { db in
            try bootstrapHousehold(in: db)
        }
    }

    func loadSnapshot() async throws -> HouseholdSharingSnapshot {
        let householdID = try await ensureBootstrap()
        return try await database.read { db in
            guard let household = try SQLiteHousehold.find(householdID).fetchOne(db) else {
                throw HouseholdSharingServiceError.noHousehold
            }

            let currentUserMember =
                try SQLiteHouseholdMember
                .where {
                    $0.householdID == household.id
                        && $0.isCurrentUser == true
                        && $0.status == HouseholdMemberStatus.active.rawValue
                }
                .fetchOne(db)

            guard let currentUserMember else {
                throw HouseholdSharingServiceError.noCurrentUserMembership
            }

            let members =
                try SQLiteHouseholdMember
                .where { $0.householdID == household.id }
                .order(by: \.createdAt)
                .fetchAll(db)

            let invites =
                try SQLiteHouseholdInvite
                .where { $0.householdID == household.id }
                .order(by: \.createdAt)
                .fetchAll(db)

            let homes =
                try SQLiteHome
                .where { $0.householdID == household.id }
                .order(by: \.name)
                .fetchAll(db)

            let overrides =
                try SQLiteHomeAccessOverride
                .where { $0.householdID == household.id }
                .fetchAll(db)

            return HouseholdSharingSnapshot(
                household: household,
                currentUserMember: currentUserMember,
                members: members,
                invites: invites,
                homes: homes,
                overrides: overrides
            )
        }
    }

    func updateDefaultAccessPolicy(_ policy: HouseholdDefaultAccessPolicy) async throws {
        let householdID = try await ensureBootstrap()
        try await database.write { db in
            try SQLiteHousehold.find(householdID)
                .update {
                    $0.defaultAccessPolicy = policy.rawValue
                }
                .execute(db)
        }
    }

    func setSharingEnabled(_ enabled: Bool) async throws {
        let householdID = try await ensureBootstrap()
        try await database.write { db in
            try SQLiteHousehold.find(householdID)
                .update {
                    $0.sharingEnabled = enabled
                }
                .execute(db)
        }
    }

    @discardableResult
    func createInvite(displayName: String, email: String) async throws -> SQLiteHouseholdInvite {
        let householdID = try await ensureBootstrap()
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return try await database.write { db in
            let currentUserMember =
                try SQLiteHouseholdMember
                .where {
                    $0.householdID == householdID
                        && $0.isCurrentUser == true
                        && $0.status == HouseholdMemberStatus.active.rawValue
                }
                .fetchOne(db)

            guard let currentUserMember else {
                throw HouseholdSharingServiceError.noCurrentUserMembership
            }

            let invite = SQLiteHouseholdInvite(
                id: UUID(),
                householdID: householdID,
                invitedByMemberID: currentUserMember.id,
                acceptedMemberID: nil,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                email: normalizedEmail,
                role: HouseholdMemberRole.member.rawValue,
                status: HouseholdInviteStatus.pending.rawValue,
                createdAt: Date(),
                acceptedAt: nil
            )
            try SQLiteHouseholdInvite.insert { invite }.execute(db)
            return invite
        }
    }

    @discardableResult
    func acceptInvite(inviteID: UUID) async throws -> SQLiteHouseholdMember {
        try await database.write { db in
            guard let invite = try SQLiteHouseholdInvite.find(inviteID).fetchOne(db) else {
                throw HouseholdSharingServiceError.inviteNotFound
            }
            guard invite.status == HouseholdInviteStatus.pending.rawValue else {
                throw HouseholdSharingServiceError.inviteNotPending
            }
            guard invite.role == HouseholdMemberRole.member.rawValue else {
                throw HouseholdSharingServiceError.invalidInviteRole
            }

            let normalizedEmail = invite.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let member: SQLiteHouseholdMember
            let existingMember =
                try SQLiteHouseholdMember
                .where {
                    $0.householdID == invite.householdID
                        && $0.contactEmail == normalizedEmail
                }
                .fetchOne(db)

            if let existing = existingMember {
                try SQLiteHouseholdMember.find(existing.id)
                    .update {
                        $0.displayName = invite.displayName
                        $0.contactEmail = normalizedEmail
                        $0.role = HouseholdMemberRole.member.rawValue
                        $0.status = HouseholdMemberStatus.active.rawValue
                    }
                    .execute(db)
                member = try SQLiteHouseholdMember.find(existing.id).fetchOne(db) ?? existing
            } else {
                let newMember = SQLiteHouseholdMember(
                    id: UUID(),
                    householdID: invite.householdID,
                    displayName: invite.displayName,
                    contactEmail: normalizedEmail,
                    role: HouseholdMemberRole.member.rawValue,
                    status: HouseholdMemberStatus.active.rawValue,
                    isCurrentUser: false,
                    createdAt: Date()
                )
                try SQLiteHouseholdMember.insert { newMember }.execute(db)
                member = newMember
            }

            try SQLiteHouseholdInvite.find(invite.id)
                .update {
                    $0.status = HouseholdInviteStatus.accepted.rawValue
                    $0.acceptedMemberID = member.id
                    $0.acceptedAt = Date()
                }
                .execute(db)

            return member
        }
    }

    func revokeMember(memberID: UUID) async throws {
        try await database.write { db in
            guard let member = try SQLiteHouseholdMember.find(memberID).fetchOne(db) else {
                throw HouseholdSharingServiceError.memberNotFound
            }
            if member.role == HouseholdMemberRole.owner.rawValue {
                throw HouseholdSharingServiceError.cannotRevokeOwner
            }

            try SQLiteHouseholdMember.find(memberID)
                .update {
                    $0.status = HouseholdMemberStatus.revoked.rawValue
                    $0.isCurrentUser = false
                }
                .execute(db)

            try SQLiteHomeAccessOverride
                .where { $0.memberID == memberID }
                .delete()
                .execute(db)
        }
    }

    func upsertHomeAccessOverride(
        homeID: UUID,
        memberID: UUID,
        decision: HomeAccessOverrideDecision?
    ) async throws {
        let householdID = try await ensureBootstrap()

        try await database.write { db in
            guard let home = try SQLiteHome.find(homeID).fetchOne(db) else {
                throw HouseholdSharingServiceError.homeNotFound
            }
            guard home.householdID == householdID else {
                throw HouseholdSharingServiceError.homeNotFound
            }
            guard let member = try SQLiteHouseholdMember.find(memberID).fetchOne(db) else {
                throw HouseholdSharingServiceError.memberNotFound
            }
            guard member.householdID == householdID else {
                throw HouseholdSharingServiceError.memberNotFound
            }

            if let decision {
                try db.execute(
                    sql:
                        """
                        INSERT INTO homeAccessOverrides (
                            id, householdID, homeID, memberID, decision, createdAt, updatedAt
                        )
                        VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        ON CONFLICT(householdID, homeID, memberID)
                        DO UPDATE SET
                            decision = excluded.decision,
                            updatedAt = CURRENT_TIMESTAMP
                        """,
                    arguments: [
                        UUID().uuidString.lowercased(),
                        householdID.uuidString.lowercased(),
                        homeID.uuidString.lowercased(),
                        memberID.uuidString.lowercased(),
                        decision.rawValue,
                    ]
                )
            } else {
                try SQLiteHomeAccessOverride
                    .where {
                        $0.householdID == householdID
                            && $0.homeID == homeID
                            && $0.memberID == memberID
                    }
                    .delete()
                    .execute(db)
            }
        }
    }

    func setHomePrivacy(homeID: UUID, isPrivate: Bool) async throws {
        try await database.write { db in
            guard try SQLiteHome.find(homeID).fetchOne(db) != nil else {
                throw HouseholdSharingServiceError.homeNotFound
            }
            try SQLiteHome.find(homeID)
                .update {
                    $0.isPrivate = isPrivate
                }
                .execute(db)
        }
    }

    func reconcileStaleOverrides() async throws {
        try await database.write { db in
            try db.execute(
                sql:
                    """
                    DELETE FROM homeAccessOverrides
                    WHERE memberID IN (
                        SELECT id
                        FROM householdMembers
                        WHERE status != ?
                    )
                    """,
                arguments: [HouseholdMemberStatus.active.rawValue]
            )
        }
    }

    func loadHomeAccessStates(homeID: UUID) async throws -> [MemberHomeAccessState] {
        let snapshot = try await loadSnapshot()
        guard let home = snapshot.homes.first(where: { $0.id == homeID }) else {
            throw HouseholdSharingServiceError.homeNotFound
        }

        let overridesByMemberID = Dictionary(uniqueKeysWithValues: snapshot.overrides.map { ($0.memberID, $0) })

        return snapshot.members
            .filter {
                $0.status == HouseholdMemberStatus.active.rawValue
                    && $0.role != HouseholdMemberRole.owner.rawValue
            }
            .map { member in
                let access = resolveAccess(
                    member: member,
                    home: home,
                    household: snapshot.household,
                    override: overridesByMemberID[member.id]
                )
                return MemberHomeAccessState(
                    id: member.id,
                    member: member,
                    homeID: homeID,
                    isAccessible: access.isAccessible,
                    source: access.source,
                    overrideDecision: access.overrideDecision
                )
            }
            .sorted { lhs, rhs in
                lhs.member.displayName.localizedCaseInsensitiveCompare(rhs.member.displayName) == .orderedAscending
            }
    }

    func moveItem(itemID: UUID, destinationHomeID: UUID, actingMemberID: UUID) async throws {
        let snapshot = try await loadSnapshot()
        guard let destinationHome = snapshot.homes.first(where: { $0.id == destinationHomeID }) else {
            throw HouseholdSharingServiceError.homeNotFound
        }
        guard let member = snapshot.members.first(where: { $0.id == actingMemberID }) else {
            throw HouseholdSharingServiceError.memberNotFound
        }
        let overrideDecision = snapshot.overrides.first {
            $0.memberID == actingMemberID && $0.homeID == destinationHomeID
        }
        let access = resolveAccess(
            member: member,
            home: destinationHome,
            household: snapshot.household,
            override: overrideDecision
        )
        guard access.isAccessible else {
            throw HouseholdSharingServiceError.permissionDeniedForMove
        }

        try await database.write { db in
            try SQLiteInventoryItem.find(itemID)
                .update {
                    $0.homeID = destinationHomeID
                }
                .execute(db)
        }
    }

    func moveItemAsCurrentUser(itemID: UUID, destinationHomeID: UUID) async throws {
        let snapshot = try await loadSnapshot()
        try await moveItem(
            itemID: itemID,
            destinationHomeID: destinationHomeID,
            actingMemberID: snapshot.currentUserMember.id
        )
    }

    func loadHouseholdLabels(forMemberID memberID: UUID? = nil) async throws -> [SQLiteInventoryLabel] {
        let snapshot = try await loadSnapshot()
        let member: SQLiteHouseholdMember
        if let memberID {
            guard let existing = snapshot.members.first(where: { $0.id == memberID }) else {
                throw HouseholdSharingServiceError.memberNotFound
            }
            member = existing
        } else {
            member = snapshot.currentUserMember
        }

        guard member.status == HouseholdMemberStatus.active.rawValue else {
            throw HouseholdSharingServiceError.memberNotActive
        }
        guard member.householdID == snapshot.household.id else {
            throw HouseholdSharingServiceError.memberNotFound
        }

        return try await database.read { db in
            try SQLiteInventoryLabel
                .where { $0.householdID == snapshot.household.id }
                .order(by: \.name)
                .fetchAll(db)
        }
    }

    private func resolveAccess(
        member: SQLiteHouseholdMember,
        home: SQLiteHome,
        household: SQLiteHousehold,
        override: SQLiteHomeAccessOverride?
    ) -> (isAccessible: Bool, source: HomeAccessSource, overrideDecision: HomeAccessOverrideDecision?) {
        guard member.status == HouseholdMemberStatus.active.rawValue else {
            return (false, .noMembership, nil)
        }
        if member.role == HouseholdMemberRole.owner.rawValue {
            return (true, .inherited, nil)
        }
        guard featureFlags.familySharingScopingEnabled else {
            // V1 global sharing mode: ignore private homes and per-home overrides.
            return (true, .inherited, nil)
        }

        let overrideDecision = override.flatMap { HomeAccessOverrideDecision(rawValue: $0.decision) }
        if let overrideDecision {
            switch overrideDecision {
            case .allow:
                return (true, .overriddenAllow, .allow)
            case .deny:
                return (false, .overriddenDeny, .deny)
            }
        }

        if home.isPrivate {
            return (false, .privateHome, nil)
        }

        let policy = HouseholdDefaultAccessPolicy(rawValue: household.defaultAccessPolicy) ?? .allHomesShared
        switch policy {
        case .allHomesShared:
            return (true, .inherited, nil)
        case .ownerScopesHomes:
            return (false, .inherited, nil)
        }
    }

    @discardableResult
    private func bootstrapHousehold(in db: Database) throws -> UUID {
        let householdID: UUID
        if let existing = try SQLiteHousehold.order(by: \.createdAt).fetchOne(db) {
            householdID = existing.id
        } else {
            let newHousehold = SQLiteHousehold(
                id: UUID(),
                name: "My Household",
                defaultAccessPolicy: HouseholdDefaultAccessPolicy.allHomesShared.rawValue,
                createdAt: Date()
            )
            try SQLiteHousehold.insert { newHousehold }.execute(db)
            householdID = newHousehold.id
        }

        try SQLiteHome
            .where { $0.householdID == nil as UUID? }
            .update { $0.householdID = householdID }
            .execute(db)

        try SQLiteInventoryLabel
            .where { $0.householdID == nil as UUID? }
            .update { $0.householdID = householdID }
            .execute(db)

        let currentUserMembership =
            try SQLiteHouseholdMember
            .where {
                $0.householdID == householdID
                    && $0.isCurrentUser == true
                    && $0.status == HouseholdMemberStatus.active.rawValue
            }
            .fetchOne(db)

        if currentUserMembership == nil {
            let ownerMember = SQLiteHouseholdMember(
                id: UUID(),
                householdID: householdID,
                displayName: "You",
                contactEmail: "",
                role: HouseholdMemberRole.owner.rawValue,
                status: HouseholdMemberStatus.active.rawValue,
                isCurrentUser: true,
                createdAt: Date()
            )
            try SQLiteHouseholdMember.insert { ownerMember }.execute(db)
        }

        return householdID
    }
}
