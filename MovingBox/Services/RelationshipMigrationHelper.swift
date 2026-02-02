import Foundation
import SQLite3
import SwiftData

/// Handles pre-migration capture and post-migration restoration of relationship data
/// that would otherwise be lost during SwiftData lightweight migration.
///
/// When SwiftData performs lightweight migration for relationship type changes
/// (e.g., to-one → to-many), it drops the old foreign key column and creates a
/// new join table. This helper reads the foreign key values from SQLite BEFORE
/// the ModelContainer is created, then restores them as proper relationships AFTER.
@MainActor
struct RelationshipMigrationHelper {

    private static let migrationKey = "MovingBox_RelationshipMigration_SQLite_v1"

    static var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }

    // MARK: - Captured Mapping Types

    struct LabelMapping {
        let itemUUID: UUID?
        let itemTitle: String
        let itemCreatedAt: Double
        let labelName: String
    }

    struct InsurancePolicyMapping {
        let homeUUID: UUID?
        let homeName: String
        let policyProviderName: String
        let policyNumber: String
    }

    struct CapturedMappings {
        let labelMappings: [LabelMapping]
        let insurancePolicyMappings: [InsurancePolicyMapping]

        var isEmpty: Bool {
            labelMappings.isEmpty && insurancePolicyMappings.isEmpty
        }
    }

    // MARK: - Pre-Migration: Capture Mappings

    /// Call BEFORE creating ModelContainer to capture relationship data from SQLite.
    /// Returns captured mappings that should be passed to `restoreMappings()` after container creation.
    static func captureMappingsIfNeeded() -> CapturedMappings {
        guard !isMigrationCompleted else {
            return CapturedMappings(labelMappings: [], insurancePolicyMappings: [])
        }

        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dbPath = appSupport.appendingPathComponent("default.store").path

        guard FileManager.default.fileExists(atPath: dbPath) else {
            // Fresh install — no database to migrate
            markCompleted()
            return CapturedMappings(labelMappings: [], insurancePolicyMappings: [])
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            print("📦 RelationshipMigration - Failed to open database")
            return CapturedMappings(labelMappings: [], insurancePolicyMappings: [])
        }
        defer { sqlite3_close(db) }

        let labelMappings = captureLabelMappings(db: db)
        let insuranceMappings = captureInsurancePolicyMappings(db: db)

        if labelMappings.isEmpty && insuranceMappings.isEmpty {
            // No old FK columns found — schema already matches or fresh install
            markCompleted()
        }

        print(
            "📦 RelationshipMigration - Captured \(labelMappings.count) label mappings, "
                + "\(insuranceMappings.count) insurance mappings"
        )

        return CapturedMappings(
            labelMappings: labelMappings,
            insurancePolicyMappings: insuranceMappings
        )
    }

    // MARK: - Post-Migration: Restore Mappings

    /// Call AFTER ModelContainer is created to restore captured relationship data.
    static func restoreMappings(_ mappings: CapturedMappings, context: ModelContext) {
        guard !mappings.isEmpty else {
            markCompleted()
            return
        }

        do {
            if !mappings.labelMappings.isEmpty {
                try restoreLabelMappings(mappings.labelMappings, context: context)
            }

            if !mappings.insurancePolicyMappings.isEmpty {
                try restoreInsurancePolicyMappings(mappings.insurancePolicyMappings, context: context)
            }

            try context.save()
            markCompleted()
            print("📦 RelationshipMigration - All mappings restored successfully")
        } catch {
            print("📦 RelationshipMigration - Error restoring mappings: \(error)")
            // Mark completed to prevent repeated failures on every launch
            markCompleted()
        }
    }

    // MARK: - Private: Label Capture

    private static func captureLabelMappings(db: OpaquePointer?) -> [LabelMapping] {
        guard tableExists(db: db, table: "ZINVENTORYITEM"),
            columnExists(db: db, table: "ZINVENTORYITEM", column: "ZLABEL")
        else {
            return []
        }

        let hasItemUUID = columnExists(db: db, table: "ZINVENTORYITEM", column: "ZID")

        let selectUUID = hasItemUUID ? "i.ZID" : "NULL"
        let query = """
            SELECT \(selectUUID), i.ZTITLE, i.ZCREATEDAT, l.ZNAME
            FROM ZINVENTORYITEM i
            JOIN ZINVENTORYLABEL l ON i.ZLABEL = l.Z_PK
            WHERE i.ZLABEL IS NOT NULL
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("📦 RelationshipMigration - Failed to prepare label query")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var mappings: [LabelMapping] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let uuid: UUID?
            if hasItemUUID,
                sqlite3_column_type(stmt, 0) != SQLITE_NULL,
                let raw = sqlite3_column_text(stmt, 0)
            {
                uuid = UUID(uuidString: String(cString: raw))
            } else {
                uuid = nil
            }

            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            let createdAt = sqlite3_column_double(stmt, 2)
            let labelName = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""

            mappings.append(
                LabelMapping(
                    itemUUID: uuid,
                    itemTitle: title,
                    itemCreatedAt: createdAt,
                    labelName: labelName
                ))
        }

        return mappings
    }

    // MARK: - Private: Insurance Policy Capture

    private static func captureInsurancePolicyMappings(db: OpaquePointer?) -> [InsurancePolicyMapping] {
        guard tableExists(db: db, table: "ZHOME"),
            columnExists(db: db, table: "ZHOME", column: "ZINSURANCEPOLICY")
        else {
            return []
        }

        let hasHomeUUID = columnExists(db: db, table: "ZHOME", column: "ZID")

        let selectUUID = hasHomeUUID ? "h.ZID" : "NULL"
        let query = """
            SELECT \(selectUUID), h.ZNAME, p.ZPROVIDERNAME, p.ZPOLICYNUMBER
            FROM ZHOME h
            JOIN ZINSURANCEPOLICY p ON h.ZINSURANCEPOLICY = p.Z_PK
            WHERE h.ZINSURANCEPOLICY IS NOT NULL
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("📦 RelationshipMigration - Failed to prepare insurance query")
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var mappings: [InsurancePolicyMapping] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let uuid: UUID?
            if hasHomeUUID,
                sqlite3_column_type(stmt, 0) != SQLITE_NULL,
                let raw = sqlite3_column_text(stmt, 0)
            {
                uuid = UUID(uuidString: String(cString: raw))
            } else {
                uuid = nil
            }

            let homeName = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            let providerName = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let policyNumber = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""

            mappings.append(
                InsurancePolicyMapping(
                    homeUUID: uuid,
                    homeName: homeName,
                    policyProviderName: providerName,
                    policyNumber: policyNumber
                ))
        }

        return mappings
    }

    // MARK: - Private: Label Restore

    private static func restoreLabelMappings(_ mappings: [LabelMapping], context: ModelContext) throws {
        let allLabels = try context.fetch(FetchDescriptor<InventoryLabel>())
        let labelsByName = Dictionary(
            allLabels.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let allItems = try context.fetch(FetchDescriptor<InventoryItem>())

        var restoredCount = 0
        for mapping in mappings {
            guard let label = labelsByName[mapping.labelName] else {
                print("📦 RelationshipMigration - Label '\(mapping.labelName)' not found, skipping")
                continue
            }

            guard let item = findItem(mapping: mapping, in: allItems) else {
                print("📦 RelationshipMigration - Item '\(mapping.itemTitle)' not found, skipping")
                continue
            }

            if !item.labels.contains(where: { $0.name == label.name }) {
                item.labels.append(label)
                restoredCount += 1
            }
        }

        print("📦 RelationshipMigration - Restored \(restoredCount) label assignments")
    }

    // MARK: - Private: Insurance Policy Restore

    private static func restoreInsurancePolicyMappings(
        _ mappings: [InsurancePolicyMapping],
        context: ModelContext
    ) throws {
        let allHomes = try context.fetch(FetchDescriptor<Home>())
        let allPolicies = try context.fetch(FetchDescriptor<InsurancePolicy>())

        var restoredCount = 0
        for mapping in mappings {
            guard let home = findHome(mapping: mapping, in: allHomes) else {
                print("📦 RelationshipMigration - Home '\(mapping.homeName)' not found, skipping")
                continue
            }

            let policy = allPolicies.first { p in
                p.providerName == mapping.policyProviderName
                    && p.policyNumber == mapping.policyNumber
            }
            guard let policy else {
                print("📦 RelationshipMigration - Policy '\(mapping.policyProviderName)' not found, skipping")
                continue
            }

            if !home.insurancePolicies.contains(where: { $0.policyNumber == policy.policyNumber }) {
                home.insurancePolicies.append(policy)
                restoredCount += 1
            }
        }

        print("📦 RelationshipMigration - Restored \(restoredCount) insurance policy assignments")
    }

    // MARK: - Private: Object Matching

    private static func findItem(mapping: LabelMapping, in items: [InventoryItem]) -> InventoryItem? {
        // Prefer UUID match
        if let uuid = mapping.itemUUID,
            let match = items.first(where: { $0.id == uuid })
        {
            return match
        }

        // Fallback: title + createdAt (Core Data stores dates as TimeInterval since 2001-01-01)
        let referenceDate = Date(timeIntervalSinceReferenceDate: mapping.itemCreatedAt)
        return items.first { item in
            item.title == mapping.itemTitle
                && abs(item.createdAt.timeIntervalSince(referenceDate)) < 1.0
        }
    }

    private static func findHome(mapping: InsurancePolicyMapping, in homes: [Home]) -> Home? {
        if let uuid = mapping.homeUUID,
            let match = homes.first(where: { $0.id == uuid })
        {
            return match
        }

        return homes.first { $0.name == mapping.homeName }
    }

    // MARK: - SQLite Helpers

    private static func tableExists(db: OpaquePointer?, table: String) -> Bool {
        var stmt: OpaquePointer?
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='\(table)'"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private static func columnExists(db: OpaquePointer?, table: String, column: String) -> Bool {
        var stmt: OpaquePointer?
        let query = "PRAGMA table_info(\(table))"
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

    private static func markCompleted() {
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
