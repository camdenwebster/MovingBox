import Dependencies
import Foundation
import SQLiteData
import Testing

@testable import MovingBox

@Suite("Household Sharing Service", .serialized)
struct HouseholdSharingServiceTests {

    @Test("Bootstrap creates default household and owner membership")
    func bootstrapCreatesDefaults() async throws {
        let db = try makeInMemoryDatabase()

        try await db.write { db in
            try SQLiteHome.insert {
                SQLiteHome(id: UUID(), name: "Main Home")
            }.execute(db)
        }

        let snapshot = try await withService(db) { service in
            try await service.loadSnapshot()
        }

        #expect(snapshot.household.name == "My Household")
        #expect(snapshot.currentUserMember.role == HouseholdMemberRole.owner.rawValue)
        #expect(snapshot.homes.count == 1)
        #expect(snapshot.homes.allSatisfy { $0.householdID == snapshot.household.id })
    }

    @Test("All-homes default inherits access when no override exists")
    func allHomesDefaultInheritsAccess() async throws {
        let db = try makeInMemoryDatabase()
        let householdID = try await bootstrapHouseholdID(db)
        let homeID = UUID()
        let memberID = UUID()

        try await db.write { db in
            try SQLiteHousehold.find(householdID).update {
                $0.defaultAccessPolicy = HouseholdDefaultAccessPolicy.allHomesShared.rawValue
            }.execute(db)

            try SQLiteHome.insert {
                SQLiteHome(id: homeID, name: "Main Home", householdID: householdID)
            }.execute(db)

            try SQLiteHouseholdMember.insert {
                SQLiteHouseholdMember(
                    id: memberID,
                    householdID: householdID,
                    displayName: "Member",
                    role: HouseholdMemberRole.member.rawValue
                )
            }.execute(db)
        }

        let states = try await withService(db) { service in
            try await service.loadHomeAccessStates(homeID: homeID)
        }
        let memberState = try #require(states.first(where: { $0.member.id == memberID }))

        #expect(memberState.isAccessible == true)
        #expect(memberState.source == .inherited)
    }

    @Test("All-homes default is superseded by explicit deny override")
    func allHomesDefaultDenyOverrideWins() async throws {
        let db = try makeInMemoryDatabase()
        let householdID = try await bootstrapHouseholdID(db)
        let homeID = UUID()
        let memberID = UUID()

        try await db.write { db in
            try SQLiteHousehold.find(householdID).update {
                $0.defaultAccessPolicy = HouseholdDefaultAccessPolicy.allHomesShared.rawValue
            }.execute(db)

            try SQLiteHome.insert {
                SQLiteHome(id: homeID, name: "Main Home", householdID: householdID)
            }.execute(db)

            try SQLiteHouseholdMember.insert {
                SQLiteHouseholdMember(
                    id: memberID,
                    householdID: householdID,
                    displayName: "Member",
                    role: HouseholdMemberRole.member.rawValue
                )
            }.execute(db)

            try SQLiteHomeAccessOverride.insert {
                SQLiteHomeAccessOverride(
                    id: UUID(),
                    householdID: householdID,
                    homeID: homeID,
                    memberID: memberID,
                    decision: HomeAccessOverrideDecision.deny.rawValue
                )
            }.execute(db)
        }

        let states = try await withService(db) { service in
            try await service.loadHomeAccessStates(homeID: homeID)
        }
        let memberState = try #require(states.first(where: { $0.member.id == memberID }))

        #expect(memberState.isAccessible == false)
        #expect(memberState.source == .overriddenDeny)
    }

