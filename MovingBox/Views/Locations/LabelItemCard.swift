//
//  LabelItemCard.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

struct LabelItemCard: View {
    var label: InventoryLabel
    var showCost: Bool = false
    @State private var thumbnail: UIImage?
    @State private var loadingError: Error?
    
    private var totalReplacementCost: Decimal {
        label.inventoryItems?.reduce(0, { $0 + $1.price }) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Photo section
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 160, height: 100)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        )
                }
            }

            
            // Label details
            VStack(alignment: .leading) {
                Text(label.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.label))
                HStack {
                    Text("Items")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                    Text("\(label.inventoryItems?.count ?? 0)")
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1))
        .padding(1)
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return LabelItemCard(label: previewer.label)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
