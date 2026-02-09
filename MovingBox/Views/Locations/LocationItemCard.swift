//
//  LocationItemCard.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import Dependencies
import SQLiteData
import SwiftUI

struct LocationItemCard: View {
    @Dependency(\.defaultDatabase) var database
    var location: SQLiteInventoryLocation
    var itemCount: Int = 0
    var totalValue: Decimal = 0
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            // Photo section
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipped()
                } else if let sfSymbol = location.sfSymbolName {
                    // Show SF Symbol for default rooms
                    Rectangle()
                        .fill(
                            Color(.secondarySystemGroupedBackground)
                        )
                        .frame(width: 160, height: 100)
                        .overlay(
                            Image(systemName: sfSymbol)
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(.secondary)
                        )
                } else {
                    // Fallback to generic photo placeholder
                    Rectangle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 160, height: 100)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .tint(.secondary)
                        )
                }
            }
            .task(id: location.id) {
                thumbnail = await loadThumbnail()
            }

            // Location details
            VStack(alignment: .leading) {
                Text(location.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.label))
                HStack {
                    Text("Items")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                    Text("\(itemCount)")
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                }
                HStack {
                    Text("Value")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                    Text(CurrencyFormatter.format(totalValue))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius))
        .background(
            RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .padding(1)
    }

    private func loadThumbnail() async -> UIImage? {
        guard
            let photo = try? await database.read({ db in
                try SQLiteInventoryLocationPhoto.primaryPhoto(for: location.id, in: db)
            })
        else { return nil }
        return await OptimizedImageManager.shared.thumbnailImage(from: photo.data, photoID: photo.id.uuidString)
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    LocationItemCard(
        location: SQLiteInventoryLocation(id: UUID(), name: "Living Room", sfSymbolName: "sofa"),
        itemCount: 12,
        totalValue: 5000
    )
}
