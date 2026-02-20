import Foundation
import SQLiteData

@Table("inventoryItemLabels")
nonisolated struct SQLiteInventoryItemLabel: Hashable, Identifiable {
    let id: UUID
    var inventoryItemID: SQLiteInventoryItem.ID
    var inventoryLabelID: SQLiteInventoryLabel.ID
}

@Table("homeInsurancePolicies")
nonisolated struct SQLiteHomeInsurancePolicy: Hashable, Identifiable {
    let id: UUID
    var homeID: SQLiteHome.ID
    var insurancePolicyID: SQLiteInsurancePolicy.ID
}
