//
//  InventoryListSubView.swift
//  MovingBox
//
//  Created by Camden Webster on 4/9/24.
//

import Dependencies
import SQLiteData
import SwiftUI

struct InventoryListSubView: View {
    @Dependency(\.defaultDatabase) var database
    @EnvironmentObject var router: Router

    let locationID: UUID?
    let filterLabelID: UUID?
    let searchString: String
    let showOnlyUnassigned: Bool
    let showAllHomes: Bool
    let activeHomeID: UUID?
    let sortField: InventoryListView.SortField
    let sortAscending: Bool
    @Binding var selectedItemIDs: Set<UUID>

    @FetchAll(SQLiteInventoryItem.all, animation: .default)
    private var allItems: [SQLiteInventoryItem]

    @FetchAll(SQLiteInventoryItemLabel.all, animation: .default)
    private var allItemLabels: [SQLiteInventoryItemLabel]

    @FetchAll(SQLiteInventoryLabel.all, animation: .default)
    private var allLabels: [SQLiteInventoryLabel]

    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]

    @Environment(\.editMode) private var editMode
    @State private var showItemCreationFlow = false

    // Lookup for labels by item
    private var labelsByItemID: [UUID: [SQLiteInventoryLabel]] {
        let labelsById = Dictionary(uniqueKeysWithValues: allLabels.map { ($0.id, $0) })
        var result: [UUID: [SQLiteInventoryLabel]] = [:]
        for itemLabel in allItemLabels {
            if let label = labelsById[itemLabel.inventoryLabelID] {
                result[itemLabel.inventoryItemID, default: []].append(label)
            }
        }
        return result
    }

    // Lookup for home names by ID
    private var homeNameByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: homes.map { ($0.id, $0.displayName) })
    }

    // Filtered and sorted items
    private var filteredItems: [SQLiteInventoryItem] {
        var result = allItems

        // Filter by location
        if showOnlyUnassigned {
            result = result.filter { $0.locationID == nil }
        } else if let locationID = locationID {
            result = result.filter { $0.locationID == locationID }
        }

        // Filter by home
        if !showAllHomes, !showOnlyUnassigned, let activeHomeID = activeHomeID {
            result = result.filter { $0.homeID == activeHomeID }
        }

        // Filter by label
        if let filterLabelID = filterLabelID {
            let itemIDsWithLabel = Set(
                allItemLabels.filter { $0.inventoryLabelID == filterLabelID }.map { $0.inventoryItemID })
            result = result.filter { itemIDsWithLabel.contains($0.id) }
        }

        // Search filter
        if !searchString.isEmpty {
            let lowercasedTerm = searchString.lowercased()
            result = result.filter { item in
                item.title.localizedStandardContains(lowercasedTerm)
                    || item.desc.localizedStandardContains(lowercasedTerm)
                    || item.notes.localizedStandardContains(lowercasedTerm)
                    || item.make.localizedStandardContains(lowercasedTerm)
                    || item.model.localizedStandardContains(lowercasedTerm)
                    || item.serial.localizedStandardContains(lowercasedTerm)
            }
        }

        // Sort
        switch sortField {
        case .title:
            result.sort {
                sortAscending
                    ? $0.title.localizedCompare($1.title) == .orderedAscending
                    : $0.title.localizedCompare($1.title) == .orderedDescending
            }
        case .date:
            result.sort { sortAscending ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }
        case .value:
            result.sort { sortAscending ? $0.price < $1.price : $0.price > $1.price }
        }

        return result
    }

    var body: some View {
        listContent
            .fullScreenCover(isPresented: $showItemCreationFlow) {
                EnhancedItemCreationFlowView(
                    captureMode: .singleItem,
                    locationID: locationID
                ) {
                    // Optional callback when item creation is complete
                }
                .tint(.green)
            }
    }

    private var selectionBinding: Binding<Set<UUID>>? {
        editMode?.wrappedValue == .active ? $selectedItemIDs : nil
    }

    @ViewBuilder
    private var listContent: some View {
        List(selection: selectionBinding) {
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                itemsSection
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Items", systemImage: "list.bullet")
        } description: {
            Text("Start by adding items to your inventory")
        } actions: {
            Button("Add Item") {
                showItemCreationFlow = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("inventory-list-empty-state-add-item-button")
        }
    }

    @ViewBuilder
    private var itemsSection: some View {
        ForEach(filteredItems) { item in
            itemRowView(for: item)
                .tag(item.id)
        }
        .onDelete(perform: deleteItems)
    }

    private func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredItems[$0] }
        do {
            try database.write { db in
                for item in itemsToDelete {
                    try SQLiteInventoryItem.find(item.id).delete().execute(db)
                }
            }
        } catch {
            print("Failed to delete items: \(error)")
        }
    }

    @ViewBuilder
    private func itemRowView(for item: SQLiteInventoryItem) -> some View {
        NavigationLink(value: Router.Destination.inventoryDetailView(itemID: item.id, showSparklesButton: true)) {
            InventoryItemRow(
                item: item,
                homeName: item.homeID.flatMap { homeNameByID[$0] },
                labels: labelsByItemID[item.id] ?? [],
                showHomeBadge: showAllHomes
            )
            .listRowInsets(EdgeInsets())
        }
    }
}
