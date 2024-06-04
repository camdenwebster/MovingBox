//
//  InventoryList.swift
//  FirebaseCRUD-CamdenW
//
//  Created by Camden Webster on 4/9/24.
//

import SwiftData
import SwiftUI

struct InventoryListView: View {
    @Environment(\.modelContext) var modelContext
    @Query var inventoryItemsForSelectedLocation: [InventoryItem]
    
    var body: some View {
        List {
            Section {
                ForEach(inventoryItemsForSelectedLocation) { inventoryItem in
                    NavigationLink(value: inventoryItem) {
                        Text(inventoryItem.title)
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
    }
    
    init(searchString: String = "", sortOrder: [SortDescriptor<InventoryItem>] = []) {
        _inventoryItemsForSelectedLocation = Query(filter: #Predicate { inventoryItemsForSelectedLocation in
            if searchString.isEmpty {
                true
            } else {
                inventoryItemsForSelectedLocation.title.localizedStandardContains(searchString)
                || inventoryItemsForSelectedLocation.desc.localizedStandardContains(searchString)
                ||
                inventoryItemsForSelectedLocation.notes.localizedStandardContains(searchString)
                ||
                inventoryItemsForSelectedLocation.make.localizedStandardContains(searchString)
                || inventoryItemsForSelectedLocation.model.localizedStandardContains(searchString)
                || inventoryItemsForSelectedLocation.serial.localizedStandardContains(searchString)
            }
        }, sort: sortOrder)
    }
    
    func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = inventoryItemsForSelectedLocation[index]
            modelContext.delete(itemToDelete)
            print("Deleting item id: \(itemToDelete.id), title: \(itemToDelete.title)")
        }
    }
}




#Preview {
    InventoryListView()
}
