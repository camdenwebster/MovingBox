import Foundation
import SQLiteData

@Table("inventoryLocations")
nonisolated struct SQLiteInventoryLocation: Hashable, Identifiable {
    let id: UUID
    var name: String = ""
    var desc: String = ""
    var sfSymbolName: String?
    var homeID: SQLiteHome.ID?
}
