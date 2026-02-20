import Foundation
import SQLiteData

@Table("householdInvites")
nonisolated struct SQLiteHouseholdInvite: Hashable, Identifiable {
    let id: UUID
    var householdID: SQLiteHousehold.ID
    var invitedByMemberID: SQLiteHouseholdMember.ID?
    var acceptedMemberID: SQLiteHouseholdMember.ID?
    var displayName: String = ""
    var email: String = ""
    var role: String = HouseholdMemberRole.member.rawValue
    var status: String = HouseholdInviteStatus.pending.rawValue
    var createdAt: Date = Date()
    var acceptedAt: Date?
}
