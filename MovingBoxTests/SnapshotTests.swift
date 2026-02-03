//
//  SnapshotTests.swift
//  MovingBoxTests
//
//  Created by Camden Webster on 4/2/25.
//

import SnapshotTesting
import SwiftData
import SwiftUI
import Testing

@testable import MovingBox

@MainActor
final class SnapshotTests {
    var filePath: StaticString {
        let xcodeCloudPath: StaticString =
            "/Volumes/workspace/repository/ci_scripts/SnapshotTests.swift"
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
            try context.deleteAllItems()

            print("Deleting locations...")
            try context.deleteAllLocations()

            print("Deleting labels...")
            try context.deleteAllLabels()

            print("Deleting homes...")
            try context.deleteAllHomes()

            print("Deleting policies...")
            try context.deleteAllPolicies()

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
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: Home.self, InventoryLabel.self, InventoryItem.self, InventoryLocation.self,
            InsurancePolicy.self, configurations: config)

        print("Container created successfully")
        testContainer = container

        if shouldLoadMockData {
            print("Populating test data...")
            await DefaultDataManager.populateTestData(modelContext: container.mainContext)
            try container.mainContext.save()
            print("Test data populated and saved")

            // Verify data was loaded
            let itemCount = try container.mainContext.fetch(FetchDescriptor<InventoryItem>()).count
            let locationCount = try container.mainContext.fetch(FetchDescriptor<InventoryLocation>())
                .count
            let labelCount = try container.mainContext.fetch(FetchDescriptor<InventoryLabel>()).count
            print(
                "Verification - Items: \(itemCount), Locations: \(locationCount), Labels: \(labelCount)")
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
    func deleteAllItems() throws {
        let items = try fetch(FetchDescriptor<InventoryItem>())
        items.forEach { delete($0) }
    }

    func deleteAllLocations() throws {
        let locations = try fetch(FetchDescriptor<InventoryLocation>())
        locations.forEach { delete($0) }
    }

    func deleteAllLabels() throws {
        let labels = try fetch(FetchDescriptor<InventoryLabel>())
        labels.forEach { delete($0) }
    }

    func deleteAllHomes() throws {
        let homes = try fetch(FetchDescriptor<Home>())
        homes.forEach { delete($0) }
    }

    func deleteAllPolicies() throws {
        let policies = try fetch(FetchDescriptor<InsurancePolicy>())
        policies.forEach { delete($0) }
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
            InventoryListView(locationID: location?.id)
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
            LocationsListView(showAllHomes: false)
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
            EditLocationView(locationID: location.id)
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
            EditLabelView(labelID: label.id)
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
            EditLabelView(labelID: label.id)
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
                item: item,
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
                item: item,
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
            "file:///mock/path/secondary3.jpg",
        ]

        let view = configureViewForSnapshot(
            InventoryDetailView(
                item: item,
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
            "file:///mock/path/secondary2.jpg",
        ]

        let view = configureViewForSnapshot(
            InventoryDetailView(
                item: item,
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

    @Test("Onboarding Notification View Layout")
    func onboardingHomeViewSnapshot() async throws {
        let container = try await createTestContainer()
        let manager = OnboardingManager()
        manager.currentStep = .notifications

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

    @Test("Onboarding Survey View Layout")
    func onboardingLocationViewSnapshot() async throws {
        let container = try await createTestContainer()
        let manager = OnboardingManager()
        manager.currentStep = .survey

        let view = configureViewForSnapshot(
            OnboardingLocationView()
                .modelContainer(container)
                .environmentObject(manager)
        )

        try await Task.sleep(for: .seconds(1))

        assertSnapshot(
            of: view,
            as: .image(precision: precision, layout: .device(config: .iPhone13Pro)),
            named: "onboarding_survey_view\(snapshotSuffix)",
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
}
