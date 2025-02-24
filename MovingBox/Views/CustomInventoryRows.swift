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
    let inventoryItem = InventoryItem(title: "", quantityString: "1", quantityInt: 1, desc: "", serial: "", model: "", make: "", location: nil, label: nil, price: "", insured: false, assetId: "", notes: "", showInvalidQuantityAlert: false)
    InventoryStringRow(inventoryItem: inventoryItem)
}
