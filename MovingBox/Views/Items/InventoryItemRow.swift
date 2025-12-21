//
//  InventoryItemRow.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

struct InventoryItemRow: View {
    var item: InventoryItem
    var showHomeBadge: Bool = false
    @State private var imageLoadTrigger = 0
    @State private var hasRetried = false

    var body: some View {
        HStack {
            AsyncImage(url: item.thumbnailURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color(.systemGray6)
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure:
                    ZStack {
                        Color(.systemGray6)
                        Image(systemName: "photo.trianglebadge.exclamationmark")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .onAppear {
                        // Retry loading once after a brief delay to handle race conditions
                        // where thumbnail file isn't quite ready yet
                        guard !hasRetried else { return }
                        hasRetried = true
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                            imageLoadTrigger += 1
                        }
                    }
                @unknown default:
                    ZStack {
                        Color(.systemGray6)
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                }
            }
            .id(imageLoadTrigger)
            VStack(alignment: .leading) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if showHomeBadge, let home = item.effectiveHome {
                    Text(home.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
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

