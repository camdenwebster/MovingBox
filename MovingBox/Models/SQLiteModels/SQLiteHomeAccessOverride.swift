import Foundation
import SQLiteData

@Table("homeAccessOverrides")
nonisolated struct SQLiteHomeAccessOverride: Hashable, Identifiable {
    let id: UUID
    var householdID: SQLiteHousehold.ID
    var homeID: SQLiteHome.ID
    var memberID: SQLiteHouseholdMember.ID
    var decision: String = HomeAccessOverrideDecision.allow.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
