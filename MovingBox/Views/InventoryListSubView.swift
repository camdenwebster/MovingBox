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
    
    init(location: InventoryLocation, searchString: String = "", sortOrder: [SortDescriptor<InventoryItem>] = []) {
        _inventoryItemsForSelectedLocation = Query(filter: #Predicate { inventoryItem in
            (inventoryItem.location == location) &&
            (searchString.isEmpty || inventoryItem.title.localizedStandardContains(searchString) ||
             inventoryItem.desc.localizedStandardContains(searchString) ||
             inventoryItem.notes.localizedStandardContains(searchString) ||
             inventoryItem.make.localizedStandardContains(searchString) ||
             inventoryItem.model.localizedStandardContains(searchString) ||
             inventoryItem.serial.localizedStandardContains(searchString))
        }, sort: sortOrder)
    }
    
    func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let itemToDelete = inventoryItemsForSelectedLocation[index]
            modelContext.delete(itemToDelete)
            print("Deleting item: \(itemToDelete.title)")
        }
    }
}




//#Preview {
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: InventoryItem.self, configurations: config)
//
//    let location = InventoryLocation(name: "Living Room")
//    try! container.mainContext.insert(location)
//
//    let item = InventoryItem(title: "Test Item", quantityString: "1", quantityInt: 1, desc: "Test Description", serial: "", model: "", make: "", location: location, label: nil, price: "", insured: false, assetId: "", notes: "", showInvalidQuantityAlert: false)
//    try! container.mainContext.insert(item)
//
//    return InventoryListSubView(location: location)
//        .modelContainer(container)
//        .environmentObject(Router())
//}
