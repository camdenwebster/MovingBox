import Foundation
import SQLiteData

/// Creates an in-memory sqlite-data database with all migrations applied.
/// Used by unit tests via `@testable import MovingBox`.
func makeInMemoryDatabase() throws -> DatabaseQueue {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    let db = try DatabaseQueue(configuration: configuration)

    var migrator = DatabaseMigrator()
    migrator.registerMigration("Create initial tables") { db in
        try #sql(
            """
            CREATE TABLE "inventoryLabels" (
                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
                "name" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "desc" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
                "color" INTEGER,
                "emoji" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '🏷️'
            ) STRICT
            """
        )
        .execute(db)

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
                "locationID" TEXT REFERENCES "inventoryLocations"("id") ON DELETE SET NULL,
                "homeID" TEXT REFERENCES "homes"("id") ON DELETE SET NULL
            ) STRICT
            """
        )
        .execute(db)

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
    try migrator.migrate(db)
    return db
}

/// Fetches raw SQL rows from a database — used by tests for foreign key checks.
func fetchRawRows(from db: DatabaseQueue, sql: String) throws -> Int {
    try db.read { db in
        try Int.fetchOne(db, sql: "SELECT count(*) FROM (\(sql))") ?? 0
    }
}

/// Fetches table names from a database.
func fetchTableNames(from db: DatabaseQueue) throws -> [String] {
    try db.read { db in
        try String.fetchAll(
            db,
            sql:
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'grdb_%' ORDER BY name"
        )
    }
}

/// Checks if foreign key integrity passes.
func checkForeignKeyIntegrity(db: DatabaseQueue) throws -> Bool {
    try db.read { db in
        let violations = try Int.fetchOne(
            db, sql: "SELECT count(*) FROM pragma_foreign_key_check()")
        return (violations ?? 0) == 0
    }
}
