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
    @EnvironmentObject var router: Router
    
    private let row = GridItem(.fixed(160))
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DashboardSectionLabel(text: "Labels", isButton: false)
            
            if labels.isEmpty {
                ContentUnavailableView {
                        Label("No Labels", systemImage: "tag")
                    } description: {
                        Text("Add labels to categorize your items")
                    } actions: {
                        Button("Add a Label") {
                            router.navigate(to: .editLabelView(label: nil, isEditing: true))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(height: 160)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [row], spacing: 16) {
                        ForEach(labels) { label in
                            LabelItemCard(label: label)
                                .frame(width: 180)
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
