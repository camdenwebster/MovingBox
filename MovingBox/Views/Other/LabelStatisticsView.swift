//
//  LabelStatisticsView.swift
//  MovingBox
//
//  Created by AI Assistant on 1/10/25.
//

import SwiftData
import SwiftUI

struct LabelStatisticsView: View {
    @Query(sort: [SortDescriptor(\InventoryLabel.name)]) private var labels: [InventoryLabel]
    private let row = GridItem(.fixed(160))
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Label Statistics")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            if labels.isEmpty {
                ContentUnavailableView(
                    "No Labels",
                    systemImage: "tag",
                    description: Text("Add labels to categorize your items")
                )
                .frame(height: 160)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [row], spacing: 16) {
                        ForEach(labels) { label in
                            LabelItemCard(label: label)
                                .frame(width: 150)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return LabelStatisticsView()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}