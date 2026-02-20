import CloudKit
import Dependencies
import Foundation
import GRDB
import OSLog
import SQLiteData
import UIKit

private let logger = Logger(subsystem: "com.mothersound.movingbox", category: "CloudKitRecovery")

/// Recovers stranded data from the legacy CoreData-backed CloudKit zone
/// (`com.apple.coredata.cloudkit.zone`) for users upgrading from v2.1.0
/// who reinstall or set up a new device without a local SwiftData store.
///
/// Follows the same struct/static-method pattern as `SQLiteMigrationCoordinator`.
struct CloudKitRecoveryCoordinator {

    // MARK: - Types

    enum RecoveryResult {
        case noRecordsFound
        case recovered(stats: RecoveryStats)
        case skipped
        case error(String)
    }

    struct RecoveryStats: CustomStringConvertible {
        var labels = 0
        var homes = 0
        var policies = 0
        var locations = 0
        var items = 0
        var itemLabels = 0
        var homePolicies = 0
        var skippedRelationships = 0

        var description: String {
            var parts = [
                "labels=\(labels)", "homes=\(homes)", "policies=\(policies)",
                "locations=\(locations)", "items=\(items)",
                "itemLabels=\(itemLabels)", "homePolicies=\(homePolicies)",
            ]
            if skippedRelationships > 0 {
                parts.append("skippedRelationships=\(skippedRelationships)")
            }
            return parts.joined(separator: ", ")
        }
    }

    // MARK: - Constants

    private static let containerID = "iCloud.com.mothersound.movingbox"
    private static let oldZoneName = "com.apple.coredata.cloudkit.zone"
    private static let recoveryCompleteKey = "com.mothersound.movingbox.cloudkit.recovery.complete"
    private static let recoveryAttemptsKey = "com.mothersound.movingbox.cloudkit.recovery.attempts"
    private static let maxRecoveryAttempts = 3

    // MARK: - Public API

    /// Lightweight probe: checks if any `CD_InventoryItem` records exist in the
    /// old CoreData CloudKit zone. Returns the item count, or nil if none found
    /// or if the check fails (e.g. no network).
    static func probeForStrandedRecords() async -> Int? {
        guard !UserDefaults.standard.bool(forKey: recoveryCompleteKey) else {
            return nil
        }

        let container = CKContainer(identifier: containerID)
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: oldZoneName)

