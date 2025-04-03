//
//  InventoryList.swift
//  FirebaseCRUD-CamdenW
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
        let descriptor = FetchDescriptor<InventoryItem>(sortBy: sortOrder)
        
        do {
            var allItems = try modelContext.fetch(descriptor)
            
            // Filter by location if specified
            if let location = location {
                allItems = allItems.filter { item in
                    item.location?.persistentModelID == location.persistentModelID
                }
            }
            
            // Apply search filter if specified
            if !searchString.isEmpty {
                allItems = allItems.filter { item in
                    let searchTerm = searchString.lowercased()
                    return item.title.localizedStandardContains(searchTerm) ||
                           item.desc.localizedStandardContains(searchTerm) ||
                           item.notes.localizedStandardContains(searchTerm) ||
                           item.make.localizedStandardContains(searchTerm) ||
                           item.model.localizedStandardContains(searchTerm) ||
                           item.serial.localizedStandardContains(searchTerm)
                }
            }
            
            await MainActor.run {
                self.items = allItems
            }
        } catch {
            print("Failed to fetch items: \(error)")
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
