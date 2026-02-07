import Foundation
import GRDB
import OSLog
import SQLite3
import SQLiteData
import UIKit

private let logger = Logger(subsystem: "com.mothersound.movingbox", category: "Migration")

/// Reads directly from SwiftData's Core Data-backed SQLite store and writes
/// to the new sqlite-data database. Handles both production schema versions
/// (v2.1.0 with old FK columns, and post-multi-home with join tables).
struct SQLiteMigrationCoordinator {

    enum MigrationResult {
        case freshInstall
        case alreadyCompleted
        case success(stats: MigrationStats)
        case error(String)
    }

    struct MigrationStats: CustomStringConvertible {
        var labels = 0
        var homes = 0
        var policies = 0
        var locations = 0
        var items = 0
        var itemLabels = 0
        var homePolicies = 0
        var skippedItemLabels = 0
        var skippedHomePolicies = 0
        var skippedColors = 0

        var description: String {
            var parts = [
                "labels=\(labels)", "homes=\(homes)", "policies=\(policies)",
                "locations=\(locations)", "items=\(items)",
                "itemLabels=\(itemLabels)", "homePolicies=\(homePolicies)",
            ]
            if skippedItemLabels > 0 { parts.append("skippedItemLabels=\(skippedItemLabels)") }
            if skippedHomePolicies > 0 {
                parts.append("skippedHomePolicies=\(skippedHomePolicies)")
            }
            if skippedColors > 0 { parts.append("skippedColors=\(skippedColors)") }
            return parts.joined(separator: ", ")
        }
    }

    private static let migrationCompleteKey = "com.mothersound.movingbox.sqlitedata.migration.complete"
    private static let migrationAttemptsKey = "com.mothersound.movingbox.sqlitedata.migration.attempts"
    private static let maxMigrationAttempts = 3

    // MARK: - Public API

