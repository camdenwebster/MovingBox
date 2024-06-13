//
//  InventoryListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftUI

enum Options: Hashable {
    case destination(String)
}

struct InventoryListView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @State private var path = NavigationPath()
    @State private var sortOrder = [SortDescriptor(\InventoryItem.title)]
    @State private var searchText = ""
    let location: InventoryLocation
    
    var body: some View {
        InventoryListSubView(locationId: location.id, searchString: searchText, sortOrder: sortOrder)
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
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
    
    func createNewItem() {
        let newInventoryItem = InventoryItem(id: UUID().uuidString, location: nil, label: nil)
        modelContext.insert(newInventoryItem)
        router.navigate(to: .editInventoryItemView(item: newInventoryItem))
        print("New item created with id \(newInventoryItem.id)")
    }
    
    func editItems() {
        print("Edit button pressed")
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return InventoryListView(location: previewer.location)
            .modelContainer(previewer.container)

    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
