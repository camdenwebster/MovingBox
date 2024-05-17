////
////  InventoryList.swift
////  FirebaseCRUD-CamdenW
////
////  Created by Camden Webster on 4/9/24.
////
//
//import SwiftUI
//
//
//struct InventoryList: View {
//    @EnvironmentObject var inventoryData: DataManager
//    @State private var isSpinning = false
//    @State private var isPresentingAlert = false
//    @State private var titleInput: String = ""
//    @State private var inventoryItem: InventoryItem?
//    @State private var newItemTitle: String?
//    
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach($inventoryData.inventoryItems) { $inventoryItem in
//                    NavigationLink(destination: InventoryDetail(inventoryItemToDisplay: inventoryItem)) {
//                        Text(inventoryItem.title)
//                    }
//                }
//                .onDelete(perform: deleteItem)
//            }
//            .navigationTitle("Home Inventory")
//            .toolbar {
//                ToolbarItem {
//                    Button(action: {
//                        withAnimation(Animation.linear(duration: 1)) {
//                            inventoryData.fetchInventoryItems()
//                            isSpinning.toggle()
//
//                            print("Found \(inventoryData.inventoryItems.count) items in inventoryItems after sync")
//                            
//                        }
//                    }) {
//                        Image(systemName: "arrow.triangle.2.circlepath.circle")
//                            .rotationEffect(.degrees(isSpinning ? 360 : 0))
//                    }
//                }
//                ToolbarItem {
//                    Button(action: {
//                        isPresentingAlert.toggle()
//                    }) {
//                        Label("Add Item", systemImage: "plus")
//                    }
//                }
//            }
//        }
//        .alert("Add a new item", isPresented: $isPresentingAlert) {
//            TextField("Title", text: $titleInput)
//                .textInputAutocapitalization(.never)
//            Button("OK") {
//                Task {
//                    createNewItem()
//                }
//            }
//            Button("Cancel", role: .cancel) { }
//        } message: {
//            Text("Item Title")
//        }
//    }
//        
//    func createNewItem() {
//        let id = UUID().uuidString
//        let newInventoryItem = InventoryItem(id: id, title: titleInput, location: "None")
//        inventoryData.addInventoryItem(newInventoryItem)
//        print("New item created with title \(newInventoryItem.title)")
//        print("Found \(inventoryData.inventoryItems.count) items in inventoryItems array")
//        }
//    
//    func deleteItem(at offsets: IndexSet) {
//        for index in offsets {
//            let itemToDelete = inventoryData.inventoryItems[index]
//            inventoryData.deleteInventoryItem(itemToDelete)
//            print("Deleting item id: \(itemToDelete.id), title: \(itemToDelete.title)")
//        }
//        inventoryData.inventoryItems.remove(atOffsets: offsets)
//    }
//}
//
//
//#Preview {
//    InventoryList()
//        .environmentObject(DataManager())
//}
