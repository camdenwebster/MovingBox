//
//  InventoryRow.swift
//  FirebaseCRUD-CamdenW
//
//  Created by Camden Webster on 4/12/24.
//

import SwiftUI


struct InventoryStringRow: View {
    var inventoryItem: InventoryItem
    var body: some View {
        Text(inventoryItem.title)
    }
}

struct InventoryQuantityRow: View {
    @State var inventoryItem: InventoryItem
    var body: some View {
        HStack {
            TextField("", text: $inventoryItem.quantityString)
            Stepper("\(inventoryItem.quantityInt)", value: $inventoryItem.quantityInt, in: 1...1000, step: 1)
        }
    }
}


#Preview {
    let inventoryItem = InventoryItem(id: "2d9aa668-fe7b-438a-bc79-09bf88f55308", title: "Coffee Maker", location: "Kitchen")
    return InventoryStringRow(inventoryItem: inventoryItem)
}
