//
//  InventoryListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftData
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
    let location: InventoryLocation?
    
    var body: some View {
        InventoryListSubView(location: location, searchString: searchText, sortOrder: sortOrder)
            .navigationTitle(location?.name ?? "All Items")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: InventoryItem.self) { inventoryItem in
                EditInventoryItemView(inventoryItemToDisplay: inventoryItem, navigationPath: $path, showSparklesButton: true)
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
                Menu("Add Item", systemImage: "plus") {
                      Button(action: {
                          let newItem = InventoryItem(
                              title: "",
                              quantityString: "1",
                              quantityInt: 1,
                              desc: "",
                              serial: "",
                              model: "",
                              make: "",
                              location: location,
                              label: nil,
                              price: Decimal.zero,
                              insured: false,
                              assetId: "",
                              notes: "",
                              showInvalidQuantityAlert: false
                          )
                          router.navigate(to: .editInventoryItemView(item: newItem, showSparklesButton: true, isEditing: true))
                      }) {
                          Label("Add Manually", systemImage: "square.and.pencil")
                      }
                      
                      Button(action: {
                          router.navigate(to: .addInventoryItemView(location: location))
                      }) {
                          Label("Add from Photo", systemImage: "camera")
                      }
                  }
            }
            .searchable(text: $searchText)
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return InventoryListView(location: previewer.location)
            .modelContainer(previewer.container)
            .environmentObject(Router())
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
