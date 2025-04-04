//
//  InventoryList.swift
//  MovingBox
//
//  Created by Camden Webster on 4/9/24.
//

import SwiftData
import SwiftUI

struct InventoryListSubView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    
    @State private var items: [InventoryItem] = []
    
    let location: InventoryLocation?
    let searchString: String
    let sortOrder: [SortDescriptor<InventoryItem>]
    
    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "list.bullet",
                    description: Text("Start by adding items to your inventory.")
                )
            } else {
                Section {
                    ForEach(items) { inventoryItem in
                        NavigationLink(value: inventoryItem) {
                            InventoryItemRow(item: inventoryItem)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .onChange(of: searchString) { _, _ in
            Task {
                await loadItems()
            }
        }
        .task {
            await loadItems()
        }
    }
    
    init(location: InventoryLocation?, searchString: String = "", sortOrder: [SortDescriptor<InventoryItem>] = [SortDescriptor(\InventoryItem.title)]) {
        self.location = location
        self.searchString = searchString
        self.sortOrder = sortOrder
    }
    
    private func loadItems() async {
        // Guard against running during teardown
        guard !Task.isCancelled else {
            print("LoadItems cancelled - context might be invalidated")
            return
        }
        
        print("Starting to load items...")
        let descriptor = FetchDescriptor<InventoryItem>(sortBy: sortOrder)
        
        do {
            print("Fetching items from context...")
            var allItems = try modelContext.fetch(descriptor)
            print("Fetched \(allItems.count) items")
            
            // Filter by location if specified
            if let location = location {
                print("Filtering by location: \(location.name)")
                allItems = allItems.filter { item in
                    item.location?.persistentModelID == location.persistentModelID
                }
                print("After location filter: \(allItems.count) items")
            }
            
            // Apply search filter if specified
            if !searchString.isEmpty {
                print("Applying search filter: \(searchString)")
                allItems = allItems.filter { item in
                    let searchTerm = searchString.lowercased()
                    return item.title.localizedStandardContains(searchTerm) ||
                           item.desc.localizedStandardContains(searchTerm) ||
                           item.notes.localizedStandardContains(searchTerm) ||
                           item.make.localizedStandardContains(searchTerm) ||
                           item.model.localizedStandardContains(searchTerm) ||
                           item.serial.localizedStandardContains(searchTerm)
                }
                print("After search filter: \(allItems.count) items")
            }
            
            await MainActor.run {
                self.items = allItems
                print("Items set on MainActor: \(self.items.count)")
            }
        } catch {
            print("Failed to fetch items: \(error)")
            print("Error details: \(String(describing: error))")
            print("Model Context state: \(String(describing: modelContext))")
        }
    }

    func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = items[index]
            modelContext.delete(itemToDelete)
            print("Deleting item: \(itemToDelete.title)")
        }
        
        // Reload items after deletion
        Task {
            await loadItems()
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return InventoryListSubView(location: previewer.location)
            .modelContainer(previewer.container)
            .environmentObject(Router())
    } catch {
        return Text("Failed to create preview")
            .foregroundColor(.red)
    }
}
