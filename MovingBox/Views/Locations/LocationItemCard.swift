//
//  LocationItemCard.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

extension View {
    var recommendedCardShape: some Shape {
        if #available(iOS 16.0, *) {
            return RoundedRectangle(cornerRadius: 12, style: .continuous)
        } else {
            return RoundedRectangle(cornerRadius: 12, style: .circular)
        }
    }
}

struct LocationItemCard: View {
    var location: InventoryLocation
    var showCost: Bool = false
    @State private var thumbnail: UIImage?
    @State private var loadingError: Error?
    
    private var totalReplacementCost: Decimal {
        location.inventoryItems?.reduce(0, { $0 + ($1.price * Decimal($1.quantityInt)) }) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Photo section
            Group {
                if let thumbnail {
                    AsyncImage(url: location.thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
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
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(height: 100)
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
            .padding(.horizontal)
            .padding(.vertical)
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
