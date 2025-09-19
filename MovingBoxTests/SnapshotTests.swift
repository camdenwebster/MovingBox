//
//  SnapshotTests.swift
//  MovingBoxTests
//
//  Created by Camden Webster on 4/2/25.
//

import SnapshotTesting
import Testing
import SwiftUI
import SwiftData
@testable import MovingBox

@MainActor
final class SnapshotTests {
    var filePath: StaticString {
        let xcodeCloudPath: StaticString = "/Volumes/workspace/repository/ci_scripts/SnapshotTests.swift"
        if ProcessInfo.processInfo.environment["CI"] == "TRUE" {
            print("☁️ Using Xcode Cloud path for Snapshots")
            return xcodeCloudPath
        } else {
          return #file
        }
    }
    
    var precision: Float = 0.99
    
    // Helper property to check if mock data should be loaded
    private var shouldLoadMockData: Bool {
        return ProcessInfo.processInfo.arguments.contains("Mock-Data")
    }
    
    // Helper property to check if dark mode should be used
    private var isDarkMode: Bool {
        let darkMode = ProcessInfo.processInfo.arguments.contains("Dark-Mode")
        print("🎨 Running tests in \(darkMode ? "dark" : "light") mode")
        return darkMode
    }
    
    private var snapshotSuffix: String {
        var suffix = ""
        if shouldLoadMockData { suffix += "_mockData" }
        if isDarkMode { suffix += "_dark" }
        return suffix
    }
    
    private var testContainer: ModelContainer?
    
    private func cleanup() async {
        print("Cleaning up test resources...")
        guard let container = testContainer else { return }
        
        let context = container.mainContext
        
        do {
            print("Deleting items...")
            try context.delete(model: InventoryItem.self)
            
            print("Deleting locations...")
            try context.delete(model: InventoryLocation.self)
            
            print("Deleting labels...")
            try context.delete(model: InventoryLabel.self)
            
            print("Deleting homes...")
            try context.delete(model: Home.self)
            
            print("Deleting policies...")
            try context.delete(model: InsurancePolicy.self)
            
            try context.save()
            print("Test data cleared successfully")
        } catch {
            print("Error during cleanup: \(error)")
        }
        
        testContainer = nil
    }
    
    private func createTestContainer() async throws -> ModelContainer {
        await cleanup()
        
        print("Creating test container...")
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Home.self, InventoryLabel.self, InventoryItem.self, InventoryLocation.self, InsurancePolicy.self, configurations: config)
        
        print("Container created successfully")
        testContainer = container
        
        if shouldLoadMockData {
            print("Populating test data...")
            await DefaultDataManager.populateTestData(modelContext: container.mainContext)
            try container.mainContext.save()
            print("Test data populated and saved")
            
            // Verify data was loaded
            let itemCount = try container.mainContext.fetch(FetchDescriptor<InventoryItem>()).count
            let locationCount = try container.mainContext.fetch(FetchDescriptor<InventoryLocation>()).count
            let labelCount = try container.mainContext.fetch(FetchDescriptor<InventoryLabel>()).count
            print("Verification - Items: \(itemCount), Locations: \(locationCount), Labels: \(labelCount)")
        }
        
        return container
    }
    
    private func configureViewForSnapshot<T: View>(_ view: T) -> some View {
        view
            .frame(width: 390, height: 844)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .background(Color(.systemBackground))
            .environment(\.colorScheme, isDarkMode ? .dark : .light)
            .environment(\.isSnapshotTesting, true)
            .environment(\.disableAnimations, true)
            .environmentObject(SettingsManager())
            .environmentObject(Router())
    }
}

// MARK: - Test Extensions
extension ModelContext {
    func delete<T: PersistentModel>(model: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try fetch(descriptor)
        items.forEach { delete($0) }
    }
}

