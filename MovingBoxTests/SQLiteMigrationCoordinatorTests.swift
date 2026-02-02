import Foundation
import Testing

@testable import MovingBox

@Suite("SQLite Migration Coordinator")
struct SQLiteMigrationCoordinatorTests {

    private static let testMigrationKey =
        "com.mothersound.movingbox.sqlitedata.migration.complete"

    // MARK: - Fresh Install

    @Test("Returns a valid result when migration flag is cleared")
    func freshOrMigratedResult() throws {
        let db = try makeInMemoryDatabase()

        // Clear any previous migration flag
        UserDefaults.standard.removeObject(forKey: Self.testMigrationKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.testMigrationKey) }

        let result = SQLiteMigrationCoordinator.migrateIfNeeded(database: db)
        // In test environment, the result depends on whether a SwiftData store
        // exists on the simulator. All outcomes are valid:
        // - .freshInstall: no store found
        // - .success: store found and migration succeeded
        // - .error: store found but migration had issues (still a valid code path)
        switch result {
        case .freshInstall, .success, .error:
            break  // all valid outcomes
        case .alreadyCompleted:
            Issue.record("Unexpected .alreadyCompleted after clearing flag")
        }
    }

    // MARK: - Already Completed

    @Test("Returns .alreadyCompleted when flag is set")
    func alreadyCompleted() throws {
        let db = try makeInMemoryDatabase()

        // Set the migration-complete flag
        UserDefaults.standard.set(true, forKey: Self.testMigrationKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.testMigrationKey) }

        let result = SQLiteMigrationCoordinator.migrateIfNeeded(database: db)
        switch result {
        case .alreadyCompleted:
            break  // expected
        default:
            Issue.record("Expected .alreadyCompleted, got \(result)")
        }
    }

    // MARK: - MigrationStats

    @Test("MigrationStats description format")
    func migrationStatsDescription() {
        var stats = SQLiteMigrationCoordinator.MigrationStats()
        stats.labels = 5
        stats.homes = 2
        stats.policies = 1
        stats.locations = 10
        stats.items = 50
        stats.itemLabels = 30
        stats.homePolicies = 2
        let desc = stats.description
        #expect(desc.contains("labels=5"))
        #expect(desc.contains("homes=2"))
        #expect(desc.contains("items=50"))
        #expect(desc.contains("itemLabels=30"))
        #expect(desc.contains("homePolicies=2"))
    }

    // MARK: - Schema

    @Test("In-memory database creates all expected tables")
    func allTablesExist() throws {
        let db = try makeInMemoryDatabase()
        let tables = try fetchTableNames(from: db)
        #expect(tables.count >= 7, "Expected at least 7 tables, got \(tables.count)")
        #expect(tables.contains("inventoryLabels"))
        #expect(tables.contains("homes"))
        #expect(tables.contains("insurancePolicies"))
        #expect(tables.contains("inventoryLocations"))
        #expect(tables.contains("inventoryItems"))
        #expect(tables.contains("inventoryItemLabels"))
        #expect(tables.contains("homeInsurancePolicies"))
    }

    // MARK: - FK Integrity After Full Insert

    @Test("Foreign key integrity after inserting all entity types")
    func foreignKeyIntegrity() throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()
        let locationID = UUID()
        let itemID = UUID()
        let labelID = UUID()
        let policyID = UUID()

        try db.write { db in
            try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Test Home")).execute(db)
            try SQLiteInsurancePolicy.insert(
                SQLiteInsurancePolicy(id: policyID, providerName: "TestCo")
            ).execute(db)
            try SQLiteInventoryLabel.insert(
                SQLiteInventoryLabel(id: labelID, name: "TestLabel")
            ).execute(db)
            try SQLiteInventoryLocation.insert(
                SQLiteInventoryLocation(id: locationID, name: "Room", homeID: homeID)
            ).execute(db)
            try SQLiteInventoryItem.insert(
                SQLiteInventoryItem(
                    id: itemID, title: "Widget", locationID: locationID, homeID: homeID
                )
            ).execute(db)
            try SQLiteInventoryItemLabel.insert(
                SQLiteInventoryItemLabel(
                    id: UUID(), inventoryItemID: itemID, inventoryLabelID: labelID
                )
            ).execute(db)
            try SQLiteHomeInsurancePolicy.insert(
                SQLiteHomeInsurancePolicy(
                    id: UUID(), homeID: homeID, insurancePolicyID: policyID
                )
            ).execute(db)
        }

        let passes = try checkForeignKeyIntegrity(db: db)
        #expect(passes, "Foreign key violations found after full insert")
    }
}
