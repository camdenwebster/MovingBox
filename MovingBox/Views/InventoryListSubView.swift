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
    
    // Make the Query property more explicit
    @Query private var inventoryItemsForSelectedLocation: [InventoryItem]
    
    let location: InventoryLocation
    let searchString: String
    
    var body: some View {
        List {
            Section {
                ForEach(inventoryItemsForSelectedLocation) { inventoryItem in
                    NavigationLink(value: inventoryItem) {
                        InventoryItemRow(item: inventoryItem)
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
    }
    
    init(location: InventoryLocation, searchString: String = "", sortOrder: [SortDescriptor<InventoryItem>] = [SortDescriptor(\InventoryItem.title)]) {
        self.location = location
        self.searchString = searchString
        
        let locationId = location.persistentModelID
        
        let predicate: Predicate<InventoryItem>
        
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
        
        _inventoryItemsForSelectedLocation = Query(
            filter: predicate,
            sort: sortOrder
        )
    }
    
    func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = inventoryItemsForSelectedLocation[index]
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