    @Test("Owner-scoped default denies access without allow override")
    func ownerScopedDefaultDeniesWithoutOverride() async throws {
        let db = try makeInMemoryDatabase()
        let householdID = try await bootstrapHouseholdID(db)
        let homeID = UUID()
        let memberID = UUID()

        try await db.write { db in
            try SQLiteHousehold.find(householdID).update {
                $0.defaultAccessPolicy = HouseholdDefaultAccessPolicy.ownerScopesHomes.rawValue
            }.execute(db)

            try SQLiteHome.insert {
                SQLiteHome(id: homeID, name: "Main Home", householdID: householdID)
            }.execute(db)

            try SQLiteHouseholdMember.insert {
                SQLiteHouseholdMember(
                    id: memberID,
                    householdID: householdID,
                    displayName: "Member",
                    role: HouseholdMemberRole.member.rawValue
                )
            }.execute(db)
        }

        let states = try await withService(db) { service in
            try await service.loadHomeAccessStates(homeID: homeID)
        }
        let memberState = try #require(states.first(where: { $0.member.id == memberID }))

        #expect(memberState.isAccessible == false)
        #expect(memberState.source == .inherited)
    }

    @Test("Owner-scoped default is superseded by explicit allow override")
    func ownerScopedAllowOverrideWins() async throws {
        let db = try makeInMemoryDatabase()
        let householdID = try await bootstrapHouseholdID(db)
        let homeID = UUID()
        let memberID = UUID()

        try await db.write { db in
            try SQLiteHousehold.find(householdID).update {
                $0.defaultAccessPolicy = HouseholdDefaultAccessPolicy.ownerScopesHomes.rawValue
            }.execute(db)

            try SQLiteHome.insert {
                SQLiteHome(id: homeID, name: "Main Home", householdID: householdID)
            }.execute(db)

            try SQLiteHouseholdMember.insert {
                SQLiteHouseholdMember(
                    id: memberID,
                    householdID: householdID,
                    displayName: "Member",
                    role: HouseholdMemberRole.member.rawValue
                )
            }.execute(db)

            try SQLiteHomeAccessOverride.insert {
                SQLiteHomeAccessOverride(
                    id: UUID(),
                    householdID: householdID,
                    homeID: homeID,
                    memberID: memberID,
                    decision: HomeAccessOverrideDecision.allow.rawValue
                )
            }.execute(db)
        }

        let states = try await withService(db) { service in
            try await service.loadHomeAccessStates(homeID: homeID)
        }
        let memberState = try #require(states.first(where: { $0.member.id == memberID }))

        #expect(memberState.isAccessible == true)
        #expect(memberState.source == .overriddenAllow)
    }

    @Test("Scoping-disabled mode ignores private homes and per-home overrides")
    func scopingDisabledForcesGlobalAccess() async throws {
        let db = try makeInMemoryDatabase()
        let householdID = try await bootstrapHouseholdID(db)
        let homeID = UUID()
        let memberID = UUID()

        try await db.write { db in
            try SQLiteHousehold.find(householdID).update {
                $0.defaultAccessPolicy = HouseholdDefaultAccessPolicy.ownerScopesHomes.rawValue
            }.execute(db)

            try SQLiteHome.insert {
                SQLiteHome(
                    id: homeID,
                    name: "Private Home",
                    householdID: householdID,
                    isPrivate: true
                )
            }.execute(db)

            try SQLiteHouseholdMember.insert {
                SQLiteHouseholdMember(
                    id: memberID,
                    householdID: householdID,
                    displayName: "Member",
                    role: HouseholdMemberRole.member.rawValue
                )
            }.execute(db)

            try SQLiteHomeAccessOverride.insert {
                SQLiteHomeAccessOverride(
                    id: UUID(),
                    householdID: householdID,
                    homeID: homeID,
                    memberID: memberID,
                    decision: HomeAccessOverrideDecision.deny.rawValue
                )
            }.execute(db)
        }

        let states = try await withService(
            db,
            featureFlags: FeatureFlags(showZoomControl: true, familySharingScopingEnabled: false)
        ) { service in
            try await service.loadHomeAccessStates(homeID: homeID)
        }
        let memberState = try #require(states.first(where: { $0.member.id == memberID }))

        #expect(memberState.isAccessible == true)
        #expect(memberState.source == .inherited)
    }

