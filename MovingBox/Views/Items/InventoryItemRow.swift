//
//  InventoryItemRow.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

struct InventoryItemRow: View {
    var item: InventoryItem
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack {
            Group {
                if let uiImage = thumbnail {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 80, maxHeight: 60)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 80, maxHeight: 60)
                        .clipped()
                        .cornerRadius(8)
                }
            }
            .task {
                do {
                    thumbnail = try await item.thumbnail
                } catch {
                    print("Error loading thumbnail: \(error)")
                }
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
            }
            Spacer()
            if let label = item.label {
                Text(label.name)
                    .foregroundStyle(.white)
                    .font(.caption)
                    .padding(5)
                    .background(in: Capsule())
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
