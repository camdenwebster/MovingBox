import Foundation
import SQLiteData

@Table("households")
nonisolated struct SQLiteHousehold: Hashable, Identifiable {
    let id: UUID
    var name: String = ""
    var sharingEnabled: Bool = false
    var defaultAccessPolicy: String = HouseholdDefaultAccessPolicy.allHomesShared.rawValue
    var createdAt: Date = Date()
}
