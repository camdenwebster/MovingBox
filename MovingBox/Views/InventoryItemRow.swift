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
//            if let imageData = item.photo, let uiImage = UIImage(data: imageData) {
            Image(uiImage: item.photo == nil ? Constants.placeholderImage : item.photo!)
                .resizable()
                .imageListViewStyle()
            VStack(alignment: .leading) {
                Text(item.title)
                if item.make != "" {
                    Text("\(item.make) \(item.model)")
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



#Preview {
    do {
        let previewer = try Previewer()
        
        return InventoryItemRow(item: previewer.inventoryItem)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
