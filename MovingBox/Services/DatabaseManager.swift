import Dependencies
import Foundation
import OSLog
import SQLiteData
import ZIPFoundation

private let logger = Logger(subsystem: "com.mothersound.movingbox", category: "Database")

let movingBoxCloudKitContainerIdentifier = "iCloud.com.mothersound.movingbox"
private let isRunningXCTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
private let pendingDatabaseRestoreDirectoryName = "PendingDatabaseRestore"
private let pendingDatabaseRestoreArchiveName = "database-restore.zip"
private let pendingDatabaseRestoreManifestName = "manifest.json"

private struct PendingDatabaseRestoreManifest: Codable, Sendable {
    let archiveFileName: String
    let createdAt: Date
}

enum PendingDatabaseRestoreError: LocalizedError {
    case invalidArchive
    case missingDatabaseFile
    case multipleDatabaseFiles
    case unsupportedDatabaseExtension
    case unexpectedArchiveContents
    case missingStagedArchive
    case unableToStageArchive
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "The selected archive is not a valid database backup."
        case .missingDatabaseFile:
            return "The archive does not contain a SQLite database file."
        case .multipleDatabaseFiles:
            return "The archive contains multiple SQLite database files."
        case .unsupportedDatabaseExtension:
            return "The archive contains an unsupported database file type."
        case .unexpectedArchiveContents:
            return "The archive contains unsupported extra files."
        case .missingStagedArchive:
            return "The staged restore archive is missing."
        case .unableToStageArchive:
            return "Unable to stage the selected database archive."
        case .restoreFailed:
            return "Failed to apply the staged database restore."
        }
    }
}

/// Attempts to attach sqlite-data's CloudKit metadatabase to a database connection.
/// This is best-effort so local-only/test flows keep working when CloudKit is unavailable.
func attachMetadatabaseIfPossible(to db: Database) {
    // XCTest runs many DB-backed tests in parallel; sharing sqlite-data's
    // CloudKit metadata database across those connections causes lock errors.
    guard !isRunningXCTest else { return }

    do {
        try db.attachMetadatabase(containerIdentifier: movingBoxCloudKitContainerIdentifier)
    } catch {
        // Best effort only. Callers should treat missing sync metadata as "not shared".
    }
}

/// Returns true when an error indicates the sqlite-data CloudKit metadata table is unavailable.
func isMissingSyncMetadataTableError(_ error: Error) -> Bool {
    guard let error = error as? DatabaseError else { return false }
    guard error.resultCode == .SQLITE_ERROR else { return false }
    guard let message = error.message?.lowercased() else { return false }
    return message.contains("no such table")
        && (message.contains("sqlitedata_icloud_metadata")
            || message.contains("sqlitedata_icloud.sqlitedata_icloud_metadata"))
}

func defaultSQLiteDataDatabasePath() throws -> String {
    let applicationSupportDirectory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    return applicationSupportDirectory.appendingPathComponent("SQLiteData.db").path
}

func validateDatabaseBackupArchive(at zipURL: URL) throws {
    let workingDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("database-archive-validate-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: workingDir)
    }

    try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
    do {
        try FileManager.default.unzipItem(at: zipURL, to: workingDir)
    } catch {
        throw PendingDatabaseRestoreError.invalidArchive
    }

    _ = try databaseFileSetForRestore(in: workingDir)
}

func stagePendingDatabaseRestoreArchive(from sourceArchiveURL: URL) throws {
    try validateDatabaseBackupArchive(at: sourceArchiveURL)

    let restoreDirectory = try pendingDatabaseRestoreDirectory()
    do {
        try? FileManager.default.removeItem(at: restoreDirectory)
        try FileManager.default.createDirectory(at: restoreDirectory, withIntermediateDirectories: true)

        let stagedArchiveURL = restoreDirectory.appendingPathComponent(pendingDatabaseRestoreArchiveName)
        try FileManager.default.copyItem(at: sourceArchiveURL, to: stagedArchiveURL)

        let manifest = PendingDatabaseRestoreManifest(
            archiveFileName: pendingDatabaseRestoreArchiveName,
            createdAt: Date()
        )
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: restoreDirectory.appendingPathComponent(pendingDatabaseRestoreManifestName))
    } catch {
        throw PendingDatabaseRestoreError.unableToStageArchive
    }
}

