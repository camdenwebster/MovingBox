//
//  InventoryItemRow.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SQLiteData
import SwiftUI

struct InventoryItemRow: View {
    var item: SQLiteInventoryItem
    var homeName: String?
    var labels: [SQLiteInventoryLabel] = []
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
                            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
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

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if showHomeBadge, let homeName {
                    Label(homeName, systemImage: "house.circle")
                        .detailLabelStyle()
                }

                if !item.make.isEmpty {
                    Label("\(item.make) \(item.model)", systemImage: "info.circle")
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
