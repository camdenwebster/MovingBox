//
//  SnapshotTests.swift
//  MovingBoxTests
//
//  Created by Camden Webster on 4/2/25.
//

import SQLiteData
import SnapshotTesting
import SwiftUI
import Testing

@testable import MovingBox

@MainActor
final class SnapshotTests {
    var filePath: StaticString {
        let xcodeCloudPath: StaticString =
            "/Volumes/workspace/repository/ci_scripts/SnapshotTests.swift"
        if ProcessInfo.processInfo.environment["CI"] == "TRUE" {
            print("Using Xcode Cloud path for Snapshots")
            return xcodeCloudPath
        } else {
            return #file
        }
    }

    var precision: Float = 0.99

    private var shouldLoadMockData: Bool {
        return ProcessInfo.processInfo.arguments.contains("Mock-Data")
    }

    private var isDarkMode: Bool {
        let darkMode = ProcessInfo.processInfo.arguments.contains("Dark-Mode")
        return darkMode
    }

    private var snapshotSuffix: String {
        var suffix = ""
        if shouldLoadMockData { suffix += "_mockData" }
        if isDarkMode { suffix += "_dark" }
        return suffix
    }

    private var testDatabase: DatabaseQueue?

    private func cleanup() async {
        guard let database = testDatabase else { return }

        do {
            try await database.write { db in
                try SQLiteInventoryItem.delete().execute(db)
                try SQLiteInventoryItemLabel.delete().execute(db)
                try SQLiteInventoryLocation.delete().execute(db)
                try SQLiteInventoryLabel.delete().execute(db)
                try SQLiteHome.delete().execute(db)
                try SQLiteInsurancePolicy.delete().execute(db)
            }
        } catch {
            print("Error during cleanup: \(error)")
        }

        testDatabase = nil
    }

