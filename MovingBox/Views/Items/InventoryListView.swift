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
    @State private var showItemCreationFlow = false
    @State private var showingImageAnalysis = false
    @State private var showingFilteringSheet = false
    @State private var analyzingImage: UIImage?
    @State private var isContextValid = true
    
    // Selection state
    @State private var isSelectionMode = false
    @State private var selectedItemIDs: Set<PersistentIdentifier> = []
    @State private var isSearchPresented = false
    @State private var showingBatchAnalysis = false
    @State private var showingDeleteConfirmation = false
    
    
    @Query private var allItems: [InventoryItem]
    
    let location: InventoryLocation?
    
    // Computed property to get actual items from selected IDs
    private var selectedItems: [InventoryItem] {
        allItems.filter { selectedItemIDs.contains($0.persistentModelID) }
    }
    
    private var inventoryListContent: some View {
        // Create a unique view based on sort order to force recreation when sort changes
        // This is necessary because @Query can't dynamically update its sort descriptor
        switch sortOrder.first?.order {
        case .reverse:
            InventoryListSubView(
                location: location, 
                searchString: searchText, 
                sortOrder: sortOrder,
                isSelectionMode: isSelectionMode,
                selectedItemIDs: $selectedItemIDs
            )
            .id("reverse-\(sortOrder.hashValue)")
        default:
            InventoryListSubView(
                location: location, 
                searchString: searchText, 
                sortOrder: sortOrder,
                isSelectionMode: isSelectionMode,
                selectedItemIDs: $selectedItemIDs
            )
            .id("forward-\(sortOrder.hashValue)")
        }
    }
    
    var body: some View {
        inventoryListContent
            .navigationTitle(location?.name ?? "All Items")
            .navigationDestination(for: InventoryItem.self) { inventoryItem in
                InventoryDetailView(inventoryItemToDisplay: inventoryItem, navigationPath: $path, showSparklesButton: true)
            }
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, isPresented: $isSearchPresented)
            .toolbar(content: toolbarContent)
            .toolbar(content: bottomToolbarContent)
            .sheet(isPresented: $showingPaywall, content: paywallSheet)
            .fullScreenCover(isPresented: $showingImageAnalysis, content: imageAnalysisSheet)
            .sheet(isPresented: $showingBatchAnalysis, content: batchAnalysisSheet)
            .sheet(isPresented: $showItemCreationFlow) {
                ItemCreationFlowView(location: location) {
                    // Optional callback when item creation is complete
                }
            }
            .alert("Delete Items", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive, action: deleteSelectedItems)
            } message: {
                Text("Are you sure you want to permanently delete \(selectedItemIDs.count) item\(selectedItemIDs.count == 1 ? "" : "s")? This action cannot be undone.")
            }
    }
    

    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        if isSelectionMode {
            // Select All Button
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: selectAllItems) {
                    Text("Select All")
                }
                .disabled(selectedItemIDs.count == allItems.count)
            }
            // Done with selection button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    isSelectionMode = false
                    selectedItemIDs.removeAll()
                }
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu("Options", systemImage: "ellipsis.circle") {
                    Button(action: createManualItem) {
                        Label("Add Manually", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("createManually")
                    Divider()
                    Button(action: {
                        isSelectionMode.toggle()
                        if isSelectionMode {
                            isSearchPresented = false
                        }
                    }) {
                        Label("Select Items", systemImage: "checkmark.circle")
                    }
                    
                    Divider()
                    Picker("Sort", selection: $sortOrder) {
                        Text("Title (A-Z)")
                            .tag([SortDescriptor(\InventoryItem.title)])
                        Text("Title (Z-A)")
                            .tag([SortDescriptor(\InventoryItem.title, order: .reverse)])
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {

                    


            }
        }
    }
    
    @ToolbarContentBuilder
    private func bottomToolbarContent() -> some ToolbarContent {
        if isSelectionMode {
            ToolbarItemGroup(placement: .bottomBar) {
                // MARK: - Toolbar item group
                // Share Sheet Button
                
                // Change Location Button
                
                // Change Label Button
                
                // Analyze with AI Button
                Button(action: analyzeSelectedItems) {
                    Label("Analyze Selected (\(selectedItemIDs.count))", systemImage: "sparkles")
                }
                .disabled(selectedItemIDs.isEmpty || !hasImagesInSelection())
            }
            
            if #available(iOS 26.0, *) {
                ToolbarSpacer(placement: .bottomBar)
            } else {
                // Fallback on earlier versions
            }

            ToolbarItem (placement: .bottomBar) {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete Selected (\(selectedItemIDs.count))", systemImage: "trash")
                }
                .disabled(selectedItemIDs.isEmpty)
            }
        } else {
            ToolbarItem(placement: .bottomBar) {
                Button(action: {
                    showingFilteringSheet = true
                }) {
                    Label("Filter", systemImage: "line.3.horizontal.decrease")
                }
            }
            
            // Search field here
            if #available(iOS 26.0, *) {
                ToolbarSpacer(placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(placement: .bottomBar)
            }
            

            // Add new item button
            ToolbarItem(placement: .bottomBar) {
                Button(action: createFromPhoto) {
                    Label("Add from Photo", systemImage: "plus")
                }
                .accessibilityIdentifier("createFromCamera")
            }
        }
    }
    
    @ViewBuilder
    private func paywallSheet() -> some View {
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
    
    @ViewBuilder
    private func imageAnalysisSheet() -> some View {
        if let image = analyzingImage {
            ImageAnalysisView(image: image) {
                showingImageAnalysis = false
                analyzingImage = nil
            }
        }
    }
    
    @ViewBuilder
    private func batchAnalysisSheet() -> some View {
        BatchAnalysisView(
            selectedItems: selectedItems,
            onDismiss: {
                showingBatchAnalysis = false
                isSelectionMode = false
                selectedItemIDs.removeAll()
            }
        )
    }
    
    private func createManualItem() {
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
    }
    
    private func createFromPhoto() {
        if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
            showingPaywall = true
        } else {
            showItemCreationFlow = true
        }
    }
    
    func handlePhotoCaptured(_ image: UIImage) {
        analyzingImage = image
        showingImageAnalysis = true
    }
    
    // MARK: - Selection Functions
    func selectAllItems() {
        selectedItemIDs = Set(allItems.map { $0.persistentModelID })
    }
    
    func deleteSelectedItems() {
        print("🗑️ DeleteSelectedItems called")
        print("🗑️ Selected item IDs: \(selectedItemIDs)")
        print("🗑️ All items count: \(allItems.count)")
        print("🗑️ Selected items count: \(selectedItems.count)")
        
        Task { @MainActor in
            let itemsToDelete = selectedItems
            print("🗑️ About to delete \(itemsToDelete.count) items:")
            
            for item in itemsToDelete {
                print("🗑️ Deleting item: \(item.title) (ID: \(item.persistentModelID))")
                modelContext.delete(item)
            }
            
            do {
                print("🗑️ Attempting to save context...")
                try modelContext.save()
                print("🗑️ Context saved successfully")
                
                // Small delay to allow SwiftData to update @Query
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Verify deletion worked by checking remaining count
                print("🗑️ Remaining items count after deletion: \(allItems.count)")
                
                // Exit selection mode after deletion
                selectedItemIDs.removeAll()
                isSelectionMode = false
                print("🗑️ Exited selection mode")
                
            } catch {
                print("🗑️ Error deleting items: \(error)")
                // Don't exit selection mode if delete failed
            }
        }
    }
    
    func moveSelectedItems(to location: InventoryLocation) {
        for item in selectedItems {
            item.location = location
        }
        try? modelContext.save()
        selectedItemIDs.removeAll()
    }
    
    func updateSelectedItemsLabel(to label: InventoryLabel?) {
        for item in selectedItems {
            item.label = label
        }
        try? modelContext.save()
        selectedItemIDs.removeAll()
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
    
    // MARK: - New Selection Functions
    func hasImagesInSelection() -> Bool {
        return selectedItems.contains { item in
            item.imageURL != nil || !item.secondaryPhotoURLs.isEmpty
        }
    }
    
    func analyzeSelectedItems() {
        showingBatchAnalysis = true
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
