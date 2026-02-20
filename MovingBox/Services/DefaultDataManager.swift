import SQLiteData
import SwiftUI

@MainActor
class DefaultDataManager {

    static func populateDefaultSQLiteLabels(database: any DatabaseWriter) async {
        do {
            let existingCount = try await database.read { db in
                try SQLiteInventoryLabel.count().fetchOne(db) ?? 0
            }
            guard existingCount == 0 else {
                print("🏷️ sqlite-data: Existing labels found, skipping default creation")
                return
            }
            // Deterministic IDs so CloudKit sync won't create duplicate default
            // labels when a user reinstalls or sets up a new device.
            let defaultLabels = TestData.labels
            try await database.write { db in
                let householdID: UUID
                if let existingHousehold = try SQLiteHousehold.order(by: \.createdAt).fetchOne(db) {
                    householdID = existingHousehold.id
                } else {
                    let newHousehold = SQLiteHousehold(
                        id: UUID(),
                        name: "My Household",
                        sharingEnabled: false,
                        defaultAccessPolicy: HouseholdDefaultAccessPolicy.allHomesShared.rawValue
                    )
                    try SQLiteHousehold.insert { newHousehold }.execute(db)
                    householdID = newHousehold.id
                }

                let ownerCount =
                    try SQLiteHouseholdMember
                    .where {
                        $0.householdID == householdID
                            && $0.isCurrentUser == true
                            && $0.status == HouseholdMemberStatus.active.rawValue
                    }
                    .fetchCount(db)

                if ownerCount == 0 {
                    try SQLiteHouseholdMember.insert {
                        SQLiteHouseholdMember(
                            id: UUID(),
                            householdID: householdID,
                            displayName: "You",
                            contactEmail: "",
                            role: HouseholdMemberRole.owner.rawValue,
                            status: HouseholdMemberStatus.active.rawValue,
                            isCurrentUser: true
                        )
                    }.execute(db)
                }

                for (index, labelData) in defaultLabels.enumerated() {
                    try SQLiteInventoryLabel.insert {
                        SQLiteInventoryLabel(
                            id: DefaultSeedID.labelIDs[index],
                            householdID: householdID,
                            name: labelData.name,
                            desc: labelData.desc,
                            color: labelData.color,
                            emoji: labelData.emoji
                        )
                    }.execute(db)
                }
            }
            print("🏷️ sqlite-data: Default labels created")
        } catch {
            print("❌ sqlite-data: Error creating default labels: \(error)")
        }
    }
}
