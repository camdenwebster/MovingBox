//
//  LabelStatisticsView.swift
//  MovingBox
//
//  Created by AI Assistant on 1/10/25.
//

import SQLiteData
import SwiftUI

struct LabelStatisticsView: View {
    @FetchAll(SQLiteInventoryLabel.order(by: \.name), animation: .default)
    private var allLabels: [SQLiteInventoryLabel]

    @FetchAll(SQLiteInventoryItemLabel.all, animation: .default)
    private var allItemLabels: [SQLiteInventoryItemLabel]

    @FetchAll(SQLiteInventoryItem.all, animation: .default)
    private var allItems: [SQLiteInventoryItem]

    @EnvironmentObject var router: Router

    private let row = GridItem(.fixed(160))

    // Labels are global (not filtered by home)
    private var labels: [SQLiteInventoryLabel] {
        allLabels
    }

    // Precomputed lookup for item counts/values per label
    private var labelItemData: [UUID: (count: Int, value: Decimal)] {
        var result: [UUID: (count: Int, value: Decimal)] = [:]
        let itemsByID = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        for itemLabel in allItemLabels {
            let item = itemsByID[itemLabel.inventoryItemID]
            let price = item.map { $0.price * Decimal($0.quantityInt) } ?? 0
            if var existing = result[itemLabel.inventoryLabelID] {
                existing.count += 1
                existing.value += price
                result[itemLabel.inventoryLabelID] = existing
            } else {
                result[itemLabel.inventoryLabelID] = (count: 1, value: price)
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                router.navigate(to: .labelsListView(showAllHomes: false))
            } label: {
                DashboardSectionLabel(text: "Labels")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard-labels-button")

            if labels.isEmpty {
                ContentUnavailableView {
                    Label("No Labels", systemImage: "tag")
                } description: {
                    Text("Add labels to categorize your items")
                } actions: {
                    Button("Add a Label") {
                        router.navigate(to: .editLabelView(labelID: nil, isEditing: true))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(height: 160)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [row], spacing: 16) {
                        ForEach(labels) { label in
                            NavigationLink(
                                value: Router.Destination.inventoryListViewForLabel(labelID: label.id)
                            ) {
                                LabelItemCard(
                                    label: label,
                                    itemCount: labelItemData[label.id]?.count ?? 0,
                                    totalValue: labelItemData[label.id]?.value ?? 0
                                )
                                .frame(width: 180)
                            }
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
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    LabelStatisticsView()
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
