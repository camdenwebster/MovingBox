//
//  LabelItemCard.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SQLiteData
import SwiftUI

struct LabelItemCard: View {
    var label: SQLiteInventoryLabel
    var itemCount: Int = 0
    var totalValue: Decimal = 0

    var body: some View {
        VStack(spacing: 0) {
            // Photo section
            VStack {
                Text(label.emoji)
                    .font(.system(size: 60))
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .background(Color(label.color ?? .systemGray5))
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
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    LabelItemCard(
        label: SQLiteInventoryLabel(id: UUID(), name: "Electronics", color: .blue, emoji: "💻"),
        itemCount: 5,
        totalValue: 2500
    )
}
