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
                for (index, labelData) in defaultLabels.enumerated() {
                    try SQLiteInventoryLabel.insert {
                        SQLiteInventoryLabel(
                            id: DefaultSeedID.labelIDs[index],
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
