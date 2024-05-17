//
//  InventoryRow.swift
//  FirebaseCRUD-CamdenW
//
//  Created by Camden Webster on 4/12/24.
//

import SwiftUI


struct InventoryRow: View {
    var inventoryItem: InventoryItem
    var body: some View {
        Text(inventoryItem.title)
    }
}

#Preview {
    let inventoryItem = InventoryItem(id: "2d9aa668-fe7b-438a-bc79-09bf88f55308", title: "Coffee Maker", location: "Kitchen")
    return InventoryRow(inventoryItem: inventoryItem)
}
