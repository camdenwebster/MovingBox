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
            AsyncImage(url: item.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
            } placeholder: {
                ZStack {
                    Color(.systemGray6)
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            }
            VStack(alignment: .leading) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
//                if item.make != "" {
//                    Text("Make: \(item.make)")
//                        .lineLimit(1)
//                        .truncationMode(.tail)
//                        .detailLabelStyle()
//                } else {
//                    EmptyView()
//                }
//                if item.model != "" {
//                    Text("Model: \(item.model)")
//                        .lineLimit(1)
//                        .truncationMode(.tail)
//                        .detailLabelStyle()
//                } else {
//                    EmptyView()
//                }
            }
            Spacer()
            if let label = item.label {
                Text(label.emoji)
                    .padding(7)
                    .background(in: Circle())
                    .backgroundStyle(Color(label.color ?? .blue))
            } else {
                EmptyView()
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
