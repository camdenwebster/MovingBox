import SQLiteData
import UIKit

@Table("inventoryLabels")
nonisolated struct SQLiteInventoryLabel: Hashable, Identifiable {
    let id: UUID
    var householdID: SQLiteHousehold.ID?
    var name: String = ""
    var desc: String = ""
    @Column(as: UIColor.HexRepresentation?.self)
    var color: UIColor?
    var emoji: String = "🏷️"
}
