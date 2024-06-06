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
    @Query var inventoryItemsForSelectedLocation: [InventoryItem]
    
//    let location: InventoryLocation

    
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
    
    init(locationId: String = "", searchString: String = "", sortOrder: [SortDescriptor<InventoryItem>] = []) {
        _inventoryItemsForSelectedLocation = Query(filter: #Predicate { inventoryItemsForSelectedLocation in
            (inventoryItemsForSelectedLocation.location?.id == locationId) &&
                        (searchString.isEmpty || inventoryItemsForSelectedLocation.title.localizedStandardContains(searchString) ||
                         inventoryItemsForSelectedLocation.desc.localizedStandardContains(searchString) ||
                         inventoryItemsForSelectedLocation.notes.localizedStandardContains(searchString) ||
                         inventoryItemsForSelectedLocation.make.localizedStandardContains(searchString) ||
                         inventoryItemsForSelectedLocation.model.localizedStandardContains(searchString) ||
                         inventoryItemsForSelectedLocation.serial.localizedStandardContains(searchString))
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




//#Preview {
//    let location = InventoryLocation(id: UUID().uuidString, name: "Attic", desc: "")
//    InventoryListSubView(location: location)
//}
