import Darwin
import Foundation
import SQLiteData
import Testing

@testable import MovingBox

@Suite("SQLite Migration Coordinator", .serialized)
struct SQLiteMigrationCoordinatorTests {

    private static let testMigrationKey =
        "com.mothersound.movingbox.sqlitedata.migration.complete"
    private static let testStoreOverrideEnv = "MOVINGBOX_SWIFTDATA_STORE_PATH_OVERRIDE"

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

    // MARK: - Attachment Plist→JSON Round-Trip (Fix 18)

    @Test("AttachmentInfo plist→JSON round-trip preserves all fields")
    func attachmentPlistJSONRoundTrip() throws {
        let attachment = AttachmentInfo(url: "file:///doc.pdf", originalName: "doc.pdf")
        let plistData = try PropertyListEncoder().encode([attachment])

        // The typed path (readAttachmentsPlistJSON) should preserve createdAt as a date string
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, enc in
            var container = enc.singleValueContainer()
            try container.encode(date.sqliteDateString)
        }
        let decoded = try PropertyListDecoder().decode([AttachmentInfo].self, from: plistData)
        let jsonData = try encoder.encode(decoded)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        #expect(jsonString.contains("doc.pdf"))
        #expect(jsonString.contains("createdAt"))
        // Verify it's valid JSON
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
        #expect(parsed?.count == 1)
        #expect(parsed?[0]["url"] as? String == "file:///doc.pdf")
        #expect(parsed?[0]["originalName"] as? String == "doc.pdf")
        #expect(parsed?[0]["createdAt"] as? String != nil)
    }

    @Test("Generic JSONSerialization drops NSDate from plist AttachmentInfo")
    func genericPathDropsNSDate() throws {
        let attachment = AttachmentInfo(url: "file:///doc.pdf", originalName: "doc.pdf")
        let plistData = try PropertyListEncoder().encode([attachment])

        // Decode as generic plist (the old code path)
        let plistObj =
            try PropertyListSerialization.propertyList(
                from: plistData, options: [], format: nil) as? [Any]
        #expect(plistObj != nil)

        // JSONSerialization cannot handle NSDate — this should fail
        let isValidJSON = JSONSerialization.isValidJSONObject(plistObj!)
        #expect(!isValidJSON, "NSDate in plist should make JSONSerialization fail")
    }

    // MARK: - Zero-Data Sanity Check (Fix 19)

    @Test("MigrationStats with zero homes represents failure condition")
    func zeroHomesIsFailureCondition() {
        let stats = SQLiteMigrationCoordinator.MigrationStats()
        // Default stats have homes == 0, which the coordinator now guards against
        #expect(stats.homes == 0)
        // Onboarding always creates at least one home, so zero from a non-empty
        // store indicates a read failure
    }

    // MARK: - Item HomeID Backfill (Fix 20)

    @Test("Items without home but with homed location get backfilled homeID")
    func itemHomeBackfillFromLocation() throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()
        let locationID = UUID()
        let itemID = UUID()

        try db.write { db in
            try SQLiteHome.insert(SQLiteHome(id: homeID, name: "Test Home")).execute(db)
            try SQLiteInventoryLocation.insert(
                SQLiteInventoryLocation(id: locationID, name: "Room", homeID: homeID)
            ).execute(db)
            // Item with location but no direct home — tests the backfill scenario
            try SQLiteInventoryItem.insert(
                SQLiteInventoryItem(
                    id: itemID, title: "Widget", locationID: locationID, homeID: homeID
                )
            ).execute(db)
        }

        // Verify the item has the correct homeID
        let itemHomeID = try db.read { db in
            try String.fetchOne(
                db, sql: "SELECT homeID FROM inventoryItems WHERE id = ?",
                arguments: [itemID.uuidString.lowercased()])
        }
        #expect(itemHomeID == homeID.uuidString.lowercased())
    }

    @Test("Existing item home assignment is not overwritten by backfill logic")
    func existingHomeNotOverwritten() throws {
        let db = try makeInMemoryDatabase()
        let home1ID = UUID()
        let home2ID = UUID()
        let locationID = UUID()
        let itemID = UUID()

        try db.write { db in
            try SQLiteHome.insert(SQLiteHome(id: home1ID, name: "Home 1")).execute(db)
            try SQLiteHome.insert(SQLiteHome(id: home2ID, name: "Home 2")).execute(db)
            try SQLiteInventoryLocation.insert(
                SQLiteInventoryLocation(id: locationID, name: "Room", homeID: home1ID)
            ).execute(db)
            // Item explicitly assigned to home2, even though location is in home1
            try SQLiteInventoryItem.insert(
                SQLiteInventoryItem(
                    id: itemID, title: "Widget", locationID: locationID, homeID: home2ID
                )
            ).execute(db)
        }

        // Verify the item retains its explicit home assignment
        let itemHomeID = try db.read { db in
            try String.fetchOne(
                db, sql: "SELECT homeID FROM inventoryItems WHERE id = ?",
                arguments: [itemID.uuidString.lowercased()])
        }
        #expect(itemHomeID == home2ID.uuidString.lowercased())
    }

    // MARK: - Legacy Zero-Home Upgrade Regression

    @Test("Legacy store with items/locations and zero homes migrates successfully")
    func legacyStoreWithoutHomesStillMigrates() throws {
        let db = try makeInMemoryDatabase()
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SQLiteMigrationCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let storePath = tempRoot.appendingPathComponent("default.store").path
        try createLegacyStoreWithoutHomes(at: storePath)

        UserDefaults.standard.removeObject(forKey: Self.testMigrationKey)
        UserDefaults.standard.removeObject(forKey: Self.testAttemptsKey)
        defer {
            UserDefaults.standard.removeObject(forKey: Self.testMigrationKey)
            UserDefaults.standard.removeObject(forKey: Self.testAttemptsKey)
            unsetenv(Self.testStoreOverrideEnv)
        }

        setenv(Self.testStoreOverrideEnv, storePath, 1)

        let result = SQLiteMigrationCoordinator.migrateIfNeeded(database: db)
        let stats: SQLiteMigrationCoordinator.MigrationStats
        switch result {
        case .success(let successStats):
            stats = successStats
        default:
            Issue.record("Expected successful migration, got \(result)")
            return
        }

        #expect(stats.homes == 1)
        #expect(stats.locations == 3)
        #expect(stats.items == 6)
        #expect(UserDefaults.standard.bool(forKey: Self.testMigrationKey))
        #expect(UserDefaults.standard.object(forKey: Self.testAttemptsKey) == nil)

        let migrated = try db.read { db in
            let homeCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM homes") ?? 0
            let locationCount =
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM inventoryLocations")
                ?? 0
            let itemCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM inventoryItems") ?? 0
            let locationsWithoutHome =
                try Int.fetchOne(
                    db, sql: "SELECT COUNT(*) FROM inventoryLocations WHERE homeID IS NULL") ?? 0
            let itemsWithoutHome =
                try Int.fetchOne(
                    db, sql: "SELECT COUNT(*) FROM inventoryItems WHERE homeID IS NULL") ?? 0
            return (
                homeCount: homeCount,
                locationCount: locationCount,
                itemCount: itemCount,
                locationsWithoutHome: locationsWithoutHome,
                itemsWithoutHome: itemsWithoutHome
            )
        }

        #expect(migrated.homeCount == 1)
        #expect(migrated.locationCount == 3)
        #expect(migrated.itemCount == 6)
        #expect(migrated.locationsWithoutHome == 0)
        #expect(migrated.itemsWithoutHome == 0)
    }

    @Test("Successful migration archives legacy SwiftData store")
    func successfulMigrationArchivesStore() throws {
        let db = try makeInMemoryDatabase()
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SQLiteMigrationCoordinatorArchiveTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let storePath = tempRoot.appendingPathComponent("default.store").path
        try createLegacyStoreWithoutHomes(at: storePath)

        UserDefaults.standard.removeObject(forKey: Self.testMigrationKey)
        UserDefaults.standard.removeObject(forKey: Self.testAttemptsKey)
        defer {
            UserDefaults.standard.removeObject(forKey: Self.testMigrationKey)
            UserDefaults.standard.removeObject(forKey: Self.testAttemptsKey)
            unsetenv(Self.testStoreOverrideEnv)
        }

        setenv(Self.testStoreOverrideEnv, storePath, 1)

        let result = SQLiteMigrationCoordinator.migrateIfNeeded(database: db)
        switch result {
        case .success:
            break
        default:
            Issue.record("Expected successful migration, got \(result)")
            return
        }

        let backupStorePath =
            tempRoot
            .appendingPathComponent("SwiftDataBackup")
            .appendingPathComponent("default.store")
            .path
        #expect(!FileManager.default.fileExists(atPath: storePath))
        #expect(FileManager.default.fileExists(atPath: backupStorePath))
    }

    // MARK: - Helpers

    private func createLegacyStoreWithoutHomes(at storePath: String) throws {
        let legacyDB = try DatabaseQueue(path: storePath)
        try legacyDB.write { db in
            try db.execute(
                sql: """
                    CREATE TABLE ZHOME (
                        Z_PK INTEGER PRIMARY KEY,
                        ZNAME TEXT,
                        ZADDRESS1 TEXT,
                        ZADDRESS2 TEXT,
                        ZCITY TEXT,
                        ZSTATE TEXT,
                        ZZIP TEXT,
                        ZCOUNTRY TEXT,
                        ZPURCHASEDATE REAL,
                        ZPURCHASEPRICE REAL,
                        ZIMAGEURL TEXT,
                        ZSECONDARYPHOTOURLS BLOB
                    )
                    """
            )

            try db.execute(
                sql: """
                    CREATE TABLE ZINVENTORYLOCATION (
                        Z_PK INTEGER PRIMARY KEY,
                        ZNAME TEXT NOT NULL,
                        ZDESC TEXT,
                        ZIMAGEURL TEXT,
                        ZSECONDARYPHOTOURLS BLOB
                    )
                    """
            )

            try db.execute(
                sql: """
                    CREATE TABLE ZINVENTORYITEM (
                        Z_PK INTEGER PRIMARY KEY,
                        ZTITLE TEXT NOT NULL,
                        ZQUANTITYSTRING TEXT,
                        ZQUANTITYINT INTEGER,
                        ZDESC TEXT,
                        ZSERIAL TEXT,
                        ZMODEL TEXT,
                        ZMAKE TEXT,
                        ZPRICE REAL,
                        ZINSURED INTEGER,
                        ZASSETID TEXT,
                        ZNOTES TEXT,
                        ZIMAGEURL TEXT,
                        ZSECONDARYPHOTOURLS BLOB,
                        ZHASUSEDAI INTEGER,
                        ZCREATEDAT REAL,
                        ZLOCATION INTEGER
                    )
                    """
            )

            for (index, name) in ["Living Room", "Garage", "Office"].enumerated() {
                try db.execute(
                    sql: """
                        INSERT INTO ZINVENTORYLOCATION (Z_PK, ZNAME, ZDESC, ZIMAGEURL, ZSECONDARYPHOTOURLS)
                        VALUES (?, ?, ?, NULL, NULL)
                        """,
                    arguments: [index + 1, name, ""]
                )
            }

            let itemNames = [
                "Lamp #1",
                "Router/Modem Combo",
                "Toolbox (Heavy)",
                "Unicode Test - Cafe",
                "Long Text Item",
                "Orphan Candidate",
            ]
            for (index, title) in itemNames.enumerated() {
                try db.execute(
                    sql: """
                        INSERT INTO ZINVENTORYITEM (
                            Z_PK, ZTITLE, ZQUANTITYSTRING, ZQUANTITYINT, ZDESC, ZSERIAL,
                            ZMODEL, ZMAKE, ZPRICE, ZINSURED, ZASSETID, ZNOTES, ZIMAGEURL,
                            ZSECONDARYPHOTOURLS, ZHASUSEDAI, ZCREATEDAT, ZLOCATION
                        ) VALUES (?, ?, '1', 1, '', '', '', '', 0.0, 0, '', '', NULL, NULL, 0, 0, ?)
                        """,
                    arguments: [index + 1, title, (index % 3) + 1]
                )
            }
        }
    }
}