        do {
            let query = CKQuery(
                recordType: "CD_InventoryItem",
                predicate: NSPredicate(value: true)
            )
            // Lightweight probe — we only need to know if records exist
            let (firstBatch, cursor) = try await database.records(
                matching: query,
                inZoneWith: zoneID,
                desiredKeys: [],
                resultsLimit: 100
            )

            guard !firstBatch.isEmpty else { return nil }

            // Count all records via cursor pagination
            var total = firstBatch.count
            var nextCursor = cursor
            while let c = nextCursor {
                let (batch, newCursor) = try await database.records(
                    continuingMatchFrom: c,
                    desiredKeys: [],
                    resultsLimit: 100
                )
                total += batch.count
                nextCursor = newCursor
            }

            logger.info("Probe found \(total) stranded CD_InventoryItem records")
            return total
        } catch let error as CKError where error.code == .zoneNotFound {
            logger.info("Old CoreData zone not found — no stranded records")
            return nil
        } catch let error as CKError where error.code == .networkUnavailable || error.code == .networkFailure {
            logger.info("Network unavailable during probe — will retry next launch")
            return nil
        } catch {
            logger.warning("Probe failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Full recovery: fetches all records from the old CoreData CloudKit zone
    /// and writes them to the sqlite-data database.
    static func recoverAllRecords(database: any DatabaseWriter) async -> RecoveryResult {
        let attempts = UserDefaults.standard.integer(forKey: recoveryAttemptsKey)
        if attempts >= maxRecoveryAttempts {
            let msg = "Recovery abandoned after \(attempts) failed attempts"
            logger.error("\(msg)")
            // Do NOT mark complete — preserve old CloudKit data so a future app
            // update can reset the attempt counter and retry successfully.
            return .error(msg)
        }
        UserDefaults.standard.set(attempts + 1, forKey: recoveryAttemptsKey)

        let container = CKContainer(identifier: containerID)
        let ckDatabase = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: oldZoneName)

        do {
            // Fetch all 5 record types in parallel
            async let fetchedHomes = fetchAllRecords(
                ofType: "CD_Home", from: ckDatabase, zoneID: zoneID)
            async let fetchedLabels = fetchAllRecords(
                ofType: "CD_InventoryLabel", from: ckDatabase, zoneID: zoneID)
            async let fetchedPolicies = fetchAllRecords(
                ofType: "CD_InsurancePolicy", from: ckDatabase, zoneID: zoneID)
            async let fetchedLocations = fetchAllRecords(
                ofType: "CD_InventoryLocation", from: ckDatabase, zoneID: zoneID)
            async let fetchedItems = fetchAllRecords(
                ofType: "CD_InventoryItem", from: ckDatabase, zoneID: zoneID)

            let homes = try await fetchedHomes
            let labels = try await fetchedLabels
            let policies = try await fetchedPolicies
            let locations = try await fetchedLocations
            let items = try await fetchedItems

            let totalRecords = homes.count + labels.count + policies.count + locations.count + items.count
            guard totalRecords > 0 else {
                logger.info("No records found in old zone")
                return .noRecordsFound
            }

            logger.info("Fetched \(totalRecords) total records from old CloudKit zone")

            // Build recordName → UUID map from CD_id fields
            let recordNameToUUID: [String: UUID] = {
                var map: [String: UUID] = [:]
                for records in [homes, labels, policies, locations, items] {
                    for record in records {
                        let recordName = record.recordID.recordName
                        if let idString = record["CD_id"] as? String,
                            let uuid = UUID(uuidString: idString)
                        {
                            map[recordName] = uuid
                        } else {
                            map[recordName] = UUID()
                        }
                    }
                }
                return map
            }()

            // Write everything in a single transaction
            let stats = try await database.write { db -> RecoveryStats in
                var stats = RecoveryStats()

                // 1. Labels
                for record in labels {
                    let uuid = recordNameToUUID[record.recordID.recordName]!
                    let colorHex = deserializeCKColorAsset(record: record, key: "CD_color")

                    try SQLiteRecordWriter.insertLabel(
                        .init(
                            id: uuid.uuidString.lowercased(),
                            name: (record["CD_name"] as? String) ?? "",
                            desc: (record["CD_desc"] as? String) ?? "",
                            colorHex: colorHex,
                            emoji: (record["CD_emoji"] as? String) ?? "🏷️"
                        ), into: db)
                    stats.labels += 1
                }

                // 2. Homes
                for record in homes {
                    let uuid = recordNameToUUID[record.recordID.recordName]!
                    let purchaseDate = (record["CD_purchaseDate"] as? Date) ?? Date()
                    let purchasePrice = SQLiteRecordWriter.decimalFromDouble(record["CD_purchasePrice"] as? Double)
                    let secondaryPhotos = jsonFromCKAssetOrData(record: record, key: "CD_secondaryPhotoURLs")
                    let isPrimary = (record["CD_isPrimary"] as? Int64).map { $0 != 0 } ?? true

                    try SQLiteRecordWriter.insertHome(
                        .init(
                            id: uuid.uuidString.lowercased(),
                            name: (record["CD_name"] as? String) ?? "",
                            address1: (record["CD_address1"] as? String) ?? "",
                            address2: (record["CD_address2"] as? String) ?? "",
                            city: (record["CD_city"] as? String) ?? "",
                            state: (record["CD_state"] as? String) ?? "",
                            zip: (record["CD_zip"] as? String) ?? "",
                            country: (record["CD_country"] as? String) ?? "",
                            purchaseDate: purchaseDate.sqliteDateString,
                            purchasePrice: "\(purchasePrice)",
                            imageURL: record["CD_imageURL"] as? String,
                            secondaryPhotoURLs: secondaryPhotos,
                            isPrimary: isPrimary,
                            colorName: (record["CD_colorName"] as? String) ?? "green"
                        ), into: db)
                    stats.homes += 1
                }

                // 3. Insurance Policies
                for record in policies {
                    let uuid = recordNameToUUID[record.recordID.recordName]!

                    try SQLiteRecordWriter.insertPolicy(
                        .init(
                            id: uuid.uuidString.lowercased(),
                            providerName: (record["CD_providerName"] as? String) ?? "",
                            policyNumber: (record["CD_policyNumber"] as? String) ?? "",
                            deductibleAmount:
                                "\(SQLiteRecordWriter.decimalFromDouble(record["CD_deductibleAmount"] as? Double))",
                            dwellingCoverageAmount:
                                "\(SQLiteRecordWriter.decimalFromDouble(record["CD_dwellingCoverageAmount"] as? Double))",
                            personalPropertyCoverageAmount:
                                "\(SQLiteRecordWriter.decimalFromDouble(record["CD_personalPropertyCoverageAmount"] as? Double))",
                            lossOfUseCoverageAmount:
                                "\(SQLiteRecordWriter.decimalFromDouble(record["CD_lossOfUseCoverageAmount"] as? Double))",
                            liabilityCoverageAmount:
                                "\(SQLiteRecordWriter.decimalFromDouble(record["CD_liabilityCoverageAmount"] as? Double))",
                            medicalPaymentsCoverageAmount:
                                "\(SQLiteRecordWriter.decimalFromDouble(record["CD_medicalPaymentsCoverageAmount"] as? Double))",
                            startDate: ((record["CD_startDate"] as? Date) ?? Date()).sqliteDateString,
                            endDate: ((record["CD_endDate"] as? Date) ?? Date()).sqliteDateString
                        ), into: db)
                    stats.policies += 1
                }

                // Determine fallback home for legacy v2.1.0 records missing CD_home.
                // Prefer the primary home, or first alphabetically if none is marked primary.
                let primaryHome =
                    homes.first(where: {
                        ($0["CD_isPrimary"] as? Int64).map { $0 != 0 } ?? false
                    })
                    ?? homes.sorted(by: {
                        ($0["CD_name"] as? String ?? "") < ($1["CD_name"] as? String ?? "")
                    }).first
                let fallbackHomeUUID = primaryHome.flatMap { recordNameToUUID[$0.recordID.recordName] }

                // 4. Locations (resolve homeID via CKRecord.Reference)
                for record in locations {
                    let uuid = recordNameToUUID[record.recordID.recordName]!
                    var homeUUID = resolveReference(
                        record: record, key: "CD_home", map: recordNameToUUID)
                    let secondaryPhotos = jsonFromCKAssetOrData(record: record, key: "CD_secondaryPhotoURLs")

                    // Pre-multi-home fallback: assign homeless locations to primary home
                    if homeUUID == nil, let fallback = fallbackHomeUUID {
                        homeUUID = fallback
                    }

                    try SQLiteRecordWriter.insertLocation(
                        .init(
                            id: uuid.uuidString.lowercased(),
                            name: (record["CD_name"] as? String) ?? "",
                            desc: (record["CD_desc"] as? String) ?? "",
                            sfSymbolName: record["CD_sfSymbolName"] as? String,
                            imageURL: record["CD_imageURL"] as? String,
                            secondaryPhotoURLs: secondaryPhotos,
                            homeID: homeUUID?.uuidString.lowercased()
                        ), into: db)
                    stats.locations += 1
                }

                // 5. Items (resolve locationID, homeID, and label references)

                // Build location → home UUID map for backfilling homeless items
                var locationHomeUUIDMap: [UUID: UUID] = [:]
                for record in locations {
                    let locUUID = recordNameToUUID[record.recordID.recordName]!
                    if let homeRef = resolveReference(
                        record: record, key: "CD_home", map: recordNameToUUID)
                    {
                        locationHomeUUIDMap[locUUID] = homeRef
                    } else if let fallback = fallbackHomeUUID {
                        locationHomeUUIDMap[locUUID] = fallback
                    }
                }

                for record in items {
                    let uuid = recordNameToUUID[record.recordID.recordName]!
                    let locationUUID = resolveReference(
                        record: record, key: "CD_location", map: recordNameToUUID)
                    var homeUUID = resolveReference(
                        record: record, key: "CD_home", map: recordNameToUUID)

                    // Backfill: inherit home from location if item has no direct home
                    if homeUUID == nil, let locationUUID,
                        let locHome = locationHomeUUIDMap[locationUUID]
                    {
                        homeUUID = locHome
                    }

                    // Pre-multi-home fallback: assign homeless items to primary home
                    if homeUUID == nil, let fallback = fallbackHomeUUID {
                        homeUUID = fallback
                    }

                    let createdAt = (record["CD_createdAt"] as? Date) ?? Date()
                    let price = SQLiteRecordWriter.decimalFromDouble(record["CD_price"] as? Double)
                    let replacementCost: Decimal? = (record["CD_replacementCost"] as? Double).map {
                        SQLiteRecordWriter.decimalFromDouble($0)
                    }
                    let secondaryPhotos = jsonFromCKAssetOrData(record: record, key: "CD_secondaryPhotoURLs")
                    let attachments = jsonFromCKAssetOrData(record: record, key: "CD_attachments")

                    try SQLiteRecordWriter.insertItem(
                        .init(
                            id: uuid.uuidString.lowercased(),
                            title: (record["CD_title"] as? String) ?? "",
                            quantityString: (record["CD_quantityString"] as? String) ?? "1",
                            quantityInt: Int((record["CD_quantityInt"] as? Int64) ?? 1),
                            desc: (record["CD_desc"] as? String) ?? "",
                            serial: (record["CD_serial"] as? String) ?? "",
                            model: (record["CD_model"] as? String) ?? "",
                            make: (record["CD_make"] as? String) ?? "",
                            price: "\(price)",
                            insured: (record["CD_insured"] as? Int64).map { $0 != 0 } ?? false,
                            assetId: (record["CD_assetId"] as? String) ?? "",
                            notes: (record["CD_notes"] as? String) ?? "",
                            replacementCost: replacementCost.map { "\($0)" },
                            depreciationRate: record["CD_depreciationRate"] as? Double,
                            imageURL: record["CD_imageURL"] as? String,
                            secondaryPhotoURLs: secondaryPhotos,
                            hasUsedAI: (record["CD_hasUsedAI"] as? Int64).map { $0 != 0 } ?? false,
                            createdAt: createdAt.sqliteDateString,
                            purchaseDate: (record["CD_purchaseDate"] as? Date)?.sqliteDateString,
                            warrantyExpirationDate: (record["CD_warrantyExpirationDate"] as? Date)?.sqliteDateString,
                            purchaseLocation: (record["CD_purchaseLocation"] as? String) ?? "",
                            condition: (record["CD_condition"] as? String) ?? "",
                            hasWarranty: (record["CD_hasWarranty"] as? Int64).map { $0 != 0 } ?? false,
                            attachments: attachments,
                            dimensionLength: (record["CD_dimensionLength"] as? String) ?? "",
                            dimensionWidth: (record["CD_dimensionWidth"] as? String) ?? "",
                            dimensionHeight: (record["CD_dimensionHeight"] as? String) ?? "",
                            dimensionUnit: (record["CD_dimensionUnit"] as? String) ?? "inches",
                            weightValue: (record["CD_weightValue"] as? String) ?? "",
                            weightUnit: (record["CD_weightUnit"] as? String) ?? "lbs",
                            color: (record["CD_color"] as? String) ?? "",
                            storageRequirements: (record["CD_storageRequirements"] as? String) ?? "",
                            isFragile: (record["CD_isFragile"] as? Int64).map { $0 != 0 } ?? false,
                            movingPriority: Int((record["CD_movingPriority"] as? Int64) ?? 3),
                            roomDestination: (record["CD_roomDestination"] as? String) ?? "",
                            locationID: locationUUID?.uuidString.lowercased(),
                            homeID: homeUUID?.uuidString.lowercased()
                        ), into: db)
                    stats.items += 1

                    // Resolve item-label relationship (v2.1.0 single FK: CD_label)
                    if let labelUUID = resolveReference(
                        record: record, key: "CD_label", map: recordNameToUUID)
                    {
                        try SQLiteRecordWriter.insertItemLabel(
                            .init(
                                id: UUID().uuidString.lowercased(),
                                inventoryItemID: uuid.uuidString.lowercased(),
                                inventoryLabelID: labelUUID.uuidString.lowercased()
                            ), into: db)
                        stats.itemLabels += 1
                    } else if record["CD_label"] != nil {
                        stats.skippedRelationships += 1
                    }
                }

                // 6. Home-Policy relationships (v2.1.0 single FK: CD_insurancePolicy on Home)
                for record in homes {
                    let homeUUID = recordNameToUUID[record.recordID.recordName]!
                    if let policyUUID = resolveReference(
                        record: record, key: "CD_insurancePolicy", map: recordNameToUUID)
                    {
                        try SQLiteRecordWriter.insertHomePolicy(
                            .init(
                                id: UUID().uuidString.lowercased(),
                                homeID: homeUUID.uuidString.lowercased(),
                                insurancePolicyID: policyUUID.uuidString.lowercased()
                            ), into: db)
                        stats.homePolicies += 1
                    } else if record["CD_insurancePolicy"] != nil {
                        stats.skippedRelationships += 1
                    }
                }

                return stats
            }

            // Post-recovery validation: verify FK integrity and item count sanity
            try await database.read { db in
                let fkViolations = try Row.fetchAll(db, sql: "PRAGMA foreign_key_check")
                guard fkViolations.isEmpty else {
                    throw RecoveryError.foreignKeyViolation(count: fkViolations.count)
                }

                let actualItems =
                    try Int.fetchOne(
                        db, sql: "SELECT COUNT(*) FROM inventoryItems") ?? 0
                guard actualItems == stats.items else {
                    throw RecoveryError.countMismatch(
                        expected: stats.items, actual: actualItems)
                }
            }

            markComplete()
            UserDefaults.standard.removeObject(forKey: recoveryAttemptsKey)
            logger.info("CloudKit recovery succeeded: \(stats.description)")
            return .recovered(stats: stats)
        } catch {
            logger.error("CloudKit recovery failed: \(error.localizedDescription)")
            return .error(error.localizedDescription)
        }
    }

    /// Deletes the old CoreData CloudKit zone to free storage. Best-effort.
    static func deleteOldCoreDataZone() async {
        let container = CKContainer(identifier: containerID)
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: oldZoneName)

        do {
            try await database.deleteRecordZone(withID: zoneID)
            logger.info("Deleted old CoreData CloudKit zone")
        } catch let error as CKError where error.code == .zoneNotFound {
            logger.info("Old CoreData zone already deleted")
        } catch {
            logger.warning("Failed to delete old zone (non-fatal): \(error.localizedDescription)")
        }
    }