    @Test("Invite acceptance creates member and excludes private homes from default access")
    func inviteAcceptanceHonorsPrivateHomes() async throws {
        let db = try makeInMemoryDatabase()
        let householdID = try await bootstrapHouseholdID(db)
        let publicHomeID = UUID()
        let privateHomeID = UUID()

        try await db.write { db in
            try SQLiteHousehold.find(householdID).update {
                $0.sharingEnabled = true
                $0.defaultAccessPolicy = HouseholdDefaultAccessPolicy.allHomesShared.rawValue
            }.execute(db)

            try SQLiteHome.insert {
                SQLiteHome(
                    id: publicHomeID,
                    name: "Public Home",
                    householdID: householdID,
                    isPrivate: false
                )
            }.execute(db)

            try SQLiteHome.insert {
                SQLiteHome(
                    id: privateHomeID,
                    name: "Private Home",
                    householdID: householdID,
                    isPrivate: true
                )
            }.execute(db)
        }

        let (publicState, privateState): (MemberHomeAccessState?, MemberHomeAccessState?) = try await withService(db) {
            service in
            let invite = try await service.createInvite(displayName: "Taylor", email: "taylor@example.com")
            let member = try await service.acceptInvite(inviteID: invite.id)

            let publicState =
                try await service
                .loadHomeAccessStates(homeID: publicHomeID)
                .first(where: { $0.member.id == member.id })
            let privateState =
                try await service
                .loadHomeAccessStates(homeID: privateHomeID)
                .first(where: { $0.member.id == member.id })
            return (publicState, privateState)
        }

        #expect(publicState?.isAccessible == true)
        #expect(publicState?.source == .inherited)
        #expect(privateState?.isAccessible == false)
        #expect(privateState?.source == .privateHome)
    }

    @Test("Revoking membership removes stale home overrides")
    func revocationCleansOverrides() async throws {
        let db = try makeInMemoryDatabase()
        let householdID = try await bootstrapHouseholdID(db)
        let homeID = UUID()
        let memberID = UUID()

        try await db.write { db in
            try SQLiteHouseholdMember.insert {
                SQLiteHouseholdMember(
                    id: memberID,
                    householdID: householdID,
                    displayName: "Member"
                )
            }.execute(db)

            try SQLiteHome.insert {
                SQLiteHome(id: homeID, name: "Main", householdID: householdID)
            }.execute(db)

            try SQLiteHomeAccessOverride.insert {
                SQLiteHomeAccessOverride(
                    id: UUID(),
                    householdID: householdID,
                    homeID: homeID,
                    memberID: memberID,
                    decision: HomeAccessOverrideDecision.allow.rawValue
                )
            }.execute(db)
        }

        try await withService(db) { service in
            try await service.revokeMember(memberID: memberID)
            try await service.reconcileStaleOverrides()
        }

        let overrideCount = try await db.read { db in
            try SQLiteHomeAccessOverride.count().fetchOne(db) ?? 0
        }
        let member = try await db.read { db in
            try SQLiteHouseholdMember.find(memberID).fetchOne(db)
        }

        #expect(overrideCount == 0)
        #expect(member?.status == HouseholdMemberStatus.revoked.rawValue)
    }

