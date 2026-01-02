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
    @State private var hasRetried = false

    var body: some View {
        HStack {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ZStack {
                        Color(.systemGray6)
                        Image(systemName: hasRetried ? "photo.trianglebadge.exclamationmark" : "photo")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                }
            }
            .task(id: item.imageURL) {
                await loadThumbnail()
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

    @MainActor
    private func loadThumbnail() async {
        hasRetried = false
        guard item.imageURL != nil else {
            thumbnail = nil
            return
        }
        
        do {
            thumbnail = try await item.thumbnail
        } catch {
            guard !hasRetried else {
                thumbnail = nil
                return
            }
            
            hasRetried = true
            try? await Task.sleep(nanoseconds: 200_000_000)
            do {
                thumbnail = try await item.thumbnail
            } catch {
                thumbnail = nil
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
