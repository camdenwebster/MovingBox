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
    @State private var isLoading = false
    
    let location: InventoryLocation?
    let searchString: String
    let sortOrder: [SortDescriptor<InventoryItem>]
    
    var body: some View {
        Group {
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
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let descriptor = FetchDescriptor<InventoryItem>(sortBy: sortOrder)
            var allItems = try modelContext.fetch(descriptor)
            
            if let location = location {
                allItems = allItems.filter { item in
                    item.location?.persistentModelID == location.persistentModelID
                }
            }
            
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
                self.isLoading = false
            }
        } catch {
            print("Error loading items: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = items[index]
            modelContext.delete(itemToDelete)
        }
        try? modelContext.save()
        
        Task {
            await loadItems()
        }
    }
}

//#Preview {
//    Group {
//        do {
//            let previewer = try Previewer()
//            InventoryListSubView(location: previewer.location)
//                .modelContainer(previewer.container)
//                .environmentObject(Router())
//        } catch {
//            ContentUnavailableView(
//                "Preview Error",
//                systemImage: "exclamationmark.triangle",
//                description: Text(error.localizedDescription)
//            )
//        }
//    }
//}
