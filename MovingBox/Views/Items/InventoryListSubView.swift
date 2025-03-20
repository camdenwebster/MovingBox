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
    
    @Query private var inventoryItems: [InventoryItem]
    
    let location: InventoryLocation?
    let searchString: String
    
    var body: some View {
        List {
            if inventoryItems.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "list.bullet",
                    description: Text("Start by adding items to your inventory.")
                ) }
            else {
                Section {
                    ForEach(inventoryItems) { inventoryItem in
                        NavigationLink(value: inventoryItem) {
                            InventoryItemRow(item: inventoryItem)
                                .listRowInsets(EdgeInsets()) // Remove default row padding
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
    }
    
    init(location: InventoryLocation?, searchString: String = "", sortOrder: [SortDescriptor<InventoryItem>] = [SortDescriptor(\InventoryItem.title)]) {
        self.location = location
        self.searchString = searchString
        
        let predicate: Predicate<InventoryItem>
        
        if let location = location {
            let locationId = location.persistentModelID
            if searchString.isEmpty {
                predicate = #Predicate<InventoryItem> { item in
                    item.location?.persistentModelID == locationId
                }
            } else {
                predicate = #Predicate<InventoryItem> { item in
                    (item.location?.persistentModelID == locationId) &&
                    (item.title.localizedStandardContains(searchString) ||
                     item.desc.localizedStandardContains(searchString) ||
                     item.notes.localizedStandardContains(searchString) ||
                     item.make.localizedStandardContains(searchString) ||
                     item.model.localizedStandardContains(searchString) ||
                     item.serial.localizedStandardContains(searchString))
                }
            }
        } else {
            if searchString.isEmpty {
                predicate = #Predicate<InventoryItem> { _ in true }
            } else {
                predicate = #Predicate<InventoryItem> { item in
                    item.title.localizedStandardContains(searchString) ||
                    item.desc.localizedStandardContains(searchString) ||
                    item.notes.localizedStandardContains(searchString) ||
                    item.make.localizedStandardContains(searchString) ||
                    item.model.localizedStandardContains(searchString) ||
                    item.serial.localizedStandardContains(searchString)
                }
            }
        }
        
        _inventoryItems = Query(
            filter: predicate,
            sort: sortOrder
        )
    }
    
    // Delete function needs to be updated to use inventoryItems
    func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = inventoryItems[index]
            modelContext.delete(itemToDelete)
            print("Deleting item: \(itemToDelete.title)")
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