func applyPendingDatabaseRestoreIfNeeded(targetDatabasePath: String) throws {
    let restoreDirectory = try pendingDatabaseRestoreDirectory()
    let manifestURL = restoreDirectory.appendingPathComponent(pendingDatabaseRestoreManifestName)
    guard FileManager.default.fileExists(atPath: manifestURL.path) else { return }

    let manifestData = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode(PendingDatabaseRestoreManifest.self, from: manifestData)
    let archiveURL = restoreDirectory.appendingPathComponent(manifest.archiveFileName)

    guard FileManager.default.fileExists(atPath: archiveURL.path) else {
        throw PendingDatabaseRestoreError.missingStagedArchive
    }

    let workingDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("database-restore-apply-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: workingDir)
    }

    do {
        try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: archiveURL, to: workingDir)
        let fileSet = try databaseFileSetForRestore(in: workingDir)

        let targetURL = URL(fileURLWithPath: targetDatabasePath)
        try FileManager.default.createDirectory(
            at: targetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let sourceDatabase = try DatabaseQueue(path: fileSet.base.path)
        let destinationDatabase = try DatabaseQueue(path: targetDatabasePath)
        try sourceDatabase.backup(to: destinationDatabase)
        try sourceDatabase.close()
        try destinationDatabase.close()

        try? FileManager.default.removeItem(at: restoreDirectory)
    } catch {
        throw PendingDatabaseRestoreError.restoreFailed
    }
}

private func pendingDatabaseRestoreDirectory() throws -> URL {
    let applicationSupportDirectory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    return applicationSupportDirectory.appendingPathComponent(pendingDatabaseRestoreDirectoryName, isDirectory: true)
}

private func databaseFileSetForRestore(in workingDirectory: URL) throws -> (base: URL, sidecars: [URL]) {
    let enumerator = FileManager.default.enumerator(
        at: workingDirectory,
        includingPropertiesForKeys: [.isRegularFileKey]
    )

    var files: [URL] = []
    while let value = enumerator?.nextObject() as? URL {
        let resourceValues = try value.resourceValues(forKeys: [.isRegularFileKey])
        if resourceValues.isRegularFile == true {
            files.append(value)
        }
    }

    let baseFiles = files.filter { fileURL in
        let name = fileURL.lastPathComponent.lowercased()
        return !name.hasSuffix("-wal") && !name.hasSuffix("-shm")
    }

    guard !baseFiles.isEmpty else { throw PendingDatabaseRestoreError.missingDatabaseFile }
    guard baseFiles.count == 1 else { throw PendingDatabaseRestoreError.multipleDatabaseFiles }

    let base = baseFiles[0]
    let extensionLowercased = base.pathExtension.lowercased()
    guard ["db", "sqlite", "sqlite3"].contains(extensionLowercased) else {
        throw PendingDatabaseRestoreError.unsupportedDatabaseExtension
    }

    let allowedNames: Set<String> = [
        base.lastPathComponent,
        base.lastPathComponent + "-wal",
        base.lastPathComponent + "-shm",
    ]
    let fileNames = Set(files.map(\.lastPathComponent))
    guard fileNames.isSubset(of: allowedNames) else {
        throw PendingDatabaseRestoreError.unexpectedArchiveContents
    }

    let sidecars = files.filter { fileURL in
        let name = fileURL.lastPathComponent.lowercased()
        return name.hasSuffix("-wal") || name.hasSuffix("-shm")
    }
    return (base, sidecars)
}

