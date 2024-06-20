//
//  InventoryItemRow.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

struct InventoryItemRow: View {
    var item: InventoryItem
    var body: some View {
        HStack {
            if let uiImage = item.photo {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            }
            VStack(alignment: .leading) {
                Text(item.title)
                if item.make != "" {
                    Text("Make: \(item.make)")
                        .detailLabelStyle()
                } else {
                    EmptyView()
                }
                if item.model != "" {
                    Text("Model: \(item.model)")
                        .detailLabelStyle()
                } else {
                    EmptyView()
                }
                if let label = item.label {
                    Text("Label: \(label.name)")
                        .detailLabelStyle()
                } else {
                    EmptyView()
                }
                
            }
        }
    }
}



//#Preview {
//    item = InventoryItem(id: UUID, title: <#T##String#>, quantityString: <#T##String#>, quantityInt: <#T##Int#>, desc: <#T##String#>, serial: <#T##String#>, model: <#T##String#>, make: <#T##String#>, location: <#T##InventoryLocation?#>, label: <#T##InventoryLabel?#>, price: <#T##String#>, insured: <#T##Bool#>, assetId: <#T##String#>, notes: <#T##String#>, showInvalidQuantityAlert: <#T##Bool#>)
//    InventoryItemRow(item: item)
//}
