//
//  InventoryListSubView.swift
//  MovingBox
//
//  Created by Camden Webster on 4/9/24.
//

import SwiftData
import SwiftUI

struct InventoryListSubView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var router: Router

    let location: InventoryLocation?
    let filterLabel: InventoryLabel?
    let searchString: String
    let sortOrder: [SortDescriptor<InventoryItem>]
    let showOnlyUnassigned: Bool
    let showAllHomes: Bool
    let activeHome: Home?
    @Binding var selectedItemIDs: Set<PersistentIdentifier>

    // Use @Query for lazy loading with dynamic predicate and sort
    @Query private var items: [InventoryItem]

    @State private var showItemCreationFlow = false

    var body: some View {
        listContent
            .movingBoxFullScreenCoverCompat(isPresented: $showItemCreationFlow) {
                EnhancedItemCreationFlowView(
                    captureMode: .singleItem,
                    location: location
                ) {
                    // Optional callback when item creation is complete
                }
                .tint(.green)
            }
    }

    @ViewBuilder
    private var listContent: some View {
        List(selection: $selectedItemIDs) {
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                itemsSection
            }
        }
    }

    // Computed property for filtered items - performs filtering in-memory only on fetched items
    private var filteredItems: [InventoryItem] {
        var result = items

        // Apply home filtering if needed (can't do this in predicate due to computed property)
        // Skip home filtering for unassigned items — they may lack a direct home reference
        if !showAllHomes, !showOnlyUnassigned, let activeHome = activeHome {
            result = result.filter { item in
                item.effectiveHome?.id == activeHome.id
            }
        }

        // Apply label filtering if needed (can't do in predicate with array.contains)
        if let filterLabel = filterLabel {
            result = result.filter { item in
                item.labels.contains { $0.id == filterLabel.id }
            }
        }

        // Apply search filtering if needed
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

        return result
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
        ForEach(filteredItems) { inventoryItem in
            itemRowView(for: inventoryItem)
                .tag(inventoryItem.persistentModelID)
        }
    }

    @ViewBuilder
    private func itemRowView(for inventoryItem: InventoryItem) -> some View {
        NavigationLink(value: inventoryItem) {
            InventoryItemRow(item: inventoryItem, showHomeBadge: showAllHomes)
                .listRowInsets(EdgeInsets())
        }
    }

    init(
        location: InventoryLocation?, filterLabel: InventoryLabel? = nil, searchString: String = "",
        sortOrder: [SortDescriptor<InventoryItem>] = [], showOnlyUnassigned: Bool = false, showAllHomes: Bool = false,
        activeHome: Home? = nil, selectedItemIDs: Binding<Set<PersistentIdentifier>> = .constant([])
    ) {
        self.location = location
        self.filterLabel = filterLabel
        self.searchString = searchString
        self.sortOrder = sortOrder
        self.showOnlyUnassigned = showOnlyUnassigned
        self.showAllHomes = showAllHomes
        self.activeHome = activeHome
        self._selectedItemIDs = selectedItemIDs

        // Build predicate based on location, label, or unassigned filter
        // Note: Home filtering is done in-memory in filteredItems computed property
        // because SwiftData predicates can't handle the effectiveHome computed property
        let predicate: Predicate<InventoryItem>?
        if showOnlyUnassigned {
            // Show only items without a location
            predicate = #Predicate<InventoryItem> { item in
                item.location == nil
            }
        } else if let location = location {
            // Show items for specific location
            let locationID = location.persistentModelID
            predicate = #Predicate<InventoryItem> { item in
                item.location?.persistentModelID == locationID
            }
        } else if let filterLabel = filterLabel {
            // Show items with specific label
            // Note: SwiftData predicates don't support array.contains well with persistentModelID,
            // so we filter in-memory via filteredItems computed property instead
            let labelID = filterLabel.id
            predicate = nil
        } else {
            // No predicate-level filtering needed
            // Home filtering happens in-memory via filteredItems
            predicate = nil
        }

        // Initialize @Query with predicate and sort descriptors
        let finalSortOrder = sortOrder.isEmpty ? [SortDescriptor(\InventoryItem.title)] : sortOrder
        _items = Query(filter: predicate, sort: finalSortOrder)
    }

}
