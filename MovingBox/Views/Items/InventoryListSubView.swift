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
    let searchString: String
    let sortOrder: [SortDescriptor<InventoryItem>]
    @Binding var selectedItemIDs: Set<PersistentIdentifier>
    
    // Use @Query for lazy loading with dynamic predicate and sort
    @Query private var items: [InventoryItem]
    
    var body: some View {
        listContent
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
        
        // Apply search filtering if needed
        if !searchString.isEmpty {
            let lowercasedTerm = searchString.lowercased()
            result = result.filter { item in
                item.title.localizedStandardContains(lowercasedTerm) ||
                item.desc.localizedStandardContains(lowercasedTerm) ||
                item.notes.localizedStandardContains(lowercasedTerm) ||
                item.make.localizedStandardContains(lowercasedTerm) ||
                item.model.localizedStandardContains(lowercasedTerm) ||
                item.serial.localizedStandardContains(lowercasedTerm)
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
                Button("Take a photo") {
                    router.navigate(to: .addInventoryItemView(location: nil))
                }
                .buttonStyle(.borderedProminent)
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
            InventoryItemRow(item: inventoryItem)
                .listRowInsets(EdgeInsets())
        }
    }
    
    
    init(location: InventoryLocation?, searchString: String = "", sortOrder: [SortDescriptor<InventoryItem>] = [], selectedItemIDs: Binding<Set<PersistentIdentifier>> = .constant([])) {
        self.location = location
        self.searchString = searchString
        self.sortOrder = sortOrder
        self._selectedItemIDs = selectedItemIDs
        
        // Build predicate based on location
        let predicate: Predicate<InventoryItem>?
        if let location = location {
            let locationID = location.persistentModelID
            predicate = #Predicate<InventoryItem> { item in
                item.location?.persistentModelID == locationID
            }
        } else {
            predicate = nil
        }
        
        // Initialize @Query with predicate and sort descriptors
        let finalSortOrder = sortOrder.isEmpty ? [SortDescriptor(\InventoryItem.title)] : sortOrder
        _items = Query(filter: predicate, sort: finalSortOrder)
    }
    
    
    
}
