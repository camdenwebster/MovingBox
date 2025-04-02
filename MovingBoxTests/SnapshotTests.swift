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
    
    var precision: Float = 0.99
    
    // Helper property to check if mock data should be loaded
    private var shouldLoadMockData: Bool {
        return ProcessInfo.processInfo.arguments.contains("Mock-Data")
    }
    
    private var snapshotSuffix: String {
        return shouldLoadMockData ? "_mockData" : ""
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
    
    @Test("Dashboard View Layout")
    func dashboardViewSnapshot() async {
        let container = try! await createTestContainer()
        
        let view = DashboardView()
            .frame(width: 390, height: 844)
            .preferredColorScheme(.light)
            .modelContainer(container)
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro), ),
            named: "dashboard_view\(snapshotSuffix)"
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
        
        let view = InventoryListView(location: location)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.light)
            .modelContainer(container)
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_list_view\(snapshotSuffix)"
        )
    }
    
    @Test("Locations List View Layout")
    func locationsListViewSnapshot() async {
        let container = try! await createTestContainer()
        
        let view = LocationsListView()
            .frame(width: 390, height: 844)
            .preferredColorScheme(.light)
            .modelContainer(container)
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "locations_list_view\(snapshotSuffix)"
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
        
        let view = AddInventoryItemView(location: location)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.light)
            .modelContainer(container)
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "add_inventory_item_view\(snapshotSuffix)"
        )
    }
    
    @Test("Edit Location View Layout")
    func editLocationViewSnapshot() async {
        let container = try! await createTestContainer()
        
        // Get kitchen location instead of first one
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { location in
                location.name == "Kitchen"
            }
        )
        let locations = try! container.mainContext.fetch(descriptor)
        let location = locations.first ?? InventoryLocation()
        
        let view = EditLocationView(location: location)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.light)
            .modelContainer(container)
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "edit_location_view\(snapshotSuffix)"
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
        
        let view = InventoryDetailView(
            inventoryItemToDisplay: item, 
            navigationPath: .constant(NavigationPath()),
            isEditing: false
        )
            .frame(width: 390, height: 844)
            .preferredColorScheme(.light)
            .modelContainer(container)
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_detail_view_read\(snapshotSuffix)"
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
        
        let view = InventoryDetailView(
            inventoryItemToDisplay: item, 
            navigationPath: .constant(NavigationPath()),
            isEditing: true
        )
            .frame(width: 390, height: 844)
            .preferredColorScheme(.light)
            .modelContainer(container)
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "inventory_detail_view_edit\(snapshotSuffix)"
        )
    }
    
    @Test("Settings View Layout")
    func settingsViewSnapshot() async {
        let container = try! await createTestContainer()
        
        let view = SettingsView()
            .frame(width: 390, height: 844)
            .preferredColorScheme(.light)
            .modelContainer(container)
        
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "settings_view\(snapshotSuffix)"
        )
    }
}
