//
//  LocationItemCard.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

struct LocationItemCard: View {
    var location: InventoryLocation
    var showCost: Bool = false
    @State private var thumbnail: UIImage?
    @State private var loadingError: Error?
    @Environment(\.modelContext) private var modelContext

    private var totalReplacementCost: Decimal {
        location.inventoryItems?.reduce(0, { $0 + $1.price }) ?? 0
    }

    private var childCount: Int {
        location.getChildren(in: modelContext).count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Photo section
            Group {
                if thumbnail != nil {
                    AsyncImage(url: location.thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 100)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.secondary)
                            }
                    }
                } else if let sfSymbol = location.sfSymbolName {
                    // Show SF Symbol for default rooms
                    Rectangle()
                        .fill(Color(.secondarySystemGroupedBackground)
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
            .overlay(alignment: .topTrailing) {
                // Show child location count badge
                if childCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                        Text("\(childCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(6)
                }
            }
            .task(id: location.imageURL) {
                do {
                    thumbnail = try await location.thumbnail
                } catch {
                    loadingError = error
                    thumbnail = nil
                }
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
                    Text("\(location.inventoryItems?.count ?? 0)")
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                }
                HStack {
                    Text("Value")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                    Text(CurrencyFormatter.format(totalReplacementCost))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius))
        .background(RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1))
        .padding(1)
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return LocationItemCard(location: previewer.location)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
