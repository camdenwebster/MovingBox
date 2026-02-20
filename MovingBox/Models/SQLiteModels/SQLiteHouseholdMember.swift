import Foundation
import SQLiteData

@Table("householdMembers")
nonisolated struct SQLiteHouseholdMember: Hashable, Identifiable {
    let id: UUID
    var householdID: SQLiteHousehold.ID
    var displayName: String = ""
    var contactEmail: String = ""
    var role: String = HouseholdMemberRole.member.rawValue
    var status: String = HouseholdMemberStatus.active.rawValue
    var isCurrentUser: Bool = false
    var createdAt: Date = Date()
}
