//
//  Previewer.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData

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
        label = InventoryLabel(id: UUID().uuidString, name: "Electronics", desc: "Electronic items")
        inventoryItem = InventoryItem(id: UUID().uuidString, location: nil, label: nil)

        
        container.mainContext.insert(inventoryItem)
    }
}