    @Test("Item move is blocked when destination access is denied")
    func moveBlockedWithoutAccess() async throws {
        let db = try makeInMemoryDatabase()
        let householdID = try await bootstrapHouseholdID(db)
        let memberID = UUID()
        let sourceHomeID = UUID()
        let destinationHomeID = UUID()
        let itemID = UUID()

        try await db.write { db in
            try SQLiteHousehold.find(householdID).update {
                $0.defaultAccessPolicy = HouseholdDefaultAccessPolicy.ownerScopesHomes.rawValue
            }.execute(db)

            try SQLiteHouseholdMember.insert {
                SQLiteHouseholdMember(
                    id: memberID,
                    householdID: householdID,
                    displayName: "Member"
                )
            }.execute(db)

            try SQLiteHome.insert {
                SQLiteHome(id: sourceHomeID, name: "Source", householdID: householdID)
            }.execute(db)
            try SQLiteHome.insert {
                SQLiteHome(id: destinationHomeID, name: "Destination", householdID: householdID)
            }.execute(db)

            try SQLiteInventoryItem.insert {
                SQLiteInventoryItem(id: itemID, title: "Lamp", homeID: sourceHomeID)
            }.execute(db)
        }

        _ = try await withService(db) { service in
            await #expect(throws: HouseholdSharingServiceError.self) {
                try await service.moveItem(
                    itemID: itemID,
                    destinationHomeID: destinationHomeID,
                    actingMemberID: memberID
                )
            }
        }
    }

    @Test("Denied home access does not hide household labels")
    func metadataVisibilityIgnoresPerHomeOverride() async throws {
        let db = try makeInMemoryDatabase()
        let householdID = try await bootstrapHouseholdID(db)
        let memberID = UUID()
        let homeID = UUID()
        let labelID = UUID()

        try await db.write { db in
            try SQLiteHouseholdMember.insert {
                SQLiteHouseholdMember(
                    id: memberID,
                    householdID: householdID,
                    displayName: "Member"
                )
            }.execute(db)

            try SQLiteHome.insert {
                SQLiteHome(id: homeID, name: "Main", householdID: householdID)
            }.execute(db)

            try SQLiteHomeAccessOverride.insert {
                SQLiteHomeAccessOverride(
                    id: UUID(),
                    householdID: householdID,
                    homeID: homeID,
                    memberID: memberID,
                    decision: HomeAccessOverrideDecision.deny.rawValue
                )
            }.execute(db)

            try SQLiteInventoryLabel.insert {
                SQLiteInventoryLabel(id: labelID, householdID: householdID, name: "Electronics", emoji: "💻")
            }.execute(db)
        }

        let labels = try await withService(db) { service in
            try await service.loadHouseholdLabels(forMemberID: memberID)
        }

        #expect(labels.count == 1)
        #expect(labels.first?.id == labelID)
    }

    @Test("Labels remain stable across revoke and re-invite")
    func metadataReferencesRemainStableAcrossReinvite() async throws {
        let db = try makeInMemoryDatabase()
        let householdID = try await bootstrapHouseholdID(db)
        let labelID = UUID()

        try await db.write { db in
            try SQLiteInventoryLabel.insert {
                SQLiteInventoryLabel(id: labelID, householdID: householdID, name: "Documents", emoji: "📄")
            }.execute(db)
        }

        let labelsAfterReinvite = try await withService(db) { service in
            let invite = try await service.createInvite(displayName: "Taylor", email: "taylor@example.com")
            let member = try await service.acceptInvite(inviteID: invite.id)
            try await service.revokeMember(memberID: member.id)

            let reInvite = try await service.createInvite(displayName: "Taylor", email: "taylor@example.com")
            let reacceptedMember = try await service.acceptInvite(inviteID: reInvite.id)
            return try await service.loadHouseholdLabels(forMemberID: reacceptedMember.id)
        }

        let totalLabels = try await db.read { db in
            try SQLiteInventoryLabel
                .where { $0.householdID == householdID }
                .fetchCount(db)
        }

        #expect(totalLabels == 1)
        #expect(labelsAfterReinvite.count == 1)
        #expect(labelsAfterReinvite.first?.id == labelID)
    }

    private func withService<T>(
        _ db: DatabaseQueue,
        featureFlags: FeatureFlags = FeatureFlags(showZoomControl: true, familySharingScopingEnabled: true),
        operation: @escaping @Sendable (HouseholdSharingService) async throws -> T
    ) async throws -> T {
        try await withDependencies {
            $0.defaultDatabase = db
        } operation: {
            try await operation(HouseholdSharingService(featureFlags: featureFlags))
        }
    }

    private func bootstrapHouseholdID(_ db: DatabaseQueue) async throws -> UUID {
        try await withService(db) { service in
            try await service.ensureBootstrap()
        }
    }
}
