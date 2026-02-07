//
//  LabelCapsuleView.swift
//  MovingBox
//
//  Created by Camden Webster on 1/19/26.
//

import SQLiteData
import SwiftUI

struct LabelCapsuleView: View {
    let label: SQLiteInventoryLabel

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
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    LabelCapsuleView(label: SQLiteInventoryLabel(id: UUID(), name: "Test", color: .blue, emoji: "📦"))
}
