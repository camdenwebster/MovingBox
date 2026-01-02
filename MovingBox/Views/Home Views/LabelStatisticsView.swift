//
//  LabelStatisticsView.swift
//  MovingBox
//
//  Created by AI Assistant on 1/10/25.
//

import SwiftData
import SwiftUI

struct LabelStatisticsView: View {
    @Query(sort: [SortDescriptor(\InventoryLabel.name)]) private var allLabels: [InventoryLabel]
    @Query(sort: \Home.purchaseDate) private var homes: [Home]
    @EnvironmentObject var router: Router
    @EnvironmentObject var settingsManager: SettingsManager

    private let row = GridItem(.fixed(160))

    private var activeHome: Home? {
        guard let activeIdString = settingsManager.activeHomeId,
              let activeId = UUID(uuidString: activeIdString) else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    // Filter labels by active home
    private var labels: [InventoryLabel] {
        guard let activeHome = activeHome else {
            return allLabels
        }
        return allLabels.filter { $0.home?.id == activeHome.id }
    }
    
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
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