    private func createTestDatabase() async throws -> DatabaseQueue {
        await cleanup()

        let database = try makeInMemoryDatabase()
        testDatabase = database

        let _ = try prepareDependencies {
            $0.defaultDatabase = database
        }

        if shouldLoadMockData {
            let seeded = try makeSeededTestDatabase()
            testDatabase = seeded
            let _ = try prepareDependencies {
                $0.defaultDatabase = seeded
            }
            return seeded
        }

        return database
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

// MARK: - Tests
extension SnapshotTests {
    @Test("Dashboard View Layout")
    func dashboardViewSnapshot() async throws {
        let _ = try await createTestDatabase()

        let view = configureViewForSnapshot(
            DashboardView()
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
        let database = try await createTestDatabase()

        let location = try await database.read { db in
            try SQLiteInventoryLocation.where { $0.name == "Kitchen" }.fetchOne(db)
        }

        let view = configureViewForSnapshot(
            InventoryListView(locationID: location?.id)
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
        let _ = try await createTestDatabase()

        let view = configureViewForSnapshot(
            LocationsListView(showAllHomes: false)
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
        let database = try await createTestDatabase()

        let location = try await database.read { db in
            try SQLiteInventoryLocation.where { $0.name == "Kitchen" }.fetchOne(db)
        }

        let locationID = location?.id ?? UUID()

        let view = configureViewForSnapshot(
            EditLocationView(locationID: locationID)
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
        let database = try await createTestDatabase()

        let label = try await database.read { db in
            try SQLiteInventoryLabel.where { $0.name == "Electronics" }.fetchOne(db)
        }

        let labelID = label?.id ?? UUID()

        let view = configureViewForSnapshot(
            EditLabelView(labelID: labelID)
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
        let database = try await createTestDatabase()

        let label = try await database.read { db in
            try SQLiteInventoryLabel.where { $0.name == "Electronics" }.fetchOne(db)
        }

        let labelID = label?.id ?? UUID()

        let view = configureViewForSnapshot(
            EditLabelView(labelID: labelID)
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
        let _ = try await createTestDatabase()

        let view = configureViewForSnapshot(
            EditHomeView()
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
        let _ = try await createTestDatabase()

        let view = configureViewForSnapshot(
            EditHomeView()
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
        let database = try await createTestDatabase()

        let item = try await database.read { db in
            try SQLiteInventoryItem
                .where { $0.title == "MacBook Pro" && $0.make == "Apple" && $0.model == "MacBook Pro M2" }
                .fetchOne(db)
        }

        let itemID = item?.id ?? UUID()

        let view = configureViewForSnapshot(
            InventoryDetailView(
                itemID: itemID,
                navigationPath: .constant(NavigationPath()),
                isEditing: false
            )
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
        let database = try await createTestDatabase()

        let item = try await database.read { db in
            try SQLiteInventoryItem
                .where { $0.title == "MacBook Pro" && $0.make == "Apple" && $0.model == "MacBook Pro M2" }
                .fetchOne(db)
        }

        let itemID = item?.id ?? UUID()

        let view = configureViewForSnapshot(
            InventoryDetailView(
                itemID: itemID,
                navigationPath: .constant(NavigationPath()),
                isEditing: true
            )
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
        let database = try await createTestDatabase()

        let items = try await database.read { db in
            try SQLiteInventoryItem.order(by: \.title).fetchAll(db)
        }

        var item = items.first ?? SQLiteInventoryItem(id: UUID())
        let itemID = item.id

        item.secondaryPhotoURLs = [
            "file:///mock/path/secondary1.jpg",
            "file:///mock/path/secondary2.jpg",
            "file:///mock/path/secondary3.jpg",
        ]
        try await database.write { db in
            try SQLiteInventoryItem.find(itemID).update {
                $0.secondaryPhotoURLs = item.secondaryPhotoURLs
            }.execute(db)
        }

        let view = configureViewForSnapshot(
            InventoryDetailView(
                itemID: itemID,
                navigationPath: .constant(NavigationPath()),
                isEditing: false
            )
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
        let database = try await createTestDatabase()

        let items = try await database.read { db in
            try SQLiteInventoryItem.order(by: \.title).fetchAll(db)
        }

        var item = items.first ?? SQLiteInventoryItem(id: UUID())
        let itemID = item.id

        item.secondaryPhotoURLs = [
            "file:///mock/path/secondary1.jpg",
            "file:///mock/path/secondary2.jpg",
        ]
        try await database.write { db in
            try SQLiteInventoryItem.find(itemID).update {
                $0.secondaryPhotoURLs = item.secondaryPhotoURLs
            }.execute(db)
        }

        let view = configureViewForSnapshot(
            InventoryDetailView(
                itemID: itemID,
                navigationPath: .constant(NavigationPath()),
                isEditing: true
            )
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
        let _ = try await createTestDatabase()

        let view = configureViewForSnapshot(
            SettingsView()
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
        let _ = try await createTestDatabase()
        let manager = OnboardingManager()
        manager.currentStep = .welcome

        let view = configureViewForSnapshot(
            OnboardingWelcomeView()
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
        let _ = try await createTestDatabase()
        let manager = OnboardingManager()
        manager.currentStep = .notifications

        let view = configureViewForSnapshot(
            OnboardingHomeView()
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
        let _ = try await createTestDatabase()
        let manager = OnboardingManager()
        manager.currentStep = .survey

        let view = configureViewForSnapshot(
            OnboardingLocationView()
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
        let _ = try await createTestDatabase()
        let manager = OnboardingManager()
        manager.currentStep = .item

        let view = configureViewForSnapshot(
            OnboardingItemView()
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
        let _ = try await createTestDatabase()
        let manager = OnboardingManager()
        manager.currentStep = .completion

        let view = configureViewForSnapshot(
            OnboardingCompletionView(isPresented: .constant(true))
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
        let _ = try await createTestDatabase()
        let manager = OnboardingManager()

        let view = configureViewForSnapshot(
            OnboardingView(isPresented: .constant(true))
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