    /// Marks recovery as complete so it won't re-run.
    static func markComplete() {
        UserDefaults.standard.set(true, forKey: recoveryCompleteKey)
    }

    // MARK: - CloudKit Fetch Helpers

    private static func fetchAllRecords(
        ofType recordType: String,
        from database: CKDatabase,
        zoneID: CKRecordZone.ID
    ) async throws -> [CKRecord] {
        let query = CKQuery(
            recordType: recordType,
            predicate: NSPredicate(value: true)
        )

        var allRecords: [CKRecord] = []
        var failedCount = 0

        let (results, cursor) = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            resultsLimit: 200
        )

        for (recordID, result) in results {
            switch result {
            case .success(let record):
                allRecords.append(record)
            case .failure(let error):
                failedCount += 1
                logger.warning(
                    "Failed to fetch \(recordType) record \(recordID.recordName): \(error.localizedDescription)")
            }
        }

        var nextCursor = cursor
        while let c = nextCursor {
            let (batchResults, newCursor) = try await database.records(
                continuingMatchFrom: c,
                resultsLimit: 200
            )
            for (recordID, result) in batchResults {
                switch result {
                case .success(let record):
                    allRecords.append(record)
                case .failure(let error):
                    failedCount += 1
                    logger.warning(
                        "Failed to fetch \(recordType) record \(recordID.recordName): \(error.localizedDescription)")
                }
            }
            nextCursor = newCursor
        }

