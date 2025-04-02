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
struct SnapshotTests {

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
    
    // Helper function to create and populate test container
    private func createTestContainer() async throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Home.self, InventoryLabel.self, InventoryItem.self, InventoryLocation.self, InsurancePolicy.self, configurations: config)
        
        // Only load test data if the Mock-Data argument is present
        if shouldLoadMockData {
            await DefaultDataManager.populateTestData(modelContext: container.mainContext)
        }
        
        return container
    }
    
    // Helper function to configure view for snapshot testing
    private func configureViewForSnapshot<T: View>(_ view: T) -> some View {
        view
            .frame(width: 390, height: 844)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .background(Color(.systemBackground))
            .environment(\.colorScheme, isDarkMode ? .dark : .light)
    }
    
    @Test("Dashboard View Layout")
    func dashboardViewSnapshot() async {
        let container = try! await createTestContainer()
        
        let view = configureViewForSnapshot(
            DashboardView()
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "dashboard_view\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Inventory List View Layout")
    func inventoryListViewSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get kitchen location instead of first one
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { location in
                location.name == "Kitchen"
            }
        )
        let locations = try! container.mainContext.fetch(descriptor)
        let location = locations.first
        
        let view = configureViewForSnapshot(
            InventoryListView(location: location)
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_list_view\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Locations List View Layout")
    func locationsListViewSnapshot() async {
        let container = try! await createTestContainer()
        
        let view = configureViewForSnapshot(
            LocationsListView()
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "locations_list_view\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Add Inventory Item View Layout")
    func addInventoryItemViewSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get kitchen location instead of first one
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { location in
                location.name == "Kitchen"
            }
        )
        let locations = try! container.mainContext.fetch(descriptor)
        let location = locations.first
        
        let view = configureViewForSnapshot(
            AddInventoryItemView(location: location)
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "add_inventory_item_view\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Edit Location View Layout - Edit Mode")
    func editLocationViewEditModeSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get kitchen location for consistency
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { location in
                location.name == "Kitchen"
            }
        )
        let locations = try! container.mainContext.fetch(descriptor)
        let location = locations.first ?? InventoryLocation()
        
        let view = configureViewForSnapshot(
            EditLocationView(location: location)
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_location_view_edit\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Edit Label View Layout - Read Mode")
    func editLabelViewReadModeSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get Electronics label for consistency
        let descriptor = FetchDescriptor<InventoryLabel>(
            predicate: #Predicate<InventoryLabel> { label in
                label.name == "Electronics"
            }
        )
        let labels = try! container.mainContext.fetch(descriptor)
        let label = labels.first ?? InventoryLabel()
        
        let view = configureViewForSnapshot(
            EditLabelView(label: label)
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_label_view_read\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Edit Label View Layout - Edit Mode")
    func editLabelViewEditModeSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get Electronics label for consistency
        let descriptor = FetchDescriptor<InventoryLabel>(
            predicate: #Predicate<InventoryLabel> { label in
                label.name == "Electronics"
            }
        )
        let labels = try! container.mainContext.fetch(descriptor)
        let label = labels.first ?? InventoryLabel()
        
        let view = configureViewForSnapshot(
            EditLabelView(label: label)
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_label_view_edit\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Edit Home View Layout - Read Mode")
    func editHomeViewReadModeSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get first home for consistency
        let descriptor = FetchDescriptor<Home>()
        let homes = try! container.mainContext.fetch(descriptor)
        let home = homes.first ?? Home()
        
        let view = configureViewForSnapshot(
            EditHomeView(home: home)
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_home_view_read\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Edit Home View Layout - Edit Mode")
    func editHomeViewEditModeSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get first home for consistency
        let descriptor = FetchDescriptor<Home>()
        let homes = try! container.mainContext.fetch(descriptor)
        let home = homes.first ?? Home()
        
        let view = configureViewForSnapshot(
            EditHomeView(home: home)
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_home_view_edit\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Inventory Detail View - Read Mode")
    func inventoryDetailViewReadModeSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get MacBook Pro item for consistency
        let descriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate<InventoryItem> { item in
                item.title == "MacBook Pro" && item.make == "Apple" && item.model == "MacBook Pro M2"
            }
        )
        let items = try! container.mainContext.fetch(descriptor)
        let item = items.first ?? InventoryItem()
        
        let view = configureViewForSnapshot(
            InventoryDetailView(
                inventoryItemToDisplay: item,
                navigationPath: .constant(NavigationPath()),
                isEditing: false
            )
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_detail_view_read\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Inventory Detail View - Edit Mode")
    func inventoryDetailViewEditModeSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get MacBook Pro item for consistency
        let descriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate<InventoryItem> { item in
                item.title == "MacBook Pro" && item.make == "Apple" && item.model == "MacBook Pro M2"
            }
        )
        let items = try! container.mainContext.fetch(descriptor)
        let item = items.first ?? InventoryItem()
        
        let view = configureViewForSnapshot(
            InventoryDetailView(
                inventoryItemToDisplay: item,
                navigationPath: .constant(NavigationPath()),
                isEditing: true
            )
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_detail_view_edit\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Settings View Layout")
    func settingsViewSnapshot() async {
        let container = try! await createTestContainer()
        
        let view = configureViewForSnapshot(
            SettingsView()
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "settings_view\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Camera View Layout")
    func cameraViewSnapshot() async {
        let container = try! await createTestContainer()
        
        let view = configureViewForSnapshot(
            CameraView { image, needsAIAnalysis, completion in
                completion()
            }
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "camera_view\(snapshotSuffix)",
            file: #file
        )
    }
    
    @Test("Photo Review View Layout")
    func photoReviewViewSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get MacBook Pro item's photo for consistency
        let descriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate<InventoryItem> { item in
                item.title == "MacBook Pro" && item.make == "Apple"
            }
        )
        let items = try! container.mainContext.fetch(descriptor)
        let item = items.first ?? InventoryItem()
        
        let view = configureViewForSnapshot(
            PhotoReviewView(
                image: item.photo ?? UIImage(),
                onAccept: { _, _, completion in completion() },
                onRetake: { }
            )
                .modelContainer(container)
        )
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "photo_review_view\(snapshotSuffix)",
            file: #file
        )
    }
}
