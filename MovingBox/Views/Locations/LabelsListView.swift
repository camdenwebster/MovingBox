//
//  LabelsListView.swift
//  MovingBox
//
//  Created by Claude Code on 1/17/26.
//

import SQLiteData
import SwiftUI

struct LabelsListView: View {
    let showAllHomes: Bool  // Kept for API compatibility but no longer affects filtering

    @EnvironmentObject var router: Router
    @State private var searchText = ""

    @FetchAll(SQLiteInventoryLabel.order(by: \.name), animation: .default)
    private var allLabels: [SQLiteInventoryLabel]

    @FetchAll(SQLiteInventoryItemLabel.all, animation: .default)
    private var allItemLabels: [SQLiteInventoryItemLabel]

    @FetchAll(SQLiteInventoryItem.all, animation: .default)
    private var allItems: [SQLiteInventoryItem]

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

    // Filtered labels based on search
    private var filteredLabels: [SQLiteInventoryLabel] {
        if searchText.isEmpty {
            return allLabels
        }
        return allLabels.filter { label in
            label.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var columns: [GridItem] {
        let minimumCardWidth: CGFloat = 160
        let maximumCardWidth: CGFloat = 220
        return [GridItem(.adaptive(minimum: minimumCardWidth, maximum: maximumCardWidth))]
    }

    var body: some View {
        Group {
            if filteredLabels.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    "No Labels",
                    systemImage: "tag",
                    description: Text("Add labels to categorize your items.")
                )
                .toolbar {
                    ToolbarItem {
                        Button {
                            router.navigate(to: .editLabelView(labelID: nil, isEditing: true))
                        } label: {
                            Label("Add Label", systemImage: "plus")
                        }
                        .accessibilityIdentifier("addLabel")
                    }
                }
            } else if filteredLabels.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No labels found matching '\(searchText)'")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredLabels) { label in
                            NavigationLink(
                                value: Router.Destination.inventoryListViewForLabel(labelID: label.id)
                            ) {
                                LabelItemCard(
                                    label: label,
                                    itemCount: labelItemData[label.id]?.count ?? 0,
                                    totalValue: labelItemData[label.id]?.value ?? 0
                                )
                                .frame(maxWidth: 180)
                            }
                        }
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem {
                        Button {
                            router.navigate(to: .editLabelView(labelID: nil, isEditing: true))
                        } label: {
                            Label("Add Label", systemImage: "plus")
                        }
                        .accessibilityIdentifier("addLabel")
                    }
                }
            }
        }
        .navigationTitle("Labels")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search labels")
        .background(Color(.systemGroupedBackground))
        .onAppear {
            print("LabelsListView: Total number of labels: \(allLabels.count)")
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    LabelsListView(showAllHomes: false)
        .environmentObject(Router())
}
