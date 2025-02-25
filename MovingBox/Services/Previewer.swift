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
        container = try ModelContainer(
            for: InventoryItem.self, 
            InventoryLocation.self,
            InventoryLabel.self,
            configurations: config
        )
        
        location = InventoryLocation(name: "Office", desc: "Camden's office")
        container.mainContext.insert(location)
        
        label = InventoryLabel(name: "Electronics", desc: "Electronic items", color: .red)
        container.mainContext.insert(label)
        
        inventoryItem = InventoryItem(
            title: "Sennheiser Power Adapter",
            quantityString: "1",
            quantityInt: 1,
            desc: "",
            serial: "Sennheiser",
            model: "Power adapter",
            make: "Sennheiser",
            location: location,
            label: label,
            price: "",
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false
        )
        container.mainContext.insert(inventoryItem)
    }
}