// MARK: - Tests
extension SnapshotTests {
    @Test("Dashboard View Layout")
    func dashboardViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            DashboardView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "dashboard_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Inventory List View Layout")
    func inventoryListViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { location in
                location.name == "Kitchen"
            }
        )
        let locations = try container.mainContext.fetch(descriptor)
        let location = locations.first
        
        let view = configureViewForSnapshot(
            InventoryListView(location: location)
                .modelContainer(container)
        )
        
        for i in 1...4 {
            try await Task.sleep(for: .seconds(0.5))
            print("Wait iteration \(i) complete")
        }
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_list_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Locations List View Layout")
    func locationsListViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            LocationsListView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "locations_list_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Add Inventory Item View Layout")
    func addInventoryItemViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { location in
                location.name == "Kitchen"
            }
        )
        let locations = try container.mainContext.fetch(descriptor)
        let location = locations.first
        
        let view = configureViewForSnapshot(
            AddInventoryItemView(location: location)
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "add_inventory_item_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Edit Location View Layout - Edit Mode")
    func editLocationViewEditModeSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { location in
                location.name == "Kitchen"
            }
        )
        let locations = try container.mainContext.fetch(descriptor)
        let location = locations.first ?? InventoryLocation()
        
        let view = configureViewForSnapshot(
            EditLocationView(location: location)
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_location_view_edit\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Edit Label View Layout - Read Mode")
    func editLabelViewReadModeSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryLabel>(
            predicate: #Predicate<InventoryLabel> { label in
                label.name == "Electronics"
            }
        )
        let labels = try container.mainContext.fetch(descriptor)
        let label = labels.first ?? InventoryLabel()
        
        let view = configureViewForSnapshot(
            EditLabelView(label: label)
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_label_view_read\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Edit Label View Layout - Edit Mode")
    func editLabelViewEditModeSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryLabel>(
            predicate: #Predicate<InventoryLabel> { label in
                label.name == "Electronics"
            }
        )
        let labels = try container.mainContext.fetch(descriptor)
        let label = labels.first ?? InventoryLabel()
        
        let view = configureViewForSnapshot(
            EditLabelView(label: label)
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_label_view_edit\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Edit Home View Layout - Read Mode")
    func editHomeViewReadModeSnapshot() async throws {
        let container = try await createTestContainer()
        
        _ = FetchDescriptor<Home>()
        
        let view = configureViewForSnapshot(
            EditHomeView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_home_view_read\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Edit Home View Layout - Edit Mode")
    func editHomeViewEditModeSnapshot() async throws {
        let container = try await createTestContainer()
        
        _ = FetchDescriptor<Home>()
        
        let view = configureViewForSnapshot(
            EditHomeView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_home_view_edit\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Inventory Detail View - Read Mode")
    func inventoryDetailViewReadModeSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate<InventoryItem> { item in
                item.title == "MacBook Pro" && item.make == "Apple" && item.model == "MacBook Pro M2"
            }
        )
        let items = try container.mainContext.fetch(descriptor)
        let item = items.first ?? InventoryItem()
        
        let view = configureViewForSnapshot(
            InventoryDetailView(
                inventoryItemToDisplay: item,
                navigationPath: .constant(NavigationPath()),
                isEditing: false
            )
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_detail_view_read\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Inventory Detail View - Edit Mode")
    func inventoryDetailViewEditModeSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate<InventoryItem> { item in
                item.title == "MacBook Pro" && item.make == "Apple" && item.model == "MacBook Pro M2"
            }
        )
        let items = try container.mainContext.fetch(descriptor)
        let item = items.first ?? InventoryItem()
        
        let view = configureViewForSnapshot(
            InventoryDetailView(
                inventoryItemToDisplay: item,
                navigationPath: .constant(NavigationPath()),
                isEditing: true
            )
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_detail_view_edit\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Inventory Detail View - Multi-Photo Display")
    func inventoryDetailViewMultiPhotoSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryItem>(
            sortBy: [SortDescriptor(\.title)]
        )
        let items = try container.mainContext.fetch(descriptor)
        let item = items.first ?? InventoryItem()
        
        // Add mock secondary photos for testing
        item.secondaryPhotoURLs = [
            "file:///mock/path/secondary1.jpg",
            "file:///mock/path/secondary2.jpg",
            "file:///mock/path/secondary3.jpg"
        ]
        
        let view = configureViewForSnapshot(
            InventoryDetailView(
                inventoryItemToDisplay: item,
                navigationPath: .constant(NavigationPath()),
                isEditing: false
            )
                .modelContainer(container)
                .environmentObject(Router())
                .environmentObject(SettingsManager())
                .environmentObject(OnboardingManager())
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_detail_view_multi_photo\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Inventory Detail View - Multi-Photo Edit Mode")
    func inventoryDetailViewMultiPhotoEditSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryItem>(
            sortBy: [SortDescriptor(\.title)]
        )
        let items = try container.mainContext.fetch(descriptor)
        let item = items.first ?? InventoryItem()
        
        // Add mock secondary photos for testing
        item.secondaryPhotoURLs = [
            "file:///mock/path/secondary1.jpg",
            "file:///mock/path/secondary2.jpg"
        ]
        
        let view = configureViewForSnapshot(
            InventoryDetailView(
                inventoryItemToDisplay: item,
                navigationPath: .constant(NavigationPath()),
                isEditing: true
            )
                .modelContainer(container)
                .environmentObject(Router())
                .environmentObject(SettingsManager())
                .environmentObject(OnboardingManager())
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_detail_view_multi_photo_edit\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Settings View Layout")
    func settingsViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            SettingsView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "settings_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Onboarding Welcome View Layout")
    func onboardingWelcomeViewSnapshot() async throws {
        let container = try await createTestContainer()
        let manager = OnboardingManager()
        manager.currentStep = .welcome
        
        let view = configureViewForSnapshot(
            OnboardingWelcomeView()
                .modelContainer(container)
                .environmentObject(manager)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "onboarding_welcome_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Onboarding Home View Layout")
    func onboardingHomeViewSnapshot() async throws {
        let container = try await createTestContainer()
        let manager = OnboardingManager()
        manager.currentStep = .homeDetails
        
        let view = configureViewForSnapshot(
            OnboardingHomeView()
                .modelContainer(container)
                .environmentObject(manager)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "onboarding_home_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Onboarding Location View Layout")
    func onboardingLocationViewSnapshot() async throws {
        let container = try await createTestContainer()
        let manager = OnboardingManager()
        manager.currentStep = .location
        
        let view = configureViewForSnapshot(
            OnboardingLocationView()
                .modelContainer(container)
                .environmentObject(manager)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "onboarding_location_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Onboarding Item View Layout")
    func onboardingItemViewSnapshot() async throws {
        let container = try await createTestContainer()
        let manager = OnboardingManager()
        manager.currentStep = .item
        
        let view = configureViewForSnapshot(
            OnboardingItemView()
                .modelContainer(container)
                .environmentObject(manager)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "onboarding_item_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Onboarding Completion View Layout")
    func onboardingCompletionViewSnapshot() async throws {
        let container = try await createTestContainer()
        let manager = OnboardingManager()
        manager.currentStep = .completion
        
        let view = configureViewForSnapshot(
            OnboardingCompletionView(isPresented: .constant(true))
                .modelContainer(container)
                .environmentObject(manager)
        )
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "onboarding_completion_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Full Onboarding Flow Layout")
    func onboardingFlowViewSnapshot() async throws {
        let container = try await createTestContainer()
        let manager = OnboardingManager()
        
        let view = configureViewForSnapshot(
            OnboardingView(isPresented: .constant(true))
                .modelContainer(container)
                .environmentObject(manager)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "onboarding_flow_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    // MARK: - Dashboard Component Views
    
    @Test("Label Statistics View Layout - Empty State")
    func labelStatisticsViewEmptySnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            LabelStatisticsView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "label_statistics_view_empty\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Label Statistics View Layout - With Data")
    func labelStatisticsViewWithDataSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            LabelStatisticsView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "label_statistics_view_with_data\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Location Statistics View Layout - Empty State")
    func locationStatisticsViewEmptySnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            LocationStatisticsView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "location_statistics_view_empty\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Location Statistics View Layout - With Data")
    func locationStatisticsViewWithDataSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            LocationStatisticsView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "location_statistics_view_with_data\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    // MARK: - Inventory Views
    
    @Test("Inventory List Sub View Layout - Empty State")
    func inventoryListSubViewEmptySnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            InventoryListSubView(location: nil, searchString: "", sortOrder: [])
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_list_sub_view_empty\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Inventory List Sub View Layout - With Items")
    func inventoryListSubViewWithItemsSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { location in
                location.name == "Kitchen"
            }
        )
        let locations = try container.mainContext.fetch(descriptor)
        let location = locations.first
        
        let view = configureViewForSnapshot(
            InventoryListSubView(location: location, searchString: "", sortOrder: [])
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_list_sub_view_with_items\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Batch Analysis View Layout - Empty Selection")
    func batchAnalysisViewEmptySnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            BatchAnalysisView(selectedItems: [], onDismiss: {})
                .modelContainer(container)
                .environmentObject(SettingsManager())
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "batch_analysis_view_empty\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Batch Analysis View Layout - With Items")
    func batchAnalysisViewWithItemsSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryItem>(
            sortBy: [SortDescriptor(\.title)]
        )
        let items = try container.mainContext.fetch(descriptor)
        let selectedItems = Array(items.prefix(3))
        
        let view = configureViewForSnapshot(
            BatchAnalysisView(selectedItems: selectedItems, onDismiss: {})
                .modelContainer(container)
                .environmentObject(SettingsManager())
        )
        
        try await Task.sleep(for: .seconds(2))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "batch_analysis_view_with_items\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    // MARK: - Selection Views
    
    @Test("Label Selection View Layout")
    func labelSelectionViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let item = InventoryItem()
        item.title = "Test Item"
        
        let view = configureViewForSnapshot(
            LabelSelectionView(selectedItem: item)
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "label_selection_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Location Selection View Layout")
    func locationSelectionViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let item = InventoryItem()
        item.title = "Test Item"
        
        let view = configureViewForSnapshot(
            LocationSelectionView(selectedItem: item)
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "location_selection_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    // MARK: - Settings Views
    
    @Test("Import Export Settings View Layout")
    func importExportSettingsViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            ImportExportSettingsView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "import_export_settings_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Import Data View Layout")
    func importDataViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            ImportDataView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "import_data_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Export Data View Layout")
    func exportDataViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            ExportDataView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "export_data_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Subscription Settings View Layout")
    func subscriptionSettingsViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            SubscriptionSettingsView()
                .modelContainer(container)
                .environmentObject(RevenueCatManager())
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "subscription_settings_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Data Deletion View Layout")
    func dataDeletionViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            DataDeletionView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "data_deletion_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Sync Data Settings View Layout")
    func syncDataSettingsViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            SyncDataSettingsView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "sync_data_settings_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    // MARK: - Photo and Display Views
    
    @Test("Full Screen Photo View Layout")
    func fullScreenPhotoViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            FullScreenPhotoView(
                images: ["test_image_url"],
                initialIndex: 0,
                isPresented: .constant(true)
            )
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "full_screen_photo_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Horizontal Photo Scroll View Layout")
    func horizontalPhotoScrollViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let urls = ["test_image_1", "test_image_2", "test_image_3"]
        
        let view = configureViewForSnapshot(
            HorizontalPhotoScrollView(
                imageURLs: urls,
                maxHeight: 200,
                onImageTap: { _ in }
            )
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "horizontal_photo_scroll_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    // MARK: - Utility Views
    
    @Test("MovingBox Paywall View Layout")
    func movingBoxPaywallViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            MovingBoxPaywallView(isPresented: .constant(true))
                .modelContainer(container)
                .environmentObject(RevenueCatManager())
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "movingbox_paywall_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Splash View Layout")
    func splashViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            SplashView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "splash_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    // MARK: - Item Creation and Analysis Views
    
    @Test("Item Creation Flow View Layout - Camera Step")
    func itemCreationFlowViewCameraSnapshot() async throws {
        let container = try await createTestContainer()
        
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { location in
                location.name == "Kitchen"
            }
        )
        let locations = try container.mainContext.fetch(descriptor)
        let location = locations.first
        
        let view = configureViewForSnapshot(
            ItemCreationFlowView(location: location, onComplete: nil)
                .modelContainer(container)
                .environmentObject(SettingsManager())
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "item_creation_flow_view_camera\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Item Analysis Detail View Layout")
    func itemAnalysisDetailViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let item = InventoryItem()
        item.title = "Test Item"
        container.mainContext.insert(item)
        
        // Create a test image
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        
        let view = configureViewForSnapshot(
            ItemAnalysisDetailView(
                item: item,
                image: testImage,
                onSave: {}
            )
                .modelContainer(container)
                .environmentObject(SettingsManager())
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "item_analysis_detail_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    @Test("Image Analysis View Layout")
    func imageAnalysisViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        // Create a test image
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        
        let view = configureViewForSnapshot(
            ImageAnalysisView(image: testImage, onComplete: {})
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "image_analysis_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    // MARK: - Notifications and Additional Onboarding
    
    @Test("Onboarding Notifications View Layout")
    func onboardingNotificationsViewSnapshot() async throws {
        let container = try await createTestContainer()
        let manager = OnboardingManager()
        
        let view = configureViewForSnapshot(
            OnboardingNotificationsView()
                .modelContainer(container)
                .environmentObject(manager)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "onboarding_notifications_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    // MARK: - Camera Views (Mock Versions for Testing)
    
    @Test("Multi Photo Camera View Layout - Mock")
    func multiPhotoCameraViewMockSnapshot() async throws {
        let container = try await createTestContainer()
        
        // Note: Testing camera views is challenging due to hardware dependencies
        // This test would capture the UI structure but not actual camera functionality
        
        let view = configureViewForSnapshot(
            VStack {
                Text("Camera Preview")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                HStack {
                    Button("Cancel") { }
                    Spacer()
                    Button("Capture") { }
                        .background(Color.white)
                        .clipShape(Circle())
                    Spacer()
                    Button("Done") { }
                }
                .padding()
            }
            .frame(width: 390, height: 844)
            .background(Color.black)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "multi_photo_camera_view_mock\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
    
    // MARK: - Empty State and Error Views
    
    @Test("Import Loading View Layout")
    func importLoadingViewSnapshot() async throws {
        let container = try await createTestContainer()
        
        let view = configureViewForSnapshot(
            ImportLoadingView()
                .modelContainer(container)
        )
        
        try await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "import_loading_view\(snapshotSuffix)",
            file: filePath
        )
        
        await cleanup()
    }
}