        if failedCount > 0 {
            logger.warning("Dropped \(failedCount) \(recordType) records due to fetch failures")
        }
        logger.info("Fetched \(allRecords.count) \(recordType) records")
        return allRecords
    }

    // MARK: - Type Conversion Helpers

    /// Resolves a CKRecord.Reference field to a UUID via the recordName → UUID map.
    private static func resolveReference(
        record: CKRecord, key: String, map: [String: UUID]
    ) -> UUID? {
        guard let reference = record[key] as? CKRecord.Reference else { return nil }
        return map[reference.recordID.recordName]
    }

    /// Deserializes a UIColor stored as a CKAsset (binary plist BLOB) into hex RGBA Int64.
    /// CoreData stores UIColor via NSKeyedArchiver; CloudKit wraps BLOBs as CKAssets.
    static func deserializeCKColorAsset(record: CKRecord, key: String) -> Int64? {
        // CloudKit stores CoreData blobs as CKAsset
        if let asset = record[key] as? CKAsset,
            let url = asset.fileURL,
            let data = try? Data(contentsOf: url)
        {
            return SQLiteRecordWriter.colorHexFromData(data)
        }
        // Fallback: might be stored as raw Data
        if let data = record[key] as? Data {
            return SQLiteRecordWriter.colorHexFromData(data)
        }
        return nil
    }

    /// Converts a CKAsset or Data plist blob to a JSON string array.
    /// CoreData stores Codable arrays as plist BLOBs; CloudKit wraps them as CKAssets.
    static func jsonFromCKAssetOrData(record: CKRecord, key: String) -> String {
        var data: Data?

        if let asset = record[key] as? CKAsset, let url = asset.fileURL {
            data = try? Data(contentsOf: url)
        } else if let raw = record[key] as? Data {
            data = raw
        }

        guard let data, !data.isEmpty else { return "[]" }

        // Try plist decoding (CoreData's default for Codable arrays)
        if let plistArray = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as? [Any],
            let jsonData = try? JSONSerialization.data(withJSONObject: plistArray, options: []),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
            return jsonString
        }

        // Try JSON decoding as fallback
        if let jsonString = String(data: data, encoding: .utf8),
            (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
        {
            return jsonString
        }

        return "[]"
    }
}

// MARK: - Recovery Errors

enum RecoveryError: LocalizedError {
    case foreignKeyViolation(count: Int)
    case countMismatch(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .foreignKeyViolation(let count):
            return "Found \(count) foreign key violation(s) after recovery"
        case .countMismatch(let expected, let actual):
            return "Item count mismatch after recovery: expected \(expected), got \(actual)"
        }
    }
}
