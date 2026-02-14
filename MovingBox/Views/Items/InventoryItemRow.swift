//
//  InventoryItemRow.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import Dependencies
import SQLiteData
import SwiftUI

struct InventoryItemRow: View {
    @Dependency(\.defaultDatabase) var database
    var item: SQLiteInventoryItem
    var homeName: String?
    var labels: [SQLiteInventoryLabel] = []
    var showHomeBadge: Bool = false
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(.rect(cornerRadius: 12))
                } else {
                    ZStack {
                        Color(.systemGray6)
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(.rect(cornerRadius: 8))
                }
            }
            .task(id: item.id) {
                thumbnail = await loadThumbnail()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if showHomeBadge, let homeName {
                    HStack {
                        Image(systemName: "house.circle")
                        Text(homeName)
                    }
                    .detailLabelStyle()
                }

                if !item.make.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("\(item.make) \(item.model)")
                    }
                    .detailLabelStyle()
                }
            }

            Spacer()

            // Display all label emojis in a horizontal stack (max 5)
            if !labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(labels.prefix(5)) { label in
                        Text(label.emoji)
                            .font(.caption)
                            .padding(5)
                            .background(in: Circle())
                            .backgroundStyle(Color(label.color ?? .blue))
                    }
                }
            }
        }
    }

    private func loadThumbnail() async -> UIImage? {
        guard
            let photo = try? await database.read({ db in
                try SQLiteInventoryItemPhoto.primaryPhoto(for: item.id, in: db)
            })
        else { return nil }
        return await OptimizedImageManager.shared.thumbnailImage(from: photo.data, photoID: photo.id.uuidString)
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    InventoryItemRow(
        item: SQLiteInventoryItem(id: UUID(), title: "MacBook Pro", model: "M4 Pro", make: "Apple"),
        homeName: "Main House",
        labels: [SQLiteInventoryLabel(id: UUID(), name: "Electronics", color: .blue, emoji: "💻")],
        showHomeBadge: true
    )
}
