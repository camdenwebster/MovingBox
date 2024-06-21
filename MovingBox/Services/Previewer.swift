//
//  Previewer.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData
import UIKit

@MainActor
struct Previewer {
    let container: ModelContainer
    let inventoryItem: InventoryItem
    let location: InventoryLocation
    let label: InventoryLabel
    
    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: InventoryItem.self, configurations: config)
        
        location = InventoryLocation(id: UUID().uuidString, name: "Office", desc: "Camden's office")
        label = InventoryLabel(id: UUID().uuidString, name: "Electronics", desc: "Electronic items", color: .red)
        inventoryItem = InventoryItem(id: UUID().uuidString, title: "Sennheiser Power Adapter", quantityString: "1", quantityInt: 1, desc: "", serial: "Sennheiser", model: "Power adapter", make: "Sennheiser", location: location, label: label, price: "", insured: false, assetId: "", notes: "", showInvalidQuantityAlert: false)

        
        container.mainContext.insert(inventoryItem)
    }
}
