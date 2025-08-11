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
    let isSelectionMode: Bool
    @Binding var selectedItemIDs: Set<PersistentIdentifier>
    
    // Use @Query for lazy loading with dynamic predicate and sort
    @Query private var items: [InventoryItem]
    
    var body: some View {
        listContent
    }
    
    @ViewBuilder
    private var listContent: some View {
        List {
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
        ContentUnavailableView(
            "No Items",
            systemImage: "list.bullet",
            description: Text("Start by adding items to your inventory.")
        )
    }
    
    @ViewBuilder
    private var itemsSection: some View {
        if isSelectionMode {
            ForEach(filteredItems) { inventoryItem in
                itemRowView(for: inventoryItem)
            }
        } else {
            ForEach(filteredItems) { inventoryItem in
                itemRowView(for: inventoryItem)
            }
            .onDelete(perform: deleteItems)
        }
    }
    
    @ViewBuilder
    private func itemRowView(for inventoryItem: InventoryItem) -> some View {
        if isSelectionMode {
            selectionModeRow(for: inventoryItem)
        } else {
            navigationLinkRow(for: inventoryItem)
        }
    }
    
    @ViewBuilder
    private func selectionModeRow(for inventoryItem: InventoryItem) -> some View {
        HStack {
            selectionButton(for: inventoryItem)
            
            InventoryItemRow(item: inventoryItem)
                .listRowInsets(EdgeInsets())
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(for: inventoryItem)
                }
        }
    }
    
    @ViewBuilder
    private func selectionButton(for inventoryItem: InventoryItem) -> some View {
        Button(action: {
            toggleSelection(for: inventoryItem)
        }) {
            let isSelected = selectedItemIDs.contains(inventoryItem.persistentModelID)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func navigationLinkRow(for inventoryItem: InventoryItem) -> some View {
        NavigationLink(value: inventoryItem) {
            InventoryItemRow(item: inventoryItem)
                .listRowInsets(EdgeInsets())
        }
    }
    
    init(location: InventoryLocation?, searchString: String = "", sortOrder: [SortDescriptor<InventoryItem>] = [], isSelectionMode: Bool = false, selectedItemIDs: Binding<Set<PersistentIdentifier>> = .constant([])) {
        self.location = location
        self.searchString = searchString
        self.sortOrder = sortOrder
        self.isSelectionMode = isSelectionMode
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
    
    private func toggleSelection(for item: InventoryItem) {
        let itemID = item.persistentModelID
        if selectedItemIDs.contains(itemID) {
            selectedItemIDs.remove(itemID)
        } else {
            selectedItemIDs.insert(itemID)
        }
    }
    
    
    @MainActor
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = filteredItems[index]
            modelContext.delete(itemToDelete)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving after delete: \(error)")
        }
    }
}