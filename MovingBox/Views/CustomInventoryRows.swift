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
            Stepper("\(inventoryItem.quantity)", value: $inventoryItem.quantity, in: 1...1000, step: 1)
        }
    }
}


#Preview {
    let inventoryItem = InventoryItem(id: UUID().uuidString, location: nil, label: nil)
    return InventoryStringRow(inventoryItem: inventoryItem)
}