    static func migrateIfNeeded(database: any DatabaseWriter) -> MigrationResult {
        guard !UserDefaults.standard.bool(forKey: migrationCompleteKey) else {
            return .alreadyCompleted
        }

        // Bail out after repeated failures to avoid infinite retry loops.
        // Do NOT mark complete here — the old SwiftData store is preserved so a
        // future app update can reset the attempt counter and retry successfully.
        let attempts = UserDefaults.standard.integer(forKey: migrationAttemptsKey)
        if attempts >= maxMigrationAttempts {
            let msg = "Migration abandoned after \(attempts) failed attempts"
            logger.error("\(msg)")
            return .error(msg)
        }
        UserDefaults.standard.set(attempts + 1, forKey: migrationAttemptsKey)

        let storePath = swiftDataStorePath()
        guard FileManager.default.fileExists(atPath: storePath) else {
            logger.info("No SwiftData store found — fresh install")
            markComplete()
            UserDefaults.standard.removeObject(forKey: migrationAttemptsKey)
            return .freshInstall
        }

        // Open old database read-only
        var oldDB: OpaquePointer?
        guard sqlite3_open_v2(storePath, &oldDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let msg = "Failed to open SwiftData store at \(storePath)"
            logger.error("\(msg)")
            return .error(msg)
        }
        defer { sqlite3_close(oldDB) }

        // Verify the Core Data tables exist
        guard tableExists(db: oldDB, table: "ZINVENTORYITEM") else {
            logger.info("No Core Data tables found — marking migration complete")
            markComplete()
            UserDefaults.standard.removeObject(forKey: migrationAttemptsKey)
            return .freshInstall
        }

        logger.info("Starting SwiftData → sqlite-data migration")

        do {
            let stats = try performMigration(from: oldDB, to: database)

            // Sanity check: onboarding always creates at least one home, so a
            // non-empty SwiftData store that yields zero homes indicates a read
            // failure (wrong schema, corrupted file, etc.). Bail before we
            // archive the old store so a retry can succeed.
            if stats.homes == 0 {
                let msg = "Migration produced zero homes from non-empty store — aborting"
                logger.error("\(msg)")
                return .error(msg)
            }

            try validate(database: database, expected: stats)
            archiveOldStore()
            markComplete()
            UserDefaults.standard.removeObject(forKey: migrationAttemptsKey)
            logger.info("Migration succeeded: \(stats.description)")
            return .success(stats: stats)
        } catch {
            logger.error("Migration failed: \(error.localizedDescription)")
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Migration Core

    private static func performMigration(
        from oldDB: OpaquePointer?,
        to database: any DatabaseWriter
    ) throws -> MigrationStats {
        var stats = MigrationStats()

        // Detect schema version
        let hasOldLabelFK = columnExists(db: oldDB, table: "ZINVENTORYITEM", column: "ZLABEL")
        let hasOldInsuranceFK = columnExists(db: oldDB, table: "ZHOME", column: "ZINSURANCEPOLICY")
        let hasLabelJoinTable = tableExists(db: oldDB, table: "Z_2LABELS")
        let hasInsuranceJoinTable = tableExists(db: oldDB, table: "Z_1INSURANCEPOLICIES")
        let hasLocationHomeFK = columnExists(db: oldDB, table: "ZINVENTORYLOCATION", column: "ZHOME")
        let hasItemHomeFK = columnExists(db: oldDB, table: "ZINVENTORYITEM", column: "ZHOME")

        logger.info(
            "Schema detection: oldLabelFK=\(hasOldLabelFK), oldInsuranceFK=\(hasOldInsuranceFK), labelJoinTable=\(hasLabelJoinTable), insuranceJoinTable=\(hasInsuranceJoinTable), locationHomeFK=\(hasLocationHomeFK), itemHomeFK=\(hasItemHomeFK)"
        )

        // Read all data from old database
        var labelZPKMap: [Int64: UUID] = [:]
        var homeZPKMap: [Int64: UUID] = [:]
        var policyZPKMap: [Int64: UUID] = [:]
        var locationZPKMap: [Int64: UUID] = [:]
        var itemZPKMap: [Int64: UUID] = [:]

        var skippedColors = 0
        let labels = readLabels(db: oldDB, zpkMap: &labelZPKMap, skippedColors: &skippedColors)
        let homes = readHomes(db: oldDB, zpkMap: &homeZPKMap)
        let policies = readPolicies(db: oldDB, zpkMap: &policyZPKMap)
        let locations = readLocations(db: oldDB, zpkMap: &locationZPKMap)
        let items = readItems(db: oldDB, zpkMap: &itemZPKMap)

        // Read relationships
        let itemLabelPairs = readItemLabelRelationships(
            db: oldDB, hasOldFK: hasOldLabelFK, hasJoinTable: hasLabelJoinTable)
        let homePolicyPairs = readHomePolicyRelationships(
            db: oldDB, hasOldFK: hasOldInsuranceFK, hasJoinTable: hasInsuranceJoinTable)
        var locationHomeMap = readLocationHomeRelationships(db: oldDB)
        let itemLocationMap = readItemLocationRelationships(db: oldDB)
        var itemHomeMap = readItemHomeRelationships(db: oldDB)

        // Backfill: items without a direct home FK but with a location that has a
        // known home should inherit that home. This handles post-multi-home schemas
        // where the item's ZHOME column is NULL but ZLOCATION points to a homed location.
        var backfilledItemHomes = 0
        for item in items {
            if itemHomeMap[item.zpk] == nil,
                let locZPK = itemLocationMap[item.zpk],
                let homeZPK = locationHomeMap[locZPK]
            {
                itemHomeMap[item.zpk] = homeZPK
                backfilledItemHomes += 1
            }
        }
        if backfilledItemHomes > 0 {
            logger.info("Backfilled homeID for \(backfilledItemHomes) items from their location")
        }

        // Pre-multi-home fallback: v2.1.0 had no ZHOME FK on locations/items.
        // All locations and items implicitly belonged to the single visible home.
        // Pre-2.2.0 onboarding re-runs may have created phantom homes, so there
        // can be multiple homes even in the old schema. Pick the "real" home
        // (first with a non-empty name) or fall back to the last-created one.
        if !hasLocationHomeFK && !homes.isEmpty && !locations.isEmpty {
            let activeHomeZPK = bestHomeZPK(from: homes)
            for location in locations {
                locationHomeMap[location.zpk] = activeHomeZPK
            }
            logger.info("Pre-multi-home schema: assigned \(locations.count) locations to home ZPK=\(activeHomeZPK)")
        }
        if !hasItemHomeFK && !homes.isEmpty && !items.isEmpty {
            let activeHomeZPK = bestHomeZPK(from: homes)
            for item in items {
                itemHomeMap[item.zpk] = activeHomeZPK
            }
            logger.info("Pre-multi-home schema: assigned \(items.count) items to home ZPK=\(activeHomeZPK)")
        }

        // Write everything in a single transaction
        try database.write { db in
            // 1. Labels
            for label in labels {
                try db.execute(
                    sql: """
                        INSERT INTO "inventoryLabels" ("id", "name", "desc", "color", "emoji")
                        VALUES (?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        label.uuid.uuidString.lowercased(),
                        label.name,
                        label.desc,
                        label.colorHex,
                        label.emoji,
                    ])
            }
            stats.labels = labels.count
            stats.skippedColors = skippedColors

            // 2. Homes
            for home in homes {
                try db.execute(
                    sql: """
                        INSERT INTO "homes" ("id", "name", "address1", "address2", "city", "state", "zip", "country",
                            "purchaseDate", "purchasePrice", "imageURL", "secondaryPhotoURLs", "isPrimary", "colorName")
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        home.uuid.uuidString.lowercased(),
                        home.name,
                        home.address1,
                        home.address2,
                        home.city,
                        home.state,
                        home.zip,
                        home.country,
                        home.purchaseDate.iso8601String,
                        "\(home.purchasePrice)",
                        home.imageURL,
                        home.secondaryPhotoURLsJSON,
                        home.isPrimary,
                        home.colorName,
                    ])
            }
            stats.homes = homes.count

            // 3. Insurance Policies
            for policy in policies {
                try db.execute(
                    sql: """
                        INSERT INTO "insurancePolicies" ("id", "providerName", "policyNumber",
                            "deductibleAmount", "dwellingCoverageAmount", "personalPropertyCoverageAmount",
                            "lossOfUseCoverageAmount", "liabilityCoverageAmount", "medicalPaymentsCoverageAmount",
                            "startDate", "endDate")
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        policy.uuid.uuidString.lowercased(),
                        policy.providerName,
                        policy.policyNumber,
                        "\(policy.deductibleAmount)",
                        "\(policy.dwellingCoverageAmount)",
                        "\(policy.personalPropertyCoverageAmount)",
                        "\(policy.lossOfUseCoverageAmount)",
                        "\(policy.liabilityCoverageAmount)",
                        "\(policy.medicalPaymentsCoverageAmount)",
                        policy.startDate.iso8601String,
                        policy.endDate.iso8601String,
                    ])
            }
            stats.policies = policies.count

            // 4. Locations (resolve homeID via Z_PK map)
            for location in locations {
                let homeUUID: String? =
                    if let homeZPK = locationHomeMap[location.zpk] {
                        homeZPKMap[homeZPK]?.uuidString.lowercased()
                    } else {
                        nil
                    }

                try db.execute(
                    sql: """
                        INSERT INTO "inventoryLocations" ("id", "name", "desc", "sfSymbolName", "imageURL",
                            "secondaryPhotoURLs", "homeID")
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        location.uuid.uuidString.lowercased(),
                        location.name,
                        location.desc,
                        location.sfSymbolName,
                        location.imageURL,
                        location.secondaryPhotoURLsJSON,
                        homeUUID,
                    ])
            }
            stats.locations = locations.count

            // 5. Items (resolve locationID and homeID via Z_PK maps)
            for item in items {
                let locationUUID: String? =
                    if let locZPK = itemLocationMap[item.zpk] {
                        locationZPKMap[locZPK]?.uuidString.lowercased()
                    } else {
                        nil
                    }

                let homeUUID: String? =
                    if let homeZPK = itemHomeMap[item.zpk] {
                        homeZPKMap[homeZPK]?.uuidString.lowercased()
                    } else {
                        nil
                    }

                try db.execute(
                    sql: """
                        INSERT INTO "inventoryItems" ("id", "title", "quantityString", "quantityInt", "desc", "serial",
                            "model", "make", "price", "insured", "assetId", "notes", "replacementCost", "depreciationRate",
                            "imageURL", "secondaryPhotoURLs", "hasUsedAI", "createdAt", "purchaseDate",
                            "warrantyExpirationDate", "purchaseLocation", "condition", "hasWarranty", "attachments",
                            "dimensionLength", "dimensionWidth", "dimensionHeight", "dimensionUnit", "weightValue",
                            "weightUnit", "color", "storageRequirements", "isFragile", "movingPriority", "roomDestination",
                            "locationID", "homeID")
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        item.uuid.uuidString.lowercased(),
                        item.title,
                        item.quantityString,
                        item.quantityInt,
                        item.desc,
                        item.serial,
                        item.model,
                        item.make,
                        "\(item.price)",
                        item.insured,
                        item.assetId,
                        item.notes,
                        item.replacementCost.map { "\($0)" },
                        item.depreciationRate,
                        item.imageURL,
                        item.secondaryPhotoURLsJSON,
                        item.hasUsedAI,
                        item.createdAt.iso8601String,
                        item.purchaseDate?.iso8601String,
                        item.warrantyExpirationDate?.iso8601String,
                        item.purchaseLocation,
                        item.condition,
                        item.hasWarranty,
                        item.attachmentsJSON,
                        item.dimensionLength,
                        item.dimensionWidth,
                        item.dimensionHeight,
                        item.dimensionUnit,
                        item.weightValue,
                        item.weightUnit,
                        item.color,
                        item.storageRequirements,
                        item.isFragile,
                        item.movingPriority,
                        item.roomDestination,
                        locationUUID,
                        homeUUID,
                    ])
            }
            stats.items = items.count

            // 6. Item-Label join entries
            for (itemZPK, labelZPK) in itemLabelPairs {
                guard let itemUUID = itemZPKMap[itemZPK],
                    let labelUUID = labelZPKMap[labelZPK]
                else {
                    logger.warning(
                        "Skipping orphaned item-label pair: item=\(itemZPK), label=\(labelZPK)")
                    stats.skippedItemLabels += 1
                    continue
                }

                try db.execute(
                    sql: """
                        INSERT INTO "inventoryItemLabels" ("id", "inventoryItemID", "inventoryLabelID")
                        VALUES (?, ?, ?)
                        """,
                    arguments: [
                        UUID().uuidString.lowercased(),
                        itemUUID.uuidString.lowercased(),
                        labelUUID.uuidString.lowercased(),
                    ])
                stats.itemLabels += 1
            }

            // 7. Home-Policy join entries
            for (homeZPK, policyZPK) in homePolicyPairs {
                guard let homeUUID = homeZPKMap[homeZPK],
                    let policyUUID = policyZPKMap[policyZPK]
                else {
                    logger.warning(
                        "Skipping orphaned home-policy pair: home=\(homeZPK), policy=\(policyZPK)")
                    stats.skippedHomePolicies += 1
                    continue
                }

                try db.execute(
                    sql: """
                        INSERT INTO "homeInsurancePolicies" ("id", "homeID", "insurancePolicyID")
                        VALUES (?, ?, ?)
                        """,
                    arguments: [
                        UUID().uuidString.lowercased(),
                        homeUUID.uuidString.lowercased(),
                        policyUUID.uuidString.lowercased(),
                    ])
                stats.homePolicies += 1
            }
        }

        return stats
    }

    // MARK: - Reading Labels

    private struct RawLabel {
        let zpk: Int64
        let uuid: UUID
        let name: String
        let desc: String
        let colorHex: Int64?
        let emoji: String
    }

    private static func readLabels(
        db: OpaquePointer?, zpkMap: inout [Int64: UUID], skippedColors: inout Int
    ) -> [RawLabel] {
        let hasUUID = columnExists(db: db, table: "ZINVENTORYLABEL", column: "ZID")
        let hasEmoji = columnExists(db: db, table: "ZINVENTORYLABEL", column: "ZEMOJI")
        let hasDesc = columnExists(db: db, table: "ZINVENTORYLABEL", column: "ZDESC")

        let uuidCol = hasUUID ? "ZID" : "NULL"
        let emojiCol = hasEmoji ? "ZEMOJI" : "NULL"
        let descCol = hasDesc ? "ZDESC" : "NULL"

        let query =
            "SELECT Z_PK, \(uuidCol), ZNAME, \(descCol), ZCOLOR, \(emojiCol) FROM ZINVENTORYLABEL"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            logPrepareError(db: db, context: "readLabels")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var results: [RawLabel] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let zpk = sqlite3_column_int64(stmt, 0)
            let uuid = resolveUUID(stmt: stmt, column: 1, zpk: zpk, map: &zpkMap)

            let name = readString(stmt: stmt, column: 2)
            let desc = readString(stmt: stmt, column: 3)

            // UIColor BLOB → hex integer (with fallback gray on deserialization failure)
            let colorHex = deserializeColorBlob(stmt: stmt, column: 4, skippedColors: &skippedColors)

            let emoji = readOptionalString(stmt: stmt, column: 5) ?? "🏷️"

            results.append(
                RawLabel(
                    zpk: zpk, uuid: uuid, name: name, desc: desc, colorHex: colorHex,
                    emoji: emoji))
        }

        logger.info("Read \(results.count) labels from SwiftData store")
        return results
    }

    // MARK: - Reading Homes

    private struct RawHome {
        let zpk: Int64
        let uuid: UUID
        let name: String
        let address1: String
        let address2: String
        let city: String
        let state: String
        let zip: String
        let country: String
        let purchaseDate: Date
        let purchasePrice: Decimal
        let imageURL: String?
        let secondaryPhotoURLsJSON: String
        let isPrimary: Bool
        let colorName: String
    }

    private static func readHomes(db: OpaquePointer?, zpkMap: inout [Int64: UUID]) -> [RawHome] {
        let hasUUID = columnExists(db: db, table: "ZHOME", column: "ZID")
        let hasPrimary = columnExists(db: db, table: "ZHOME", column: "ZISPRIMARY")
        let hasColor = columnExists(db: db, table: "ZHOME", column: "ZCOLORNAME")

        let uuidCol = hasUUID ? "ZID" : "NULL"
        let primaryCol = hasPrimary ? "ZISPRIMARY" : "1"  // v2.1.0: single home is always primary
        let colorCol = hasColor ? "ZCOLORNAME" : "NULL"  // defaults to "green" below
        let query = """
            SELECT Z_PK, \(uuidCol), ZNAME, ZADDRESS1, ZADDRESS2, ZCITY, ZSTATE, ZZIP, ZCOUNTRY,
                ZPURCHASEDATE, ZPURCHASEPRICE, ZIMAGEURL, ZSECONDARYPHOTOURLS, \(primaryCol), \(colorCol)
            FROM ZHOME
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            logPrepareError(db: db, context: "readHomes")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var results: [RawHome] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let zpk = sqlite3_column_int64(stmt, 0)
            let uuid = resolveUUID(stmt: stmt, column: 1, zpk: zpk, map: &zpkMap)

            let purchaseDate = readCoreDataDate(stmt: stmt, column: 9)
            let purchasePrice = readDecimal(stmt: stmt, column: 10)

            results.append(
                RawHome(
                    zpk: zpk, uuid: uuid,
                    name: readString(stmt: stmt, column: 2),
                    address1: readString(stmt: stmt, column: 3),
                    address2: readString(stmt: stmt, column: 4),
                    city: readString(stmt: stmt, column: 5),
                    state: readString(stmt: stmt, column: 6),
                    zip: readString(stmt: stmt, column: 7),
                    country: readString(stmt: stmt, column: 8),
                    purchaseDate: purchaseDate,
                    purchasePrice: purchasePrice,
                    imageURL: readOptionalString(stmt: stmt, column: 11),
                    secondaryPhotoURLsJSON: readCodableArrayJSON(stmt: stmt, column: 12),
                    isPrimary: sqlite3_column_int(stmt, 13) != 0,
                    colorName: readOptionalString(stmt: stmt, column: 14) ?? "green"
                ))
        }

        logger.info("Read \(results.count) homes from SwiftData store")
        return results
    }

    /// Picks the "real" home from a list that may contain phantom homes from
    /// pre-2.2.0 onboarding re-runs. A home is considered user-customized if
    /// it has a non-default name, address, or photo. Falls back to the
    /// last-created home (highest Z_PK), matching pre-2.2.0 `homes.last` behavior.
    private static func bestHomeZPK(from homes: [RawHome]) -> Int64 {
        homes.first(where: { home in
            (!home.name.isEmpty && home.name != "My Home")
                || !home.address1.isEmpty || !home.city.isEmpty || home.imageURL != nil
        })?.zpk ?? homes.map(\.zpk).max() ?? homes[0].zpk
    }

    // MARK: - Reading Insurance Policies

    private struct RawPolicy {
        let zpk: Int64
        let uuid: UUID
        let providerName: String
        let policyNumber: String
        let deductibleAmount: Decimal
        let dwellingCoverageAmount: Decimal
        let personalPropertyCoverageAmount: Decimal
        let lossOfUseCoverageAmount: Decimal
        let liabilityCoverageAmount: Decimal
        let medicalPaymentsCoverageAmount: Decimal
        let startDate: Date
        let endDate: Date
    }

    private static func readPolicies(db: OpaquePointer?, zpkMap: inout [Int64: UUID]) -> [RawPolicy] {
        guard tableExists(db: db, table: "ZINSURANCEPOLICY") else { return [] }

        let hasUUID = columnExists(db: db, table: "ZINSURANCEPOLICY", column: "ZID")
        let uuidCol = hasUUID ? "ZID" : "NULL"

        let query = """
            SELECT Z_PK, \(uuidCol), ZPROVIDERNAME, ZPOLICYNUMBER,
                ZDEDUCTIBLEAMOUNT, ZDWELLINGCOVERAGEAMOUNT, ZPERSONALPROPERTYCOVERAGEAMOUNT,
                ZLOSSOFUSECOVERAGEAMOUNT, ZLIABILITYCOVERAGEAMOUNT, ZMEDICALPAYMENTSCOVERAGEAMOUNT,
                ZSTARTDATE, ZENDDATE
            FROM ZINSURANCEPOLICY
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            logPrepareError(db: db, context: "readPolicies")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var results: [RawPolicy] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let zpk = sqlite3_column_int64(stmt, 0)
            let uuid = resolveUUID(stmt: stmt, column: 1, zpk: zpk, map: &zpkMap)

            results.append(
                RawPolicy(
                    zpk: zpk, uuid: uuid,
                    providerName: readString(stmt: stmt, column: 2),
                    policyNumber: readString(stmt: stmt, column: 3),
                    deductibleAmount: readDecimal(stmt: stmt, column: 4),
                    dwellingCoverageAmount: readDecimal(stmt: stmt, column: 5),
                    personalPropertyCoverageAmount: readDecimal(stmt: stmt, column: 6),
                    lossOfUseCoverageAmount: readDecimal(stmt: stmt, column: 7),
                    liabilityCoverageAmount: readDecimal(stmt: stmt, column: 8),
                    medicalPaymentsCoverageAmount: readDecimal(stmt: stmt, column: 9),
                    startDate: readCoreDataDate(stmt: stmt, column: 10),
                    endDate: readCoreDataDate(stmt: stmt, column: 11)
                ))
        }

        logger.info("Read \(results.count) insurance policies from SwiftData store")
        return results
    }

    // MARK: - Reading Locations

    private struct RawLocation {
        let zpk: Int64
        let uuid: UUID
        let name: String
        let desc: String
        let sfSymbolName: String?
        let imageURL: String?
        let secondaryPhotoURLsJSON: String
    }

    private static func readLocations(db: OpaquePointer?, zpkMap: inout [Int64: UUID])
        -> [RawLocation]
    {
        let hasUUID = columnExists(db: db, table: "ZINVENTORYLOCATION", column: "ZID")
        let hasSFSymbol = columnExists(
            db: db, table: "ZINVENTORYLOCATION", column: "ZSFSYMBOLNAME")

        let uuidCol = hasUUID ? "ZID" : "NULL"
        let sfCol = hasSFSymbol ? "ZSFSYMBOLNAME" : "NULL"

        let query = """
            SELECT Z_PK, \(uuidCol), ZNAME, ZDESC, \(sfCol), ZIMAGEURL, ZSECONDARYPHOTOURLS
            FROM ZINVENTORYLOCATION
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            logPrepareError(db: db, context: "readLocations")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var results: [RawLocation] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let zpk = sqlite3_column_int64(stmt, 0)
            let uuid = resolveUUID(stmt: stmt, column: 1, zpk: zpk, map: &zpkMap)

            results.append(
                RawLocation(
                    zpk: zpk, uuid: uuid,
                    name: readString(stmt: stmt, column: 2),
                    desc: readString(stmt: stmt, column: 3),
                    sfSymbolName: readOptionalString(stmt: stmt, column: 4),
                    imageURL: readOptionalString(stmt: stmt, column: 5),
                    secondaryPhotoURLsJSON: readCodableArrayJSON(stmt: stmt, column: 6)
                ))
        }

        logger.info("Read \(results.count) locations from SwiftData store")
        return results
    }

    // MARK: - Reading Items

    private struct RawItem {
        let zpk: Int64
        let uuid: UUID
        let title: String
        let quantityString: String
        let quantityInt: Int
        let desc: String
        let serial: String
        let model: String
        let make: String
        let price: Decimal
        let insured: Bool
        let assetId: String
        let notes: String
        let replacementCost: Decimal?
        let depreciationRate: Double?
        let imageURL: String?
        let secondaryPhotoURLsJSON: String
        let hasUsedAI: Bool
        let createdAt: Date
        let purchaseDate: Date?
        let warrantyExpirationDate: Date?
        let purchaseLocation: String
        let condition: String
        let hasWarranty: Bool
        let attachmentsJSON: String
        let dimensionLength: String
        let dimensionWidth: String
        let dimensionHeight: String
        let dimensionUnit: String
        let weightValue: String
        let weightUnit: String
        let color: String
        let storageRequirements: String
        let isFragile: Bool
        let movingPriority: Int
        let roomDestination: String
    }

    private static func readItems(db: OpaquePointer?, zpkMap: inout [Int64: UUID]) -> [RawItem] {
        let hasUUID = columnExists(db: db, table: "ZINVENTORYITEM", column: "ZID")
        let uuidCol = hasUUID ? "ZID" : "NULL"

        // Build column list, checking for columns that may not exist in older schemas
        let hasReplacementCost = columnExists(
            db: db, table: "ZINVENTORYITEM", column: "ZREPLACEMENTCOST")
        let hasDepreciation = columnExists(
            db: db, table: "ZINVENTORYITEM", column: "ZDEPRECIATIONRATE")
        let hasAttachments = columnExists(db: db, table: "ZINVENTORYITEM", column: "ZATTACHMENTS")
        let hasDimensions = columnExists(
            db: db, table: "ZINVENTORYITEM", column: "ZDIMENSIONLENGTH")
        let hasWeight = columnExists(db: db, table: "ZINVENTORYITEM", column: "ZWEIGHTVALUE")
        let hasColor = columnExists(db: db, table: "ZINVENTORYITEM", column: "ZCOLOR")
        let hasStorage = columnExists(
            db: db, table: "ZINVENTORYITEM", column: "ZSTORAGEREQUIREMENTS")
        let hasFragile = columnExists(db: db, table: "ZINVENTORYITEM", column: "ZISFRAGILE")
        let hasMovingPriority = columnExists(
            db: db, table: "ZINVENTORYITEM", column: "ZMOVINGPRIORITY")
        let hasRoomDest = columnExists(
            db: db, table: "ZINVENTORYITEM", column: "ZROOMDESTINATION")
        let hasPurchaseDate = columnExists(
            db: db, table: "ZINVENTORYITEM", column: "ZPURCHASEDATE")
        let hasWarrantyExp = columnExists(
            db: db, table: "ZINVENTORYITEM", column: "ZWARRANTYEXPIRATIONDATE")
        let hasPurchaseLocation = columnExists(
            db: db, table: "ZINVENTORYITEM", column: "ZPURCHASELOCATION")
        let hasCondition = columnExists(db: db, table: "ZINVENTORYITEM", column: "ZCONDITION")
        let hasWarranty = columnExists(db: db, table: "ZINVENTORYITEM", column: "ZHASWARRANTY")

        let query = """
            SELECT Z_PK, \(uuidCol), ZTITLE, ZQUANTITYSTRING, ZQUANTITYINT, ZDESC, ZSERIAL,
                ZMODEL, ZMAKE, ZPRICE, ZINSURED, ZASSETID, ZNOTES,
                \(hasReplacementCost ? "ZREPLACEMENTCOST" : "NULL"),
                \(hasDepreciation ? "ZDEPRECIATIONRATE" : "NULL"),
                ZIMAGEURL, ZSECONDARYPHOTOURLS, ZHASUSEDAI, ZCREATEDAT,
                \(hasPurchaseDate ? "ZPURCHASEDATE" : "NULL"),
                \(hasWarrantyExp ? "ZWARRANTYEXPIRATIONDATE" : "NULL"),
                \(hasPurchaseLocation ? "ZPURCHASELOCATION" : "NULL"),
                \(hasCondition ? "ZCONDITION" : "NULL"),
                \(hasWarranty ? "ZHASWARRANTY" : "NULL"),
                \(hasAttachments ? "ZATTACHMENTS" : "NULL"),
                \(hasDimensions ? "ZDIMENSIONLENGTH" : "NULL"),
                \(hasDimensions ? "ZDIMENSIONWIDTH" : "NULL"),
                \(hasDimensions ? "ZDIMENSIONHEIGHT" : "NULL"),
                \(hasDimensions ? "ZDIMENSIONUNIT" : "NULL"),
                \(hasWeight ? "ZWEIGHTVALUE" : "NULL"),
                \(hasWeight ? "ZWEIGHTUNIT" : "NULL"),
                \(hasColor ? "ZCOLOR" : "NULL"),
                \(hasStorage ? "ZSTORAGEREQUIREMENTS" : "NULL"),
                \(hasFragile ? "ZISFRAGILE" : "NULL"),
                \(hasMovingPriority ? "ZMOVINGPRIORITY" : "NULL"),
                \(hasRoomDest ? "ZROOMDESTINATION" : "NULL")
            FROM ZINVENTORYITEM
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            logPrepareError(db: db, context: "readItems")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var results: [RawItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let zpk = sqlite3_column_int64(stmt, 0)
            let uuid = resolveUUID(stmt: stmt, column: 1, zpk: zpk, map: &zpkMap)

            let replacementCost: Decimal? =
                sqlite3_column_type(stmt, 13) != SQLITE_NULL
                ? readDecimal(stmt: stmt, column: 13) : nil

            let depreciationRate: Double? =
                sqlite3_column_type(stmt, 14) != SQLITE_NULL
                ? sqlite3_column_double(stmt, 14) : nil

            let purchaseDate: Date? =
                sqlite3_column_type(stmt, 19) != SQLITE_NULL
                ? readCoreDataDate(stmt: stmt, column: 19) : nil

            let warrantyExp: Date? =
                sqlite3_column_type(stmt, 20) != SQLITE_NULL
                ? readCoreDataDate(stmt: stmt, column: 20) : nil

            results.append(
                RawItem(
                    zpk: zpk, uuid: uuid,
                    title: readString(stmt: stmt, column: 2),
                    quantityString: readOptionalString(stmt: stmt, column: 3) ?? "1",
                    quantityInt: Int(sqlite3_column_int(stmt, 4)),
                    desc: readString(stmt: stmt, column: 5),
                    serial: readString(stmt: stmt, column: 6),
                    model: readString(stmt: stmt, column: 7),
                    make: readString(stmt: stmt, column: 8),
                    price: readDecimal(stmt: stmt, column: 9),
                    insured: sqlite3_column_int(stmt, 10) != 0,
                    assetId: readString(stmt: stmt, column: 11),
                    notes: readString(stmt: stmt, column: 12),
                    replacementCost: replacementCost,
                    depreciationRate: depreciationRate,
                    imageURL: readOptionalString(stmt: stmt, column: 15),
                    secondaryPhotoURLsJSON: readCodableArrayJSON(stmt: stmt, column: 16),
                    hasUsedAI: sqlite3_column_int(stmt, 17) != 0,
                    createdAt: readCoreDataDate(stmt: stmt, column: 18),
                    purchaseDate: purchaseDate,
                    warrantyExpirationDate: warrantyExp,
                    purchaseLocation: readString(stmt: stmt, column: 21),
                    condition: readString(stmt: stmt, column: 22),
                    hasWarranty: sqlite3_column_type(stmt, 23) != SQLITE_NULL
                        && sqlite3_column_int(stmt, 23) != 0,
                    attachmentsJSON: readAttachmentsPlistJSON(stmt: stmt, column: 24),
                    dimensionLength: readString(stmt: stmt, column: 25),
                    dimensionWidth: readString(stmt: stmt, column: 26),
                    dimensionHeight: readString(stmt: stmt, column: 27),
                    dimensionUnit: readOptionalString(stmt: stmt, column: 28) ?? "inches",
                    weightValue: readString(stmt: stmt, column: 29),
                    weightUnit: readOptionalString(stmt: stmt, column: 30) ?? "lbs",
                    color: readString(stmt: stmt, column: 31),
                    storageRequirements: readString(stmt: stmt, column: 32),
                    isFragile: sqlite3_column_type(stmt, 33) != SQLITE_NULL
                        && sqlite3_column_int(stmt, 33) != 0,
                    movingPriority: sqlite3_column_type(stmt, 34) != SQLITE_NULL
                        ? Int(sqlite3_column_int(stmt, 34)) : 3,
                    roomDestination: readString(stmt: stmt, column: 35)
                ))
        }

        logger.info("Read \(results.count) items from SwiftData store")
        return results
    }

    // MARK: - Reading Relationships

    /// Returns array of (itemZPK, labelZPK) pairs
    private static func readItemLabelRelationships(
        db: OpaquePointer?, hasOldFK: Bool, hasJoinTable: Bool
    ) -> [(Int64, Int64)] {
        if hasOldFK {
            // v2.1.0: single FK column ZINVENTORYITEM.ZLABEL
            let query =
                "SELECT Z_PK, ZLABEL FROM ZINVENTORYITEM WHERE ZLABEL IS NOT NULL"
            return readPairs(db: db, query: query)
        } else if hasJoinTable {
            // Post-multi-home: join table Z_2LABELS
            let query = "SELECT Z_2INVENTORYITEMS, Z_3LABELS FROM Z_2LABELS"
            return readPairs(db: db, query: query)
        }
        return []
    }

    /// Returns array of (homeZPK, policyZPK) pairs
    private static func readHomePolicyRelationships(
        db: OpaquePointer?, hasOldFK: Bool, hasJoinTable: Bool
    ) -> [(Int64, Int64)] {
        if hasOldFK {
            let query =
                "SELECT Z_PK, ZINSURANCEPOLICY FROM ZHOME WHERE ZINSURANCEPOLICY IS NOT NULL"
            return readPairs(db: db, query: query)
        } else if hasJoinTable {
            let query = "SELECT Z_1HOMES, Z_2INSURANCEPOLICIES FROM Z_1INSURANCEPOLICIES"
            return readPairs(db: db, query: query)
        }
        return []
    }

    /// Returns map of locationZPK → homeZPK
    private static func readLocationHomeRelationships(db: OpaquePointer?) -> [Int64: Int64] {
        guard columnExists(db: db, table: "ZINVENTORYLOCATION", column: "ZHOME") else { return [:] }
        let query =
            "SELECT Z_PK, ZHOME FROM ZINVENTORYLOCATION WHERE ZHOME IS NOT NULL"
        var result: [Int64: Int64] = [:]
        for (locZPK, homeZPK) in readPairs(db: db, query: query) {
            result[locZPK] = homeZPK
        }
        return result
    }

    /// Returns map of itemZPK → locationZPK
    private static func readItemLocationRelationships(db: OpaquePointer?) -> [Int64: Int64] {
        let query =
            "SELECT Z_PK, ZLOCATION FROM ZINVENTORYITEM WHERE ZLOCATION IS NOT NULL"
        var result: [Int64: Int64] = [:]
        for (itemZPK, locZPK) in readPairs(db: db, query: query) {
            result[itemZPK] = locZPK
        }
        return result
    }

    /// Returns map of itemZPK → homeZPK
    private static func readItemHomeRelationships(db: OpaquePointer?) -> [Int64: Int64] {
        guard columnExists(db: db, table: "ZINVENTORYITEM", column: "ZHOME") else { return [:] }
        let query =
            "SELECT Z_PK, ZHOME FROM ZINVENTORYITEM WHERE ZHOME IS NOT NULL"
        var result: [Int64: Int64] = [:]
        for (itemZPK, homeZPK) in readPairs(db: db, query: query) {
            result[itemZPK] = homeZPK
        }
        return result
    }

    // MARK: - Validation

    private static func validate(database: any DatabaseWriter, expected: MigrationStats) throws {
        try database.read { db in
            let labelCount =
                try Int.fetchOne(
                    db, sql: "SELECT COUNT(*) FROM inventoryLabels") ?? 0
            let homeCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM homes") ?? 0
            let policyCount =
                try Int.fetchOne(
                    db, sql: "SELECT COUNT(*) FROM insurancePolicies") ?? 0
            let locationCount =
                try Int.fetchOne(
                    db, sql: "SELECT COUNT(*) FROM inventoryLocations") ?? 0
            let itemCount =
                try Int.fetchOne(
                    db, sql: "SELECT COUNT(*) FROM inventoryItems") ?? 0

            guard labelCount == expected.labels else {
                throw MigrationError.countMismatch(
                    table: "inventoryLabels", expected: expected.labels, actual: labelCount)
            }
            guard homeCount == expected.homes else {
                throw MigrationError.countMismatch(
                    table: "homes", expected: expected.homes, actual: homeCount)
            }
            guard policyCount == expected.policies else {
                throw MigrationError.countMismatch(
                    table: "insurancePolicies", expected: expected.policies, actual: policyCount)
            }
            guard locationCount == expected.locations else {
                throw MigrationError.countMismatch(
                    table: "inventoryLocations", expected: expected.locations, actual: locationCount)
            }
            guard itemCount == expected.items else {
                throw MigrationError.countMismatch(
                    table: "inventoryItems", expected: expected.items, actual: itemCount)
            }

            // Verify FK integrity
            let fkViolations = try Row.fetchAll(db, sql: "PRAGMA foreign_key_check")
            guard fkViolations.isEmpty else {
                throw MigrationError.foreignKeyViolation(
                    count: fkViolations.count)
            }
        }

        logger.info("Migration validation passed")
    }

    // MARK: - Completion & Backup

    private static func archiveOldStore() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let backupDir = appSupport.appendingPathComponent("SwiftDataBackup")

        do {
            try FileManager.default.createDirectory(
                at: backupDir, withIntermediateDirectories: true)
            for ext in ["store", "store-shm", "store-wal"] {
                let src = appSupport.appendingPathComponent("default.\(ext)")
                let dst = backupDir.appendingPathComponent("default.\(ext)")
                if FileManager.default.fileExists(atPath: src.path) {
                    try FileManager.default.moveItem(at: src, to: dst)
                }
            }
            logger.info("Archived old SwiftData store to SwiftDataBackup/")
        } catch {
            logger.warning("Failed to archive old store: \(error.localizedDescription)")
        }
    }

    private static func markComplete() {
        UserDefaults.standard.set(true, forKey: migrationCompleteKey)
    }

    // MARK: - SQLite Helpers

    private static func swiftDataStorePath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("default.store").path
    }

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private static func tableExists(db: OpaquePointer?, table: String) -> Bool {
        var stmt: OpaquePointer?
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, table, -1, sqliteTransient)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private static func columnExists(db: OpaquePointer?, table: String, column: String) -> Bool {
        var stmt: OpaquePointer?
        // PRAGMA doesn't support parameter binding, but table names are hardcoded internal
        // constants so this is safe. We quote the table name to prevent injection.
        let query = "PRAGMA table_info(\"\(table.replacingOccurrences(of: "\"", with: "\"\""))\")"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let name = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
                name == column
            {
                return true
            }
        }
        return false
    }

    private static func resolveUUID(
        stmt: OpaquePointer?, column: Int32, zpk: Int64,
        map: inout [Int64: UUID]
    ) -> UUID {
        if sqlite3_column_type(stmt, column) != SQLITE_NULL,
            let raw = sqlite3_column_text(stmt, column),
            let uuid = UUID(uuidString: String(cString: raw))
        {
            map[zpk] = uuid
            return uuid
        }
        let newUUID = UUID()
        map[zpk] = newUUID
        return newUUID
    }

    private static func readString(stmt: OpaquePointer?, column: Int32) -> String {
        if sqlite3_column_type(stmt, column) != SQLITE_NULL,
            let raw = sqlite3_column_text(stmt, column)
        {
            return String(cString: raw)
        }
        return ""
    }

    private static func readOptionalString(stmt: OpaquePointer?, column: Int32) -> String? {
        guard sqlite3_column_type(stmt, column) != SQLITE_NULL,
            let raw = sqlite3_column_text(stmt, column)
        else { return nil }
        return String(cString: raw)
    }

    private static func readCoreDataDate(stmt: OpaquePointer?, column: Int32) -> Date {
        guard sqlite3_column_type(stmt, column) != SQLITE_NULL else { return Date() }
        let timestamp = sqlite3_column_double(stmt, column)
        return Date(timeIntervalSinceReferenceDate: timestamp)
    }

    /// Reads a Core Data REAL column as Decimal, preferring the text representation
    /// to avoid IEEE 754 precision loss (e.g. 99.99 → "99.9899999999999980...").
    private static func readDecimal(stmt: OpaquePointer?, column: Int32) -> Decimal {
        guard sqlite3_column_type(stmt, column) != SQLITE_NULL else { return 0 }
        // SQLite returns a clean string (e.g. "99.99") for REAL columns,
        // avoiding the Double → Decimal precision artifacts.
        if let textPtr = sqlite3_column_text(stmt, column) {
            let text = String(cString: textPtr)
            if let decimal = Decimal(string: text) {
                return decimal
            }
        }
        // Fallback: use Double conversion (lossy but better than zero)
        return Decimal(sqlite3_column_double(stmt, column))
    }

    /// Reads a Core Data Codable array stored as plist BLOB or JSON TEXT.
    /// Returns a JSON string suitable for sqlite-data storage.
    private static func readCodableArrayJSON(stmt: OpaquePointer?, column: Int32) -> String {
        guard sqlite3_column_type(stmt, column) != SQLITE_NULL else { return "[]" }

        let colType = sqlite3_column_type(stmt, column)

        if colType == SQLITE_BLOB {
            // Core Data stores Codable arrays as plist BLOBs
            guard let blobPtr = sqlite3_column_blob(stmt, column) else { return "[]" }
            let blobLen = Int(sqlite3_column_bytes(stmt, column))
            guard blobLen > 0 else { return "[]" }
            let data = Data(bytes: blobPtr, count: blobLen)

            // Try plist decoding (Core Data's default for Codable arrays)
            do {
                let plistObj = try PropertyListSerialization.propertyList(
                    from: data, options: [], format: nil)
                if let plistArray = plistObj as? [Any] {
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: plistArray, options: [])
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        return jsonString
                    }
                }
            } catch {
                logger.warning("Plist deserialization failed for column \(column): \(error.localizedDescription)")
            }

            // Try JSON decoding as fallback
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    _ = try JSONSerialization.jsonObject(with: data, options: [])
                    return jsonString
                }
            } catch {
                logger.warning(
                    "JSON fallback deserialization failed for column \(column): \(error.localizedDescription)")
            }

            return "[]"
        } else if colType == SQLITE_TEXT {
            // Already stored as text
            if let raw = sqlite3_column_text(stmt, column) {
                return String(cString: raw)
            }
        }

        return "[]"
    }

    /// Reads a Core Data `[AttachmentInfo]` plist BLOB and re-encodes it as JSON
    /// with ISO 8601 date strings (matching sqlite-data's expected format).
    ///
    /// `readCodableArrayJSON` silently loses `AttachmentInfo` data because CoreData
    /// stores `Date` values as `NSDate` objects in plists. `JSONSerialization` cannot
    /// represent `NSDate`, so the round-trip through plist→generic-JSON drops the
    /// `createdAt` field. This method uses `PropertyListDecoder` → typed Swift struct
    /// → `JSONEncoder` with a custom date strategy to preserve all fields.
    static func readAttachmentsPlistJSON(stmt: OpaquePointer?, column: Int32) -> String {
        guard sqlite3_column_type(stmt, column) == SQLITE_BLOB else {
            // Fallback: TEXT columns or NULL
            return readCodableArrayJSON(stmt: stmt, column: column)
        }
        guard let blobPtr = sqlite3_column_blob(stmt, column) else { return "[]" }
        let blobLen = Int(sqlite3_column_bytes(stmt, column))
        guard blobLen > 0 else { return "[]" }
        let data = Data(bytes: blobPtr, count: blobLen)

        // Try typed decoding (preserves Date fields correctly)
        do {
            let attachments = try PropertyListDecoder().decode([AttachmentInfo].self, from: data)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(date.iso8601String)
            }
            let jsonData = try encoder.encode(attachments)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            logger.warning("AttachmentInfo typed decode failed, falling back to generic: \(error.localizedDescription)")
        }

        // Fall back to generic plist→JSON (may lose Date fields)
        return readCodableArrayJSON(stmt: stmt, column: column)
    }

    /// Deserializes a UIColor BLOB stored via UIColorValueTransformer → hex Int64.
    /// Returns a fallback gray if the BLOB exists but can't be deserialized.
    private static func deserializeColorBlob(
        stmt: OpaquePointer?, column: Int32, skippedColors: inout Int
    ) -> Int64? {
        guard sqlite3_column_type(stmt, column) == SQLITE_BLOB else { return nil }
        guard let blobPtr = sqlite3_column_blob(stmt, column) else { return nil }
        let blobLen = Int(sqlite3_column_bytes(stmt, column))
        guard blobLen > 0 else { return nil }

        let data = Data(bytes: blobPtr, count: blobLen)

        guard
            let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)
        else {
            logger.warning("Failed to deserialize UIColor BLOB — using fallback gray")
            skippedColors += 1
            return 0x8080_80FF  // medium gray fallback
        }

        // Convert UIColor to hex integer (RGBA), normalizing to sRGB for grayscale safety
        let converted = color.cgColor.converted(
            to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil
        )
        guard let components = converted?.components, components.count >= 3 else { return nil }
        let r = Int64(components[0] * 0xFF) << 24
        let g = Int64(components[1] * 0xFF) << 16
        let b = Int64(components[2] * 0xFF) << 8
        let a = Int64((components.count >= 4 ? components[3] : 1) * 0xFF)
        return r | g | b | a
    }

    /// Reads two Int64 columns as pairs from a query result
    private static func readPairs(db: OpaquePointer?, query: String) -> [(Int64, Int64)] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            logPrepareError(db: db, context: "readPairs")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var pairs: [(Int64, Int64)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let first = sqlite3_column_int64(stmt, 0)
            let second = sqlite3_column_int64(stmt, 1)
            pairs.append((first, second))
        }
        return pairs
    }

    private static func logPrepareError(db: OpaquePointer?, context: String) {
        let errMsg = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
        logger.error("sqlite3_prepare_v2 failed in \(context): \(errMsg)")
    }
}

// MARK: - Date Helper

extension Date {
    /// SQLite standard date format expected by GRDB's default date decoding.
    private static let sqliteDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var iso8601String: String {
        Self.sqliteDateFormatter.string(from: self)
    }
}

// MARK: - Migration Errors

enum MigrationError: LocalizedError {
    case countMismatch(table: String, expected: Int, actual: Int)
    case foreignKeyViolation(count: Int)

    var errorDescription: String? {
        switch self {
        case .countMismatch(let table, let expected, let actual):
            return
                "Count mismatch in \(table): expected \(expected), got \(actual)"
        case .foreignKeyViolation(let count):
            return "Found \(count) foreign key violation(s) after migration"
        }
    }
}
