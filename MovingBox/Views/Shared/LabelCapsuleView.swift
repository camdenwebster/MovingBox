//
//  LabelCapsuleView.swift
//  MovingBox
//
//  Created by Camden Webster on 1/19/26.
//

import SwiftUI

struct LabelCapsuleView: View {
    let label: InventoryLabel

    var body: some View {
        let backgroundColor = Color(label.color ?? .blue)
        HStack {
            Text(label.emoji)
            Text(label.name)
                .fontDesign(.rounded)
                .fontWeight(.bold)
                .foregroundStyle(backgroundColor.idealTextColor())

        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(in: Capsule())
        .backgroundStyle(backgroundColor.gradient)
    }
}

#Preview {
    let label = InventoryLabel()
    LabelCapsuleView(label: label)
}
