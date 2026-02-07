import CloudKit
import Dependencies
import Foundation
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
            markComplete()
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
            var recordNameToUUID: [String: UUID] = [:]
            for records in [homes, labels, policies, locations, items] {
                for record in records {
                    let recordName = record.recordID.recordName
                    if let idString = record["CD_id"] as? String,
                        let uuid = UUID(uuidString: idString)
                    {
                        recordNameToUUID[recordName] = uuid
                    } else {
                        recordNameToUUID[recordName] = UUID()
                    }
                }
            }

            // Write everything in a single transaction
            let stats = try await database.write { db -> RecoveryStats in
                var stats = RecoveryStats()

                // 1. Labels
                for record in labels {
                    let uuid = recordNameToUUID[record.recordID.recordName]!
                    let colorHex = deserializeCKColorAsset(record: record, key: "CD_color")

                    try db.execute(
                        sql: """
                            INSERT INTO "inventoryLabels" ("id", "name", "desc", "color", "emoji")
                            VALUES (?, ?, ?, ?, ?)
                            """,
                        arguments: [
                            uuid.uuidString.lowercased(),
                            (record["CD_name"] as? String) ?? "",
                            (record["CD_desc"] as? String) ?? "",
                            colorHex,
                            (record["CD_emoji"] as? String) ?? "🏷️",
                        ])
                    stats.labels += 1
                }

                // 2. Homes
                for record in homes {
                    let uuid = recordNameToUUID[record.recordID.recordName]!
                    let purchaseDate = (record["CD_purchaseDate"] as? Date) ?? Date()
                    let purchasePrice = decimalFromCKDouble(record["CD_purchasePrice"] as? Double)
                    let secondaryPhotos = jsonFromCKAssetOrData(record: record, key: "CD_secondaryPhotoURLs")
                    let isPrimary = (record["CD_isPrimary"] as? Int64).map { $0 != 0 } ?? true

                    try db.execute(
                        sql: """
                            INSERT INTO "homes" ("id", "name", "address1", "address2", "city", "state", "zip", "country",
                                "purchaseDate", "purchasePrice", "imageURL", "secondaryPhotoURLs", "isPrimary", "colorName")
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                            """,
                        arguments: [
                            uuid.uuidString.lowercased(),
                            (record["CD_name"] as? String) ?? "",
                            (record["CD_address1"] as? String) ?? "",
                            (record["CD_address2"] as? String) ?? "",
                            (record["CD_city"] as? String) ?? "",
                            (record["CD_state"] as? String) ?? "",
                            (record["CD_zip"] as? String) ?? "",
                            (record["CD_country"] as? String) ?? "",
                            purchaseDate.iso8601String,
                            "\(purchasePrice)",
                            record["CD_imageURL"] as? String,
                            secondaryPhotos,
                            isPrimary,
                            (record["CD_colorName"] as? String) ?? "green",
                        ])
                    stats.homes += 1
                }

                // 3. Insurance Policies
                for record in policies {
                    let uuid = recordNameToUUID[record.recordID.recordName]!

                    try db.execute(
                        sql: """
                            INSERT INTO "insurancePolicies" ("id", "providerName", "policyNumber",
                                "deductibleAmount", "dwellingCoverageAmount", "personalPropertyCoverageAmount",
                                "lossOfUseCoverageAmount", "liabilityCoverageAmount", "medicalPaymentsCoverageAmount",
                                "startDate", "endDate")
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                            """,
                        arguments: [
                            uuid.uuidString.lowercased(),
                            (record["CD_providerName"] as? String) ?? "",
                            (record["CD_policyNumber"] as? String) ?? "",
                            "\(decimalFromCKDouble(record["CD_deductibleAmount"] as? Double))",
                            "\(decimalFromCKDouble(record["CD_dwellingCoverageAmount"] as? Double))",
                            "\(decimalFromCKDouble(record["CD_personalPropertyCoverageAmount"] as? Double))",
                            "\(decimalFromCKDouble(record["CD_lossOfUseCoverageAmount"] as? Double))",
                            "\(decimalFromCKDouble(record["CD_liabilityCoverageAmount"] as? Double))",
                            "\(decimalFromCKDouble(record["CD_medicalPaymentsCoverageAmount"] as? Double))",
                            ((record["CD_startDate"] as? Date) ?? Date()).iso8601String,
                            ((record["CD_endDate"] as? Date) ?? Date()).iso8601String,
                        ])
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

                    try db.execute(
                        sql: """
                            INSERT INTO "inventoryLocations" ("id", "name", "desc", "sfSymbolName", "imageURL",
                                "secondaryPhotoURLs", "homeID")
                            VALUES (?, ?, ?, ?, ?, ?, ?)
                            """,
                        arguments: [
                            uuid.uuidString.lowercased(),
                            (record["CD_name"] as? String) ?? "",
                            (record["CD_desc"] as? String) ?? "",
                            record["CD_sfSymbolName"] as? String,
                            record["CD_imageURL"] as? String,
                            secondaryPhotos,
                            homeUUID?.uuidString.lowercased(),
                        ])
                    stats.locations += 1
                }

                // 5. Items (resolve locationID, homeID, and label references)

                for record in items {
                    let uuid = recordNameToUUID[record.recordID.recordName]!
                    let locationUUID = resolveReference(
                        record: record, key: "CD_location", map: recordNameToUUID)
                    var homeUUID = resolveReference(
                        record: record, key: "CD_home", map: recordNameToUUID)

                    // Pre-multi-home fallback: assign homeless items to primary home
                    if homeUUID == nil, let fallback = fallbackHomeUUID {
                        homeUUID = fallback
                    }

                    let createdAt = (record["CD_createdAt"] as? Date) ?? Date()
                    let price = decimalFromCKDouble(record["CD_price"] as? Double)
                    let replacementCost: Decimal? = (record["CD_replacementCost"] as? Double).map {
                        decimalFromCKDouble($0)
                    }
                    let secondaryPhotos = jsonFromCKAssetOrData(record: record, key: "CD_secondaryPhotoURLs")
                    let attachments = jsonFromCKAssetOrData(record: record, key: "CD_attachments")

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
                            uuid.uuidString.lowercased(),
                            (record["CD_title"] as? String) ?? "",
                            (record["CD_quantityString"] as? String) ?? "1",
                            (record["CD_quantityInt"] as? Int64) ?? 1,
                            (record["CD_desc"] as? String) ?? "",
                            (record["CD_serial"] as? String) ?? "",
                            (record["CD_model"] as? String) ?? "",
                            (record["CD_make"] as? String) ?? "",
                            "\(price)",
                            (record["CD_insured"] as? Int64).map { $0 != 0 } ?? false,
                            (record["CD_assetId"] as? String) ?? "",
                            (record["CD_notes"] as? String) ?? "",
                            replacementCost.map { "\($0)" },
                            record["CD_depreciationRate"] as? Double,
                            record["CD_imageURL"] as? String,
                            secondaryPhotos,
                            (record["CD_hasUsedAI"] as? Int64).map { $0 != 0 } ?? false,
                            createdAt.iso8601String,
                            (record["CD_purchaseDate"] as? Date)?.iso8601String,
                            (record["CD_warrantyExpirationDate"] as? Date)?.iso8601String,
                            (record["CD_purchaseLocation"] as? String) ?? "",
                            (record["CD_condition"] as? String) ?? "",
                            (record["CD_hasWarranty"] as? Int64).map { $0 != 0 } ?? false,
                            attachments,
                            (record["CD_dimensionLength"] as? String) ?? "",
                            (record["CD_dimensionWidth"] as? String) ?? "",
                            (record["CD_dimensionHeight"] as? String) ?? "",
                            (record["CD_dimensionUnit"] as? String) ?? "inches",
                            (record["CD_weightValue"] as? String) ?? "",
                            (record["CD_weightUnit"] as? String) ?? "lbs",
                            (record["CD_color"] as? String) ?? "",
                            (record["CD_storageRequirements"] as? String) ?? "",
                            (record["CD_isFragile"] as? Int64).map { $0 != 0 } ?? false,
                            (record["CD_movingPriority"] as? Int64) ?? 3,
                            (record["CD_roomDestination"] as? String) ?? "",
                            locationUUID?.uuidString.lowercased(),
                            homeUUID?.uuidString.lowercased(),
                        ])
                    stats.items += 1

                    // Resolve item-label relationship (v2.1.0 single FK: CD_label)
                    if let labelUUID = resolveReference(
                        record: record, key: "CD_label", map: recordNameToUUID)
                    {
                        try db.execute(
                            sql: """
                                INSERT INTO "inventoryItemLabels" ("id", "inventoryItemID", "inventoryLabelID")
                                VALUES (?, ?, ?)
                                """,
                            arguments: [
                                UUID().uuidString.lowercased(),
                                uuid.uuidString.lowercased(),
                                labelUUID.uuidString.lowercased(),
                            ])
                        stats.itemLabels += 1
                    }
                }

                // 6. Home-Policy relationships (v2.1.0 single FK: CD_insurancePolicy on Home)
                for record in homes {
                    let homeUUID = recordNameToUUID[record.recordID.recordName]!
                    if let policyUUID = resolveReference(
                        record: record, key: "CD_insurancePolicy", map: recordNameToUUID)
                    {
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

        let (results, cursor) = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            resultsLimit: 200
        )

        for (_, result) in results {
            if case .success(let record) = result {
                allRecords.append(record)
            }
        }

        var nextCursor = cursor
        while let c = nextCursor {
            let (batchResults, newCursor) = try await database.records(
                continuingMatchFrom: c,
                resultsLimit: 200
            )
            for (_, result) in batchResults {
                if case .success(let record) = result {
                    allRecords.append(record)
                }
            }
            nextCursor = newCursor
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

    /// Converts a CloudKit Double value to Decimal, avoiding IEEE 754 precision loss.
    static func decimalFromCKDouble(_ value: Double?) -> Decimal {
        guard let value else { return 0 }
        // Use string representation to avoid Double→Decimal precision artifacts
        return Decimal(string: "\(value)") ?? Decimal(value)
    }

    /// Converts a CloudKit Double to an optional Decimal.
    private static func decimalFromCKDouble(_ value: Double) -> Decimal {
        Decimal(string: "\(value)") ?? Decimal(value)
    }

    /// Deserializes a UIColor stored as a CKAsset (binary plist BLOB) into hex RGBA Int64.
    /// CoreData stores UIColor via NSKeyedArchiver; CloudKit wraps BLOBs as CKAssets.
    static func deserializeCKColorAsset(record: CKRecord, key: String) -> Int64? {
        // CloudKit stores CoreData blobs as CKAsset
        if let asset = record[key] as? CKAsset,
            let url = asset.fileURL,
            let data = try? Data(contentsOf: url)
        {
            return colorHexFromData(data)
        }
        // Fallback: might be stored as raw Data
        if let data = record[key] as? Data {
            return colorHexFromData(data)
        }
        return nil
    }

    /// Converts NSKeyedArchiver UIColor data to hex RGBA Int64.
    static func colorHexFromData(_ data: Data) -> Int64? {
        guard let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)
        else { return 0x8080_80FF }

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
