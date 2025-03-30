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
    
    private var totalReplacementCost: Decimal {
        location.inventoryItems?.reduce(0, { $0 + $1.price }) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Photo section
            Group {
                if let uiImage = location.photo {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
//                        .frame(width: 160, height: 160)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 160, height: 160)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        )
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
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2, y: 1)
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
