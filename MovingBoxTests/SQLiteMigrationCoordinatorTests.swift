import Foundation
import Testing

@testable import MovingBox

@Suite("SQLite Migration Coordinator", .serialized)
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

    // MARK: - Skipped Counters in Stats

    @Test("MigrationStats description includes non-zero skipped counters")
    func skippedCountersInDescription() {
        var stats = SQLiteMigrationCoordinator.MigrationStats()
        stats.labels = 3
        stats.items = 10
        stats.skippedItemLabels = 2
        stats.skippedColors = 1

        let desc = stats.description
        #expect(desc.contains("skippedItemLabels=2"))
        #expect(desc.contains("skippedColors=1"))
        #expect(!desc.contains("skippedHomePolicies"))  // zero → omitted
    }

    @Test("MigrationStats description omits all skipped counters when zero")
    func skippedCountersOmittedWhenZero() {
        var stats = SQLiteMigrationCoordinator.MigrationStats()
        stats.labels = 1
        stats.items = 5

        let desc = stats.description
        #expect(!desc.contains("skipped"))
    }

    // MARK: - Decimal Precision

    @Test("Decimal(string:) preserves exact value for price storage")
    func decimalStringPrecision() {
        // String-based Decimal always preserves exact representation
        #expect("\(Decimal(string: "99.99")!)" == "99.99")
        #expect("\(Decimal(string: "0.01")!)" == "0.01")
        #expect("\(Decimal(string: "1234.56")!)" == "1234.56")
        #expect("\(Decimal(string: "999999.99")!)" == "999999.99")
    }

    // MARK: - Retry Limit

    private static let testAttemptsKey =
        "com.mothersound.movingbox.sqlitedata.migration.attempts"

    @Test("Migration abandoned after max retry attempts")
    func retryLimitAbandons() throws {
        let db = try makeInMemoryDatabase()

        // Clear state
        UserDefaults.standard.removeObject(forKey: Self.testMigrationKey)
        UserDefaults.standard.removeObject(forKey: Self.testAttemptsKey)
        defer {
            UserDefaults.standard.removeObject(forKey: Self.testMigrationKey)
            UserDefaults.standard.removeObject(forKey: Self.testAttemptsKey)
        }

        // Simulate 3 prior failed attempts
        UserDefaults.standard.set(3, forKey: Self.testAttemptsKey)

        let result = SQLiteMigrationCoordinator.migrateIfNeeded(database: db)
        switch result {
        case .error(let msg):
            #expect(msg.contains("abandoned"))
        default:
            Issue.record("Expected .error with 'abandoned', got \(result)")
        }

        // Should NOT mark migration complete — old store preserved for future recovery
        #expect(!UserDefaults.standard.bool(forKey: Self.testMigrationKey))
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
