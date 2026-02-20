//
//  InventoryListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import AVFoundation
import Dependencies
import RevenueCatUI
import SQLiteData
import SentrySwiftUI
import SwiftUI
import SwiftUIBackports
import TipKit

enum Options: Hashable {
    case destination(String)
}

private struct VideoAnalysisSelection: Identifiable {
    let id = UUID()
    let url: URL
    let preloadedAsset: AVAsset
}

private enum VideoAnalysisLaunchError: LocalizedError {
    case noVideoTrack

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "No video track found. Please select a valid video."
        }
    }
}

struct InventoryListView: View {
    @Dependency(\.defaultDatabase) var database
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared

    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]

    @FetchAll(SQLiteInventoryItem.all, animation: .default)
    private var allItems: [SQLiteInventoryItem]

    @FetchAll(SQLiteInventoryLocation.order(by: \.name), animation: .default)
    private var allLocations: [SQLiteInventoryLocation]

    @FetchAll(SQLiteInventoryLabel.order(by: \.name), animation: .default)
    private var allLabels: [SQLiteInventoryLabel]

    @FetchAll(SQLiteInventoryItemLabel.all, animation: .default)
    private var allItemLabels: [SQLiteInventoryItemLabel]

    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var showingPaywall = false
    @State private var showItemCreationFlow = false
    @State private var showManualItemSheet = false
    @State private var manualItemID: UUID?
    @State private var showingImageAnalysis = false
    @State private var analyzingImage: UIImage?

    // Sorting state
    enum SortField: Hashable {
        case title, date, value
    }
    @State private var currentSortField: SortField = .title
    @State private var titleAscending = true
    @State private var dateNewestFirst = true
    @State private var valueGreatestFirst = true

    // Selection state - using native SwiftUI selection
    @State private var editMode: EditMode = .inactive
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var isSearchPresented = false
    @State private var showingDeleteConfirmation = false
    @State private var showingVideoLibrary = false
    @State private var pendingVideoAnalysis: VideoAnalysisSelection?
    @State private var hasTrackedVideoLibraryTipVisit = false

    // State for batch operations
    @State private var showingLocationPicker = false
    @State private var showingLabelPicker = false
    @State private var showingLocationChangeConfirmation = false
    @State private var showingLabelChangeConfirmation = false
    @State private var selectedNewLocation: SQLiteInventoryLocation?
    @State private var selectedNewLabel: SQLiteInventoryLabel?
    @State private var exportCoordinator = ExportCoordinator()

    let locationID: UUID?
    let filterLabelID: UUID?
    let showOnlyUnassigned: Bool
    let showAllHomes: Bool

    private var activeHome: SQLiteHome? {
        guard let activeIdString = settings.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    init(
        locationID: UUID?,
        filterLabelID: UUID? = nil,
        showOnlyUnassigned: Bool = false,
        showAllHomes: Bool = false
    ) {
        self.locationID = locationID
        self.filterLabelID = filterLabelID
        self.showOnlyUnassigned = showOnlyUnassigned
        self.showAllHomes = showAllHomes
    }

    // Computed properties for selection state
    private var isSelectionMode: Bool {
        editMode == .active
    }

    private var selectedCount: Int {
        selectedItemIDs.count
    }

    // Derived sort values for InventoryListSubView
    private var sortAscending: Bool {
        switch currentSortField {
        case .title: return titleAscending
        case .date: return !dateNewestFirst
        case .value: return !valueGreatestFirst
        }
    }

    // Navigation title
    private var navigationTitle: String {
        if showOnlyUnassigned {
            return "No Location"
        }
        if let filterLabelID = filterLabelID {
            return allLabels.first { $0.id == filterLabelID }?.name ?? "All Items"
        }
        if let locationID = locationID {
            return allLocations.first { $0.id == locationID }?.name ?? "All Items"
        }
        return "All Items"
    }

    // Version-appropriate menu icon
    private var menuIcon: String {
        if #available(iOS 26.0, *) {
            return "ellipsis"
        } else {
            return "ellipsis.circle"
        }
    }

    // Locations filtered by active home
    private var locationsForActiveHome: [SQLiteInventoryLocation] {
        guard let activeHome = activeHome else { return allLocations }
        return allLocations.filter { $0.homeID == activeHome.id }
    }

    private var selectedLocation: SQLiteInventoryLocation? {
        guard let locationID else { return nil }
        return allLocations.first(where: { $0.id == locationID })
    }

    private var inventoryListContent: some View {
        InventoryListSubView(
            locationID: locationID,
            filterLabelID: filterLabelID,
            searchString: searchText,
            showOnlyUnassigned: showOnlyUnassigned,
            showAllHomes: showAllHomes,
            activeHomeID: activeHome?.id,
            sortField: currentSortField,
            sortAscending: sortAscending,
            selectedItemIDs: $selectedItemIDs
        )
    }

    var body: some View {
        inventoryListContent
            .environment(\.editMode, $editMode)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(isSelectionMode)
            .searchable(text: $searchText, isPresented: $isSearchPresented)
            .toolbar(content: toolbarContent)
            .toolbar(content: bottomToolbarContent)
            .sheet(isPresented: $showingPaywall, content: paywallSheet)
            .fullScreenCover(isPresented: $showingImageAnalysis, content: imageAnalysisSheet)
            .sheet(isPresented: $showingVideoLibrary) {
                VideoLibrarySheetView(
                    location: selectedLocation,
                    onAnalyzeVideo: { url in
                        try await startVideoAnalysis(for: url)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showItemCreationFlow) {
                EnhancedItemCreationFlowView(
                    captureMode: .singleItem,
                    locationID: locationID
                ) {
                    // Optional callback when item creation is complete
                }
                .tint(.green)
            }
            .fullScreenCover(item: $pendingVideoAnalysis) { selection in
                EnhancedItemCreationFlowView(
                    captureMode: .video,
                    locationID: locationID,
                    initialVideoURL: selection.url,
                    initialVideoAsset: selection.preloadedAsset
                ) {
                    pendingVideoAnalysis = nil
                }
                .tint(.green)
            }
            .sheet(
                isPresented: $showManualItemSheet,
                onDismiss: {
                    manualItemID = nil
                }
            ) {
                if let itemID = manualItemID {
                    NavigationStack {
                        InventoryDetailView(
                            itemID: itemID,
                            navigationPath: .constant(NavigationPath()),
                            showSparklesButton: true,
                            isEditing: true,
                            onSave: { showManualItemSheet = false },
                            onCancel: { showManualItemSheet = false }
                        )
                    }
                }
            }
            .alert("Delete Items", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: deleteSelectedItems)
                    .accessibilityIdentifier("alertDelete")
            } message: {
                Text(
                    "Are you sure you want to permanently delete \(selectedCount) item\(selectedCount == 1 ? "" : "s")? This action cannot be undone."
                )
            }
            .sheet(isPresented: $showingLocationPicker) {
                locationPickerSheet()
            }
            .sheet(isPresented: $showingLabelPicker) {
                labelPickerSheet()
            }
            .sheet(
                isPresented: $exportCoordinator.showShareSheet,
                onDismiss: {
                    exportCoordinator.showExportProgress = false
                    exportCoordinator.archiveURL = nil
                }
            ) {
                if let url = exportCoordinator.archiveURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Change Location", isPresented: $showingLocationChangeConfirmation) {
                Button("Cancel", role: .cancel) {
                    selectedNewLocation = nil
                }
                Button("Change") {
                    if let newLocation = selectedNewLocation {
                        changeSelectedItemsLocation(to: newLocation.id)
                    }
                    selectedNewLocation = nil
                }
            } message: {
                let locationName = selectedNewLocation?.name ?? "Unknown Location"
                Text(
                    "Are you sure you want to move \(selectedCount) item\(selectedCount == 1 ? "" : "s") to \(locationName)?"
                )
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
                Text(
                    "Are you sure you want to set the label for \(selectedCount) item\(selectedCount == 1 ? "" : "s") to \(labelName)?"
                )
            }
            .sheet(isPresented: $exportCoordinator.showExportProgress) {
                ExportProgressView(
                    phase: exportCoordinator.exportPhase,
                    progress: exportCoordinator.exportProgress,
                    onCancel: { exportCoordinator.cancelExport() }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .alert("Export Error", isPresented: $exportCoordinator.showExportError) {
                Button("OK") {
                    exportCoordinator.exportError = nil
                }
            } message: {
                Text(exportCoordinator.exportError?.localizedDescription ?? "An error occurred while exporting items.")
            }
            .onAppear {
                if filterLabelID == nil {
                    trackVideoLibraryTipVisitIfNeeded()
                }
            }
            .onDisappear {
                hasTrackedVideoLibraryTipVisit = false
            }
            .sentryTrace("InventoryListView")
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
            if filterLabelID == nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    videoToolbarButton
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu("Options", systemImage: menuIcon) {
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
                    Button {
                        sortByTitle()
                    } label: {
                        if currentSortField == .title {
                            Label("Title", systemImage: "checkmark")
                        } else {
                            Text("Title")
                        }
                        Text(titleAscending ? "Ascending" : "Descending")
                    }

                    Button {
                        sortByDate()
                    } label: {
                        if currentSortField == .date {
                            Label("Date", systemImage: "checkmark")
                        } else {
                            Text("Date")
                        }
                        Text(dateNewestFirst ? "Newest First" : "Oldest First")
                    }

                    Button {
                        sortByValue()
                    } label: {
                        if currentSortField == .value {
                            Label("Value", systemImage: "checkmark")
                        } else {
                            Text("Value")
                        }
                        Text(valueGreatestFirst ? "Highest First" : "Lowest First")
                    }
                }
                .accessibilityIdentifier("toolbarMenu")
            }
        }
    }

    @ViewBuilder
    private var videoToolbarButton: some View {
        if #available(iOS 17.0, *) {
            Button {
                openVideoLibrary()
            } label: {
                Image(systemName: "video")
            }
            .popoverTip(InventoryVideoLibraryTip(), arrowEdge: .top)
            .accessibilityIdentifier("inventoryVideoLibraryButton")
        } else {
            Button {
                openVideoLibrary()
            } label: {
                Image(systemName: "video")
            }
            .accessibilityIdentifier("inventoryVideoLibraryButton")
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
                .disabled(selectedCount == 0 || exportCoordinator.isExporting)

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
            }

            if #available(iOS 26.0, *) {
                ToolbarSpacer(placement: .bottomBar)
            } else {
                // For iOS < 26, add spacer to push delete button to trailing edge
                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete Selected (\(selectedCount))", systemImage: "trash")
                }
                .disabled(selectedCount == 0)
                .accessibilityIdentifier("deleteSelected")
            }
        } else {

            // Search field and spacers
            if #available(iOS 26.0, *) {
                ToolbarSpacer(placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
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
                createManualItem()
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
    private func locationPickerSheet() -> some View {
        PickerSheet.locationPicker(
            locations: locationsForActiveHome,
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
            labels: allLabels,
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

    private func createManualItem() {
        let newID = UUID()
        do {
            try database.write { db in
                try SQLiteInventoryItem.insert {
                    SQLiteInventoryItem(
                        id: newID,
                        locationID: locationID,
                        homeID: activeHome?.id
                    )
                }.execute(db)
            }
            manualItemID = newID
            showManualItemSheet = true
        } catch {
            print("Failed to create new item: \(error)")
        }
    }

    private func createFromPhoto() {
        print("📱 InventoryListView - Add from Photo button tapped")
        if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI }).count) {
            showingPaywall = true
        } else {
            print("📱 Launching Camera")
            showItemCreationFlow = true
        }
    }

    private func openVideoLibrary() {
        if #available(iOS 17.0, *) {
            InventoryVideoLibraryTip.hasOpenedVideoLibrary = true
        }
        showingVideoLibrary = true
    }

    private func startVideoAnalysis(for url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else {
            throw VideoAnalysisLaunchError.noVideoTrack
        }

        showingVideoLibrary = false
        try await Task.sleep(for: .milliseconds(150))
        pendingVideoAnalysis = VideoAnalysisSelection(url: url, preloadedAsset: asset)
    }

    private func trackVideoLibraryTipVisitIfNeeded() {
        guard !hasTrackedVideoLibraryTipVisit else { return }
        hasTrackedVideoLibraryTipVisit = true
        if #available(iOS 17.0, *) {
            InventoryVideoLibraryTip.inventoryListVisitCount += 1
        }
    }

    func handlePhotoCaptured(_ image: UIImage) {
        analyzingImage = image
        showingImageAnalysis = true
    }

    // MARK: - Selection Functions
    func selectAllItems() {
        selectedItemIDs = Set(allItems.map { $0.id })
    }

    func selectNoItems() {
        selectedItemIDs.removeAll()
    }

    func deleteSelectedItems() {
        guard !selectedItemIDs.isEmpty else { return }
        do {
            try database.write { db in
                for itemID in selectedItemIDs {
                    try SQLiteInventoryItem.find(itemID).delete().execute(db)
                }
            }
            selectedItemIDs.removeAll()
            editMode = .inactive
        } catch {
            print("Failed to delete items: \(error)")
        }
    }

    func changeSelectedItemsLocation(to locationID: UUID?) {
        guard !selectedItemIDs.isEmpty else { return }
        do {
            try database.write { db in
                for itemID in selectedItemIDs {
                    try SQLiteInventoryItem.find(itemID)
                        .update { $0.locationID = locationID }
                        .execute(db)
                }
            }
            selectedItemIDs.removeAll()
            editMode = .inactive
        } catch {
            print("Failed to change location: \(error)")
        }
    }

    func changeSelectedItemsLabel(to label: SQLiteInventoryLabel?) {
        guard !selectedItemIDs.isEmpty else { return }
        do {
            try database.write { db in
                for itemID in selectedItemIDs {
                    // Remove existing label associations for this item
                    try SQLiteInventoryItemLabel
                        .where { $0.inventoryItemID == itemID }
                        .delete()
                        .execute(db)

                    // Add new label if provided
                    if let label = label {
                        try SQLiteInventoryItemLabel.insert {
                            SQLiteInventoryItemLabel(
                                id: UUID(),
                                inventoryItemID: itemID,
                                inventoryLabelID: label.id
                            )
                        }.execute(db)
                    }

                    try SQLiteInventoryItem.find(itemID)
                        .update {
                            $0.labelIDs = label.map { [$0.id] } ?? []
                        }
                        .execute(db)
                }
            }
            selectedItemIDs.removeAll()
            editMode = .inactive
        } catch {
            print("Failed to change labels: \(error)")
        }
    }

    func exportSelectedItems() {
        guard !selectedItemIDs.isEmpty else { return }
        let selectedItems = allItems.filter { selectedItemIDs.contains($0.id) }
        guard !selectedItems.isEmpty else { return }
        Task {
            await exportCoordinator.exportSpecificItems(
                items: selectedItems,
                database: database
            )
        }
    }

    // MARK: - Sorting Functions
    private func sortByTitle() {
        if currentSortField == .title {
            titleAscending.toggle()
        } else {
            currentSortField = .title
            titleAscending = true
        }
    }

    private func sortByDate() {
        if currentSortField == .date {
            dateNewestFirst.toggle()
        } else {
            currentSortField = .date
            dateNewestFirst = true
        }
    }

    private func sortByValue() {
        if currentSortField == .value {
            valueGreatestFirst.toggle()
        } else {
            currentSortField = .value
            valueGreatestFirst = true
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    InventoryListView(locationID: nil)
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
