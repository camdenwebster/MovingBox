//
//  InventoryListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftUIBackports
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
    
    // Selection state - using native SwiftUI selection
    @State private var editMode: EditMode = .inactive
    @State private var selectedItemIDs: Set<PersistentIdentifier> = []
    @State private var isSearchPresented = false
    @State private var showingBatchAnalysis = false
    @State private var showingDeleteConfirmation = false
    
    // State for new toolbar functionality
    @State private var showingExportShare = false
    @State private var showingLocationPicker = false
    @State private var showingLabelPicker = false
    @State private var showingLocationChangeConfirmation = false
    @State private var showingLabelChangeConfirmation = false
    @State private var selectedNewLocation: InventoryLocation?
    @State private var selectedNewLabel: InventoryLabel?
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var showingExportProgress = false
    @State private var exportError: Error?
    @State private var showingExportError = false
    
    @Query private var allItems: [InventoryItem]
    
    let location: InventoryLocation?
    
    // Computed properties for selection state
    private var isSelectionMode: Bool {
        editMode == .active
    }
    
    // Cache for selected items to avoid repeated expensive filtering
    @State private var cachedSelectedItems: [InventoryItem] = []
    @State private var cachedSelectionIDs: Set<PersistentIdentifier> = []
    
    // Optimized: Use cached selected items with lazy computation
    private var selectedItems: [InventoryItem] {
        guard !selectedItemIDs.isEmpty else { 
            if !cachedSelectedItems.isEmpty {
                cachedSelectedItems = []
                cachedSelectionIDs = []
            }
            return [] 
        }
        
        // Only recompute if selection changed
        if cachedSelectionIDs != selectedItemIDs {
            cachedSelectedItems = allItems.filter { selectedItemIDs.contains($0.persistentModelID) }
            cachedSelectionIDs = selectedItemIDs
        }
        
        return cachedSelectedItems
    }
    
    // Memoized count for toolbar performance
    private var selectedCount: Int {
        selectedItemIDs.count
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
                selectedItemIDs: $selectedItemIDs
            )
            .id("reverse-\(sortOrder.hashValue)")
        default:
            InventoryListSubView(
                location: location, 
                searchString: searchText, 
                sortOrder: sortOrder,
                selectedItemIDs: $selectedItemIDs
            )
            .id("forward-\(sortOrder.hashValue)")
        }
    }
    
    var body: some View {
        inventoryListContent
            .environment(\.editMode, $editMode)
            .navigationTitle(location?.name ?? "All Items")
            .navigationDestination(for: InventoryItem.self) { inventoryItem in
                InventoryDetailView(inventoryItemToDisplay: inventoryItem, navigationPath: $path, showSparklesButton: true)
            }
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(isSelectionMode)
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
                Text("Are you sure you want to permanently delete \(selectedCount) item\(selectedCount == 1 ? "" : "s")? This action cannot be undone.")
            }
            .sheet(isPresented: $showingLocationPicker) {
                locationPickerSheet()
            }
            .sheet(isPresented: $showingLabelPicker) {
                labelPickerSheet()
            }
            .sheet(isPresented: $showingExportShare, onDismiss: {
                // When share sheet is dismissed, also dismiss the progress sheet and clean up
                showingExportProgress = false
                exportURL = nil
            }) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Change Location", isPresented: $showingLocationChangeConfirmation) {
                Button("Cancel", role: .cancel) {
                    selectedNewLocation = nil
                }
                Button("Change") {
                    if let newLocation = selectedNewLocation {
                        changeSelectedItemsLocation(to: newLocation)
                    }
                    selectedNewLocation = nil
                }
            } message: {
                let locationName = selectedNewLocation?.name ?? "Unknown Location"
                Text("Are you sure you want to move \(selectedCount) item\(selectedCount == 1 ? "" : "s") to \(locationName)?")
            }
            .alert("Change Label", isPresented: $showingLabelChangeConfirmation) {
                Button("Cancel", role: .cancel) {
                    selectedNewLabel = nil
                }
                Button("Change") {
                    changeSelectedItemsLabel(to: selectedNewLabel)
                    selectedNewLabel = nil
                }
            } message: {
                let labelName = selectedNewLabel?.name ?? "No Label"
                Text("Are you sure you want to set the label for \(selectedCount) item\(selectedCount == 1 ? "" : "s") to \(labelName)?")
            }
            .sheet(isPresented: $showingExportProgress) {
                exportProgressSheet()
            }
            .alert("Export Error", isPresented: $showingExportError) {
                Button("OK") {
                    exportError = nil
                }
            } message: {
                Text(exportError?.localizedDescription ?? "An error occurred while exporting items.")
            }
    }
    

    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {

        
        if isSelectionMode {
            // Select All/None Button
            ToolbarItem(placement: .navigationBarLeading) {
                if selectedCount > 0 {
                    Button(action: selectNoItems) {
                        Text("Select None")
                    }
                } else {
                    Button(action: selectAllItems) {
                        Text("Select All")
                    }
                    .disabled(allItems.isEmpty)
                }
            }
            // Edit button (native SwiftUI)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    editMode = .inactive
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
                        editMode = .active
                        isSearchPresented = false
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
                .accessibilityIdentifier("toolbarMenu")
            }
        }
    }
    
    @ToolbarContentBuilder
    private func bottomToolbarContent() -> some ToolbarContent {
        if isSelectionMode {
            ToolbarItemGroup(placement: .bottomBar) {
                // MARK: - Toolbar item group
                // Share Sheet Button
                Button(action: exportSelectedItems) {
                    Label("Export Selected (\(selectedCount))", systemImage: "square.and.arrow.up")
                }
                .disabled(selectedCount == 0 || isExporting)
                
                // Change Location Button
                Button(action: {
                    showingLocationPicker = true
                }) {
                    Label("Move (\(selectedCount))", systemImage: "folder")
                }
                .disabled(selectedCount == 0)
                
                // Change Label Button
                Button(action: {
                    showingLabelPicker = true
                }) {
                    Label("Label (\(selectedCount))", systemImage: "tag")
                }
                .disabled(selectedCount == 0)
                
                // TODO: Fix the Batch Analysis flow
                // Analyze with AI Button
//                Button(action: analyzeSelectedItems) {
//                    Label("Analyze (\(selectedCount))", systemImage: "sparkles")
//                }
//                .disabled(selectedCount == 0 || !hasImagesInSelection())
            }
            
            if #available(iOS 26.0, *) {
                ToolbarSpacer(placement: .bottomBar)
            } else {
                // For iOS < 26, add spacer to push delete button to trailing edge
                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }
            }
            
            ToolbarItem (placement: .bottomBar) {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete Selected (\(selectedCount))", systemImage: "trash")
                }
                .disabled(selectedCount == 0)
            }
        } else {
            ToolbarItem(placement: .bottomBar) {
                Button(action: {
                    showingFilteringSheet = true
                }) {
                    Label("Filter", systemImage: "line.3.horizontal.decrease")
                }
            }
            
            // Search field and spacers
            if #available(iOS 26.0, *) {
                ToolbarSpacer(placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(placement: .bottomBar)
            } else {
                // For iOS < 26, add spacer to push + button to trailing edge
                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }
            }

            // Add new item button
            ToolbarItem(placement: .bottomBar) {
                Button(action: createFromPhoto) {
                    Label("Add from Photo", systemImage: "plus")
                }
                .accessibilityIdentifier("createFromCamera")
                .buttonStyle(.borderedProminent)
                .tint(Color.customPrimary)
                .backport.glassEffect(in: Circle())
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
                editMode = .inactive
                selectedItemIDs.removeAll()
            }
        )
    }
    
    @ViewBuilder
    private func locationPickerSheet() -> some View {
        PickerSheet.locationPicker(
            locations: getAllLocations(),
            onSelect: { location in
                selectedNewLocation = location
                showingLocationPicker = false
                showingLocationChangeConfirmation = true
            },
            onCancel: {
                showingLocationPicker = false
            }
        )
    }
    
    @ViewBuilder
    private func labelPickerSheet() -> some View {
        PickerSheet.labelPicker(
            labels: getAllLabels(),
            onSelect: { label in
                selectedNewLabel = label
                showingLabelPicker = false
                showingLabelChangeConfirmation = true
            },
            onCancel: {
                showingLabelPicker = false
            }
        )
    }
    
    @ViewBuilder
    private func exportProgressSheet() -> some View {
        NavigationView {
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.5)
                
                VStack(spacing: 8) {
                    Text("Exporting Items")
                        .font(.headline)
                    Text("Please wait while we prepare your export...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }
    
    private func createManualItem() {
       print("📱 InventoryListView - Add Manual Item button tapped")
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
        print("📱 InventoryListView - Add Manual Item button tapped")
        print("📱 InventoryListView - Settings.isPro: \(settings.isPro)")
        print("📱 InventoryListView - Items count: \(allItems.count)")
        if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
            showingPaywall = true
        } else {
            print("📱 Launching Camera")
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
    
    func selectNoItems() {
        selectedItemIDs.removeAll()
    }
    
    func deleteSelectedItems() {
        Task { @MainActor in
            let itemsToDelete = selectedItems
            
            for item in itemsToDelete {
                modelContext.delete(item)
            }
            
            do {
                try modelContext.save()
                
                // Small delay to allow SwiftData to update @Query
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Exit selection mode after deletion
                selectedItemIDs.removeAll()
                editMode = .inactive
                
            } catch {
                // Don't exit selection mode if delete failed
                // Error will be handled by SwiftData's built-in error handling
            }
        }
    }
    
    func moveSelectedItems(to location: InventoryLocation) {
        for item in selectedItems {
            item.location = location
        }
        try? modelContext.save()
        selectedItemIDs.removeAll()
        editMode = .inactive
    }
    
    func updateSelectedItemsLabel(to label: InventoryLabel?) {
        for item in selectedItems {
            item.label = label
        }
        try? modelContext.save()
        selectedItemIDs.removeAll()
        editMode = .inactive
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
        guard !selectedItemIDs.isEmpty else { return false }
        return allItems.contains { item in
            guard selectedItemIDs.contains(item.persistentModelID) else { return false }
            return hasAnalyzableImage(item)
        }
    }
    
    private func hasAnalyzableImage(_ item: InventoryItem) -> Bool {
        // Check primary image URL
        if let imageURL = item.imageURL, !imageURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        
        // Check secondary photo URLs (filter out empty strings)
        if !item.secondaryPhotoURLs.isEmpty {
            let validURLs = item.secondaryPhotoURLs.filter { url in
                !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !validURLs.isEmpty {
                return true
            }
        }
        
        // Check legacy data property (for items that haven't migrated yet)
        if let data = item.data, !data.isEmpty {
            return true
        }
        
        return false
    }
    
    func analyzeSelectedItems() {
        showingBatchAnalysis = true
    }
    
    func exportSelectedItems() {
        guard !selectedItems.isEmpty else { return }
        
        Task { @MainActor in
            do {
                showingExportProgress = true
                isExporting = true
                
                // Create a custom DataManager method for exporting specific items
                let url = try await DataManager.shared.exportSpecificItems(
                    items: selectedItems,
                    modelContext: modelContext
                )
                
                exportURL = url
                showingExportShare = true
                
            } catch {
                showingExportProgress = false
                exportError = error
                showingExportError = true
            }
            
            isExporting = false
        }
    }
    
    func changeSelectedItemsLocation(to location: InventoryLocation) {
        for item in selectedItems {
            item.location = location
        }
        try? modelContext.save()
        selectedItemIDs.removeAll()
        editMode = .inactive
    }
    
    func changeSelectedItemsLabel(to label: InventoryLabel?) {
        for item in selectedItems {
            item.label = label
        }
        try? modelContext.save()
        selectedItemIDs.removeAll()
        editMode = .inactive
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

