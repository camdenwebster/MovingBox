//
//  LocationItemCard.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

struct LocationItemCard: View {
    var location: InventoryLocation
    var body: some View {
        VStack(spacing: 0) {
            // Photo section
            Group {
                if let uiImage = location.photo {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
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
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.label))
                
                HStack {
                    Text("Items")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                    Text("\(location.inventoryItems?.count ?? 0)")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
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
