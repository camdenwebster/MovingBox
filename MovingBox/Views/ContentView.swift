//
//  ContentView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @State private var path = NavigationPath()
    @State private var sortOrder = [SortDescriptor(\InventoryItem.title)]
    
    @State private var searchText = ""
        
    var body: some View {
        NavigationStack(path: $path) {
            InventoryListView(searchString: searchText, sortOrder: sortOrder)
                .navigationTitle("Home Inventory")
                .navigationDestination(for: InventoryItem.self) { inventoryItem in EditInventoryItemView(inventoryItemToDisplay: inventoryItem, navigationPath: $path)
                }
                .toolbar {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort", selection: $sortOrder) {
                            Text("Title (A-Z)")
                                .tag([SortDescriptor(\InventoryItem.title)])
                            Text("Title (Z-A)")
                                .tag([SortDescriptor(\InventoryItem.title, order: .reverse)])
                        }
                    }
                    Button("Add Item", systemImage: "plus", action: createNewItem)
                }
                .searchable(text: $searchText)
        }
    }
        
    func createNewItem() {
        let newInventoryItem = InventoryItem(id: UUID().uuidString, title: "", quantityString: "1", quantityInt: 1, desc: "", serial: "", model: "", make: "", location: nil, label: nil, price: "", insured: false, assetId: "", notes: "", showInvalidQuantityAlert: false)
        modelContext.insert(newInventoryItem)
        path.append(newInventoryItem)
        print("New item created with id \(newInventoryItem.id)")
    }
    
    func editItems() {
        print("Edit button pressed")
    }
}



#Preview {
    do {
        let previewer = try Previewer()
        return ContentView()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

