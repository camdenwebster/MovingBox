//
//  InventoryListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import RevenueCatUI
import SwiftData
import SwiftUI

enum Options: Hashable {
    case destination(String)
}

struct InventoryListView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared
    
    @State private var path = NavigationPath()
    @State private var sortOrder = [SortDescriptor(\InventoryItem.title)]
    @State private var searchText = ""
    @State private var showingPaywall = false
    @State private var showingCamera = false
    @State private var showingImageAnalysis = false
    @State private var analyzingImage: UIImage?
    @State private var isContextValid = true
    
    // Selection state
    @State private var isSelectionMode = false
    @State private var selectedItems: Set<InventoryItem> = []
    
    @Query private var allItems: [InventoryItem]
    
    let location: InventoryLocation?
    
    var body: some View {
        InventoryListSubView(
            location: location, 
            searchString: searchText, 
            sortOrder: sortOrder,
            isSelectionMode: isSelectionMode,
            selectedItems: $selectedItems
        )
            .navigationTitle(location?.name ?? "All Items")
            .navigationDestination(for: InventoryItem.self) { inventoryItem in
                InventoryDetailView(inventoryItemToDisplay: inventoryItem, navigationPath: $path, showSparklesButton: true)
            }
            .toolbar {
                Menu("Options", systemImage: isSelectionMode ? "checkmark.circle" : "ellipsis.circle") {
                    Button(action: {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedItems.removeAll()
                        }
                    }) {
                        Label(isSelectionMode ? "Cancel Selection" : "Select Items", systemImage: isSelectionMode ? "xmark" : "checkmark.circle")
                    }
                    
                    if !isSelectionMode {
                        Divider()
                        Picker("Sort", selection: $sortOrder) {
                            Text("Title (A-Z)")
                                .tag([SortDescriptor(\InventoryItem.title)])
                            Text("Title (Z-A)")
                                .tag([SortDescriptor(\InventoryItem.title, order: .reverse)])
                        }
                    }
                }
                
                if !isSelectionMode {
                    Menu("Add Item", systemImage: "plus") {
                        Button(action: {
                            print("📱 InventoryListView - Add Item button tapped")
                            print("📱 InventoryListView - Settings.isPro: \(settings.isPro)")
                            print("📱 InventoryListView - Items count: \(allItems.count)")
                            print("📱 InventoryListView - Creating new item")
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
                            router.navigate(to: .inventoryDetailView(item: newItem, showSparklesButton: true, isEditing: true))
                        }) {
                            Label("Add Manually", systemImage: "square.and.pencil")
                        }
                        .accessibilityIdentifier("createManually")
                        
                        Button(action: {
                            if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
                                showingPaywall = true
                            } else {
                                router.navigate(to: .addInventoryItemView(location: location))
                            }
                        }) {
                            Label("Add from Photo", systemImage: "camera")
                        }
                        .accessibilityIdentifier("createFromCamera")
                    }
                    .accessibilityIdentifier("addItem")
                }
            }
            .searchable(text: $searchText, isPresented: .constant(!isSelectionMode))
            .toolbar {
                if isSelectionMode {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: selectAllItems) {
                            Text("Select All")
                        }
                        .disabled(selectedItems.count == allItems.count)
                        
                        Spacer()
                        
                        Button(action: deleteSelectedItems) {
                            Image(systemName: "trash")
                        }
                        .disabled(selectedItems.isEmpty)
                        
                        Spacer()
                        
                        Menu {
                            ForEach(getAllLocations(), id: \.self) { location in
                                Button(action: {
                                    moveSelectedItems(to: location)
                                }) {
                                    Text(location.name)
                                }
                            }
                        } label: {
                            Image(systemName: "folder")
                        }
                        .disabled(selectedItems.isEmpty)
                        
                        Spacer()
                        
                        Menu {
                            ForEach(getAllLabels(), id: \.self) { label in
                                Button(action: {
                                    updateSelectedItemsLabel(to: label)
                                }) {
                                    Text("\(label.emoji) \(label.name)")
                                }
                            }
                            Button(action: {
                                updateSelectedItemsLabel(to: nil)
                            }) {
                                Text("Remove Label")
                            }
                        } label: {
                            Image(systemName: "tag")
                        }
                        .disabled(selectedItems.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                revenueCatManager.presentPaywall(
                    isPresented: $showingPaywall,
                    onCompletion: {
                        settings.isPro = true
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
                        router.navigate(to: .inventoryDetailView(item: newItem, showSparklesButton: true, isEditing: true))
                    },
                    onDismiss: nil
                )
            }
            .fullScreenCover(isPresented: $showingImageAnalysis) {
                if let image = analyzingImage {
                    ImageAnalysisView(image: image) {
                        showingImageAnalysis = false
                        analyzingImage = nil
                    }
                }
            }
    }
    

    
    func handlePhotoCaptured(_ image: UIImage) {
        analyzingImage = image
        showingImageAnalysis = true
    }
    
    // MARK: - Selection Functions
    func selectAllItems() {
        selectedItems = Set(allItems)
    }
    
    func deleteSelectedItems() {
        for item in selectedItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
        selectedItems.removeAll()
    }
    
    func moveSelectedItems(to location: InventoryLocation) {
        for item in selectedItems {
            item.location = location
        }
        try? modelContext.save()
        selectedItems.removeAll()
    }
    
    func updateSelectedItemsLabel(to label: InventoryLabel?) {
        for item in selectedItems {
            item.label = label
        }
        try? modelContext.save()
        selectedItems.removeAll()
    }
    
    func getAllLocations() -> [InventoryLocation] {
        do {
            let descriptor = FetchDescriptor<InventoryLocation>(sortBy: [SortDescriptor(\InventoryLocation.name)])
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching locations: \(error)")
            return []
        }
    }
    
    func getAllLabels() -> [InventoryLabel] {
        do {
            let descriptor = FetchDescriptor<InventoryLabel>(sortBy: [SortDescriptor(\InventoryLabel.name)])
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching labels: \(error)")
            return []
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return InventoryListView(location: previewer.location)
            .modelContainer(previewer.container)
            .environmentObject(Router())
            .environmentObject(SettingsManager())
            .environmentObject(RevenueCatManager.shared)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