/// Registers all sqlite-data schema migrations on the given migrator.
/// Shared between the production database and in-memory test databases
/// so the schema is always defined in exactly one place.
func registerMigrations(_ migrator: inout DatabaseMigrator) {
    migrator.registerMigration("Create initial tables") { db in
        // 1. inventoryLabels (no FK dependencies)
        try #sql(
            """
            CREATE TABLE "inventoryLabels" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "householdID" TEXT,
                "name" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "desc" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "color" INTEGER,
                "emoji" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '🏷️'
            ) STRICT
            """
        )
        .execute(db)

        // 2. homes (no FK dependencies)
        try #sql(
            """
            CREATE TABLE "homes" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "name" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "address1" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "address2" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "city" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "state" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "zip" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "country" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "purchaseDate" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                "purchasePrice" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '0',
                "imageURL" TEXT,
                "secondaryPhotoURLs" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]',
                "isPrimary" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "colorName" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'green'
            ) STRICT
            """
        )
        .execute(db)

        // 3. insurancePolicies (no FK dependencies)
        try #sql(
            """
            CREATE TABLE "insurancePolicies" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "providerName" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "policyNumber" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "deductibleAmount" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '0',
                "dwellingCoverageAmount" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '0',
                "personalPropertyCoverageAmount" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '0',
                "lossOfUseCoverageAmount" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '0',
                "liabilityCoverageAmount" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '0',
                "medicalPaymentsCoverageAmount" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '0',
                "startDate" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                "endDate" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
            ) STRICT
            """
        )
        .execute(db)

        // 4. inventoryLocations (FK to homes)
        try #sql(
            """
            CREATE TABLE "inventoryLocations" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "name" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "desc" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "sfSymbolName" TEXT,
                "imageURL" TEXT,
                "secondaryPhotoURLs" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]',
                "homeID" TEXT REFERENCES "homes"("id") ON DELETE SET NULL
            ) STRICT
            """
        )
        .execute(db)

        // 5. inventoryItems (home FK; location stored as nullable UUID text)
        try #sql(
            """
            CREATE TABLE "inventoryItems" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "title" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "quantityString" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '1',
                "quantityInt" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 1,
                "desc" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "serial" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "model" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "make" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "price" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '0',
                "insured" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "assetId" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "notes" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "replacementCost" TEXT,
                "depreciationRate" REAL,
                "imageURL" TEXT,
                "secondaryPhotoURLs" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]',
                "hasUsedAI" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "createdAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                "purchaseDate" TEXT,
                "warrantyExpirationDate" TEXT,
                "purchaseLocation" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "condition" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "hasWarranty" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "attachments" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]',
                "labelIDs" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]',
                "dimensionLength" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "dimensionWidth" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "dimensionHeight" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "dimensionUnit" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'inches',
                "weightValue" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "weightUnit" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'lbs',
                "color" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "storageRequirements" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "isFragile" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "movingPriority" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 3,
                "roomDestination" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "locationID" TEXT,
                "homeID" TEXT REFERENCES "homes"("id") ON DELETE SET NULL
            ) STRICT
            """
        )
        .execute(db)

        // 6. inventoryItemLabels (join table: items <-> labels)
        try #sql(
            """
            CREATE TABLE "inventoryItemLabels" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "inventoryItemID" TEXT NOT NULL REFERENCES "inventoryItems"("id") ON DELETE CASCADE,
                "inventoryLabelID" TEXT NOT NULL REFERENCES "inventoryLabels"("id") ON DELETE CASCADE
            ) STRICT
            """
        )
        .execute(db)

        // 7. homeInsurancePolicies (join table: homes <-> policies)
        try #sql(
            """
            CREATE TABLE "homeInsurancePolicies" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "homeID" TEXT NOT NULL REFERENCES "homes"("id") ON DELETE CASCADE,
                "insurancePolicyID" TEXT NOT NULL REFERENCES "insurancePolicies"("id") ON DELETE CASCADE
            ) STRICT
            """
        )
        .execute(db)
    }

    migrator.registerMigration("Create indexes") { db in
        // Foreign key indexes
        try #sql(
            """
            CREATE INDEX "idx_inventoryLocations_homeID" ON "inventoryLocations"("homeID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_inventoryItems_locationID" ON "inventoryItems"("locationID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_inventoryItems_homeID" ON "inventoryItems"("homeID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_inventoryItemLabels_inventoryItemID" ON "inventoryItemLabels"("inventoryItemID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_inventoryItemLabels_inventoryLabelID" ON "inventoryItemLabels"("inventoryLabelID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_inventoryLabels_householdID" ON "inventoryLabels"("householdID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_homeInsurancePolicies_homeID" ON "homeInsurancePolicies"("homeID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_homeInsurancePolicies_insurancePolicyID" ON "homeInsurancePolicies"("insurancePolicyID")
            """
        )
        .execute(db)

        // Composite indexes on join tables for query performance
        // (non-unique — SyncEngine does not support unique constraints)
        try #sql(
            """
            CREATE INDEX "idx_inventoryItemLabels_composite"
                ON "inventoryItemLabels"("inventoryItemID", "inventoryLabelID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_homeInsurancePolicies_composite"
                ON "homeInsurancePolicies"("homeID", "insurancePolicyID")
            """
        )
        .execute(db)
    }

    migrator.registerMigration("Create photo tables") { db in
        try #sql(
            """
            CREATE TABLE "inventoryItemPhotos" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "inventoryItemID" TEXT NOT NULL REFERENCES "inventoryItems"("id") ON DELETE CASCADE,
                "data" BLOB NOT NULL,
                "sortOrder" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "homePhotos" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "homeID" TEXT NOT NULL REFERENCES "homes"("id") ON DELETE CASCADE,
                "data" BLOB NOT NULL,
                "sortOrder" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "inventoryLocationPhotos" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "inventoryLocationID" TEXT NOT NULL REFERENCES "inventoryLocations"("id") ON DELETE CASCADE,
                "data" BLOB NOT NULL,
                "sortOrder" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_inventoryItemPhotos_inventoryItemID"
                ON "inventoryItemPhotos"("inventoryItemID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_homePhotos_homeID"
                ON "homePhotos"("homeID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_inventoryLocationPhotos_inventoryLocationID"
                ON "inventoryLocationPhotos"("inventoryLocationID")
            """
        )
        .execute(db)
    }

    migrator.registerMigration("Drop unique indexes on join tables") { db in
        // SyncEngine does not support UNIQUE constraints on synchronized tables.
        // Replace unique indexes with regular composite indexes.
        try #sql(
            """
            DROP INDEX IF EXISTS "idx_inventoryItemLabels_unique"
            """
        )
        .execute(db)
        try #sql(
            """
            DROP INDEX IF EXISTS "idx_homeInsurancePolicies_unique"
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX IF NOT EXISTS "idx_inventoryItemLabels_composite"
                ON "inventoryItemLabels"("inventoryItemID", "inventoryLabelID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX IF NOT EXISTS "idx_homeInsurancePolicies_composite"
                ON "homeInsurancePolicies"("homeID", "insurancePolicyID")
            """
        )
        .execute(db)
    }

    migrator.registerMigration("Add household sharing tables") { db in
        try #sql(
            """
            CREATE TABLE IF NOT EXISTS "households" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "name" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "sharingEnabled" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "defaultAccessPolicy" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'allHomesShared',
                "createdAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE IF NOT EXISTS "householdMembers" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "householdID" TEXT NOT NULL REFERENCES "households"("id") ON DELETE CASCADE,
                "displayName" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "contactEmail" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "role" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'member',
                "status" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'active',
                "isCurrentUser" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "createdAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE IF NOT EXISTS "householdInvites" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "householdID" TEXT NOT NULL REFERENCES "households"("id") ON DELETE CASCADE,
                "invitedByMemberID" TEXT REFERENCES "householdMembers"("id") ON DELETE SET NULL,
                "acceptedMemberID" TEXT REFERENCES "householdMembers"("id") ON DELETE SET NULL,
                "displayName" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "email" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "role" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'member',
                "status" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'pending',
                "createdAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                "acceptedAt" TEXT
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE IF NOT EXISTS "homeAccessOverrides" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "householdID" TEXT NOT NULL REFERENCES "households"("id") ON DELETE CASCADE,
                "homeID" TEXT NOT NULL REFERENCES "homes"("id") ON DELETE CASCADE,
                "memberID" TEXT NOT NULL REFERENCES "householdMembers"("id") ON DELETE CASCADE,
                "decision" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'allow',
                "createdAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                "updatedAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX IF NOT EXISTS "idx_householdMembers_householdID"
                ON "householdMembers"("householdID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX IF NOT EXISTS "idx_householdInvites_householdID"
                ON "householdInvites"("householdID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX IF NOT EXISTS "idx_homeAccessOverrides_homeID"
                ON "homeAccessOverrides"("homeID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS "idx_homeAccessOverrides_household_home_member_unique"
                ON "homeAccessOverrides"("householdID", "homeID", "memberID")
            """
        )
        .execute(db)
    }

    migrator.registerMigration("Add household columns to homes") { db in
        let existingHomeColumns = try String.fetchAll(
            db,
            sql: "SELECT name FROM pragma_table_info('homes')"
        )

        if !existingHomeColumns.contains("householdID") {
            try #sql(
                """
                ALTER TABLE "homes" ADD COLUMN "householdID" TEXT REFERENCES "households"("id") ON DELETE SET NULL
                """
            )
            .execute(db)
        }

        if !existingHomeColumns.contains("isPrivate") {
            try #sql(
                """
                ALTER TABLE "homes" ADD COLUMN "isPrivate" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
                """
            )
            .execute(db)
        }

        try #sql(
            """
            CREATE INDEX IF NOT EXISTS "idx_homes_householdID" ON "homes"("householdID")
            """
        )
        .execute(db)

        let defaultHouseholdID: String
        if let existingID = try String.fetchOne(
            db,
            sql: "SELECT id FROM households ORDER BY createdAt ASC LIMIT 1"
        ) {
            defaultHouseholdID = existingID
        } else {
            let newID = UUID().uuidString.lowercased()
            try db.execute(
                sql:
                    """
                    INSERT INTO households (id, name, defaultAccessPolicy, createdAt)
                    VALUES (?, ?, ?, CURRENT_TIMESTAMP)
                    """,
                arguments: [newID, "My Household", HouseholdDefaultAccessPolicy.allHomesShared.rawValue]
            )
            defaultHouseholdID = newID
        }

        try db.execute(
            sql:
                """
                UPDATE homes
                SET householdID = ?
                WHERE householdID IS NULL
                """,
            arguments: [defaultHouseholdID]
        )

        let currentOwnerCount =
            try Int.fetchOne(
                db,
                sql:
                    """
                    SELECT COUNT(*)
                    FROM householdMembers
                    WHERE householdID = ?
                      AND isCurrentUser = 1
                      AND status = ?
                    """,
                arguments: [defaultHouseholdID, HouseholdMemberStatus.active.rawValue]
            ) ?? 0

        if currentOwnerCount == 0 {
            try db.execute(
                sql:
                    """
                    INSERT INTO householdMembers (
                        id, householdID, displayName, contactEmail, role, status, isCurrentUser, createdAt
                    )
                    VALUES (?, ?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP)
                    """,
                arguments: [
                    UUID().uuidString.lowercased(),
                    defaultHouseholdID,
                    "You",
                    "",
                    HouseholdMemberRole.owner.rawValue,
                    HouseholdMemberStatus.active.rawValue,
                ]
            )
        }
    }

    migrator.registerMigration("Add sharingEnabled to households") { db in
        let householdColumns = try String.fetchAll(
            db,
            sql: "SELECT name FROM pragma_table_info('households')"
        )
        if !householdColumns.contains("sharingEnabled") {
            try #sql(
                """
                ALTER TABLE "households" ADD COLUMN "sharingEnabled" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
                """
            )
            .execute(db)
        }
    }

    migrator.registerMigration("Scope labels to households") { db in
        let labelColumns = try String.fetchAll(
            db,
            sql: "SELECT name FROM pragma_table_info('inventoryLabels')"
        )
        if !labelColumns.contains("householdID") {
            try #sql(
                """
                ALTER TABLE "inventoryLabels" ADD COLUMN "householdID" TEXT
                """
            )
            .execute(db)
        }

        try #sql(
            """
            CREATE INDEX IF NOT EXISTS "idx_inventoryLabels_householdID" ON "inventoryLabels"("householdID")
            """
        )
        .execute(db)

        let defaultHouseholdID: String
        if let existingID = try String.fetchOne(
            db,
            sql: "SELECT id FROM households ORDER BY createdAt ASC LIMIT 1"
        ) {
            defaultHouseholdID = existingID
        } else {
            let newID = UUID().uuidString.lowercased()
            try db.execute(
                sql:
                    """
                    INSERT INTO households (id, name, defaultAccessPolicy, sharingEnabled, createdAt)
                    VALUES (?, ?, ?, 0, CURRENT_TIMESTAMP)
                    """,
                arguments: [newID, "My Household", HouseholdDefaultAccessPolicy.allHomesShared.rawValue]
            )
            defaultHouseholdID = newID
        }

        let ownerCount =
            try Int.fetchOne(
                db,
                sql:
                    """
                    SELECT COUNT(*)
                    FROM householdMembers
                    WHERE householdID = ?
                      AND isCurrentUser = 1
                      AND status = ?
                    """,
                arguments: [defaultHouseholdID, HouseholdMemberStatus.active.rawValue]
            ) ?? 0

        if ownerCount == 0 {
            try db.execute(
                sql:
                    """
                    INSERT INTO householdMembers (
                        id, householdID, displayName, contactEmail, role, status, isCurrentUser, createdAt
                    )
                    VALUES (?, ?, ?, ?, ?, ?, 1, CURRENT_TIMESTAMP)
                    """,
                arguments: [
                    UUID().uuidString.lowercased(),
                    defaultHouseholdID,
                    "You",
                    "",
                    HouseholdMemberRole.owner.rawValue,
                    HouseholdMemberStatus.active.rawValue,
                ]
            )
        }

        try db.execute(
            sql:
                """
                UPDATE inventoryLabels
                SET householdID = ?
                WHERE householdID IS NULL
                """,
            arguments: [defaultHouseholdID]
        )
    }

    migrator.registerMigration("Add item label IDs and decouple location relationship") { db in
        let itemColumns = try String.fetchAll(
            db,
            sql: "SELECT name FROM pragma_table_info('inventoryItems')"
        )

        if !itemColumns.contains("labelIDs") {
            try #sql(
                """
                ALTER TABLE "inventoryItems" ADD COLUMN "labelIDs" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]'
                """
            )
            .execute(db)
        }

        if itemColumns.contains("id") {
            // Best-effort backfill from join rows so label assignments survive schema transition.
            try db.execute(
                sql:
                    """
                    UPDATE inventoryItems
                    SET labelIDs = COALESCE(
                        (
                            SELECT json_group_array(inventoryLabelID)
                            FROM inventoryItemLabels
                            WHERE inventoryItemLabels.inventoryItemID = inventoryItems.id
                        ),
                        '[]'
                    )
                    WHERE labelIDs = '[]'
                       OR labelIDs IS NULL
                    """
            )
        }

        let fkColumns = try String.fetchAll(
            db,
            sql: "SELECT \"from\" FROM pragma_foreign_key_list('inventoryItems')"
        )
        let hasLocationForeignKey = fkColumns.contains { $0.lowercased() == "locationid" }

        guard hasLocationForeignKey else { return }

        try #sql(
            """
            ALTER TABLE "inventoryItems" RENAME TO "inventoryItems_old"
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "inventoryItems" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "title" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "quantityString" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '1',
                "quantityInt" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 1,
                "desc" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "serial" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "model" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "make" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "price" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '0',
                "insured" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "assetId" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "notes" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "replacementCost" TEXT,
                "depreciationRate" REAL,
                "imageURL" TEXT,
                "secondaryPhotoURLs" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]',
                "hasUsedAI" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "createdAt" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP,
                "purchaseDate" TEXT,
                "warrantyExpirationDate" TEXT,
                "purchaseLocation" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "condition" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "hasWarranty" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "attachments" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]',
                "labelIDs" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '[]',
                "dimensionLength" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "dimensionWidth" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "dimensionHeight" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "dimensionUnit" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'inches',
                "weightValue" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "weightUnit" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT 'lbs',
                "color" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "storageRequirements" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "isFragile" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
                "movingPriority" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 3,
                "roomDestination" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "locationID" TEXT,
                "homeID" TEXT REFERENCES "homes"("id") ON DELETE SET NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            INSERT INTO "inventoryItems" (
                "id",
                "title",
                "quantityString",
                "quantityInt",
                "desc",
                "serial",
                "model",
                "make",
                "price",
                "insured",
                "assetId",
                "notes",
                "replacementCost",
                "depreciationRate",
                "imageURL",
                "secondaryPhotoURLs",
                "hasUsedAI",
                "createdAt",
                "purchaseDate",
                "warrantyExpirationDate",
                "purchaseLocation",
                "condition",
                "hasWarranty",
                "attachments",
                "labelIDs",
                "dimensionLength",
                "dimensionWidth",
                "dimensionHeight",
                "dimensionUnit",
                "weightValue",
                "weightUnit",
                "color",
                "storageRequirements",
                "isFragile",
                "movingPriority",
                "roomDestination",
                "locationID",
                "homeID"
            )
            SELECT
                "id",
                "title",
                "quantityString",
                "quantityInt",
                "desc",
                "serial",
                "model",
                "make",
                "price",
                "insured",
                "assetId",
                "notes",
                "replacementCost",
                "depreciationRate",
                "imageURL",
                "secondaryPhotoURLs",
                "hasUsedAI",
                "createdAt",
                "purchaseDate",
                "warrantyExpirationDate",
                "purchaseLocation",
                "condition",
                "hasWarranty",
                "attachments",
                COALESCE("labelIDs", '[]'),
                "dimensionLength",
                "dimensionWidth",
                "dimensionHeight",
                "dimensionUnit",
                "weightValue",
                "weightUnit",
                "color",
                "storageRequirements",
                "isFragile",
                "movingPriority",
                "roomDestination",
                "locationID",
                "homeID"
            FROM "inventoryItems_old"
            """
        )
        .execute(db)

        try #sql(
            """
            DROP TABLE "inventoryItems_old"
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX IF NOT EXISTS "idx_inventoryItems_locationID" ON "inventoryItems"("locationID")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX IF NOT EXISTS "idx_inventoryItems_homeID" ON "inventoryItems"("homeID")
            """
        )
        .execute(db)
    }
}

func appDatabase() throws -> any DatabaseWriter {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true

    configuration.prepareDatabase { db in
        attachMetadatabaseIfPossible(to: db)
        #if DEBUG
            db.trace(options: .profile) {
                guard
                    !SyncEngine.isSynchronizing,
                    !$0.expandedDescription.hasPrefix("--")
                else { return }
                logger.debug("\($0.expandedDescription)")
            }
        #endif
    }

    let databasePath = try defaultSQLiteDataDatabasePath()
    do {
        try applyPendingDatabaseRestoreIfNeeded(targetDatabasePath: databasePath)
    } catch {
        logger.error("Pending restore application failed: \(error.localizedDescription)")
    }

    let database = try SQLiteData.defaultDatabase(path: databasePath, configuration: configuration)
    logger.info("Opened database at '\(database.path)'")

    var migrator = DatabaseMigrator()
    #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
    #endif

    registerMigrations(&migrator)
    try migrator.migrate(database)
    return database
}
