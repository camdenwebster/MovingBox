import Foundation
import GRDB
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "com.mothersound.movingbox", category: "HomeCulling")

/// One-time cleanup that removes empty homes accumulated from pre-2.2.0 onboarding re-runs.
///
/// Pre-2.2.0 versions used `homes.last` (ordered by `purchaseDate`) to pick the active home.
/// Users who re-ran onboarding could accumulate multiple empty homes that were never visible.
/// On upgrade to 2.2.0 (first version with multi-home), these phantom homes would suddenly
/// appear in the sidebar. This manager culls them once.
struct HomeCullingManager {

    private static let cullingCompleteKey =
        "com.mothersound.movingbox.homeCulling.2_2_0.complete"

    /// Runs the one-time cull. No-op if already completed.
    ///
    /// - Returns: The ID of a culled home that was previously the `activeHomeId`,
    ///   or `nil` if the active home was kept. The caller should update
    ///   `SettingsManager.activeHomeId` when non-nil.
    @MainActor
    static func cullIfNeeded(
        database: any DatabaseWriter,
        activeHomeId: String?
    ) async -> String? {
        guard !UserDefaults.standard.bool(forKey: cullingCompleteKey) else { return nil }

        do {
            let replacementActiveId = try await performCulling(
                database: database,
                activeHomeId: activeHomeId
            )
            UserDefaults.standard.set(true, forKey: cullingCompleteKey)
            logger.info("Home culling completed successfully")
            return replacementActiveId
        } catch {
            // Log but don't block app launch — phantom homes are cosmetic, not fatal
            logger.error("Home culling failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// - Returns: A replacement `activeHomeId` if the current one was culled, else `nil`.
    private static func performCulling(
        database: any DatabaseWriter,
        activeHomeId: String?
    ) async throws -> String? {
        try await database.write { db in
            // 1. Fetch all homes with usage data in a single query
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT h.id,
                        (SELECT COUNT(*) FROM inventoryItems WHERE homeID = h.id) +
                        (SELECT COUNT(*) FROM inventoryItems WHERE locationID IN
                            (SELECT id FROM inventoryLocations WHERE homeID = h.id)) AS itemCount,
                        (SELECT COUNT(*) FROM homeInsurancePolicies WHERE homeID = h.id) AS policyCount,
                        CASE WHEN (h.name != '' AND h.name != 'My Home')
                            OR h.address1 != '' OR h.city != '' OR h.imageURL IS NOT NULL
                        THEN 1 ELSE 0 END AS hasMetadata
                    FROM homes h ORDER BY h.purchaseDate ASC
                    """)

            guard rows.count > 1 else {
                logger.info("Only \(rows.count) home(s) found, no culling needed")
                return nil
            }

            // 2. Determine which homes have user content or metadata
            var homesInUse: Set<String> = []

            for row in rows {
                let homeID: String = row["id"]
                let itemCount: Int = row["itemCount"]
                let policyCount: Int = row["policyCount"]
                let hasMetadata: Bool = row["hasMetadata"]

                if itemCount + policyCount > 0 || hasMetadata {
                    homesInUse.insert(homeID)
                }
            }

            let allHomes = rows

            // 3. Determine which homes to keep
            let allHomeIDs = allHomes.map { $0["id"] as String }
            let homesToKeep: Set<String>

            if homesInUse.isEmpty {
                // ALL homes are empty — keep only the last one (matches old homes.last behavior)
                if let lastHomeID = allHomeIDs.last {
                    homesToKeep = [lastHomeID]
                    logger.info("All homes empty; keeping last home: \(lastHomeID)")
                } else {
                    return nil
                }
            } else {
                homesToKeep = homesInUse
            }

            let homesToCull = allHomeIDs.filter { !homesToKeep.contains($0) }

            guard !homesToCull.isEmpty else {
                logger.info("No empty homes to cull")
                return nil
            }

            logger.info("Culling \(homesToCull.count) empty home(s), keeping \(homesToKeep.count)")

            // 4. Delete locations belonging to homes being culled
            //    (FK is ON DELETE SET NULL, so we delete explicitly to avoid orphans)
            for homeID in homesToCull {
                try db.execute(
                    sql: """
                        DELETE FROM inventoryLocations WHERE homeID = ?
                        """, arguments: [homeID])
            }

            // 5. Delete the empty homes
            let placeholders = homesToCull.map { _ in "?" }.joined(separator: ", ")
            try db.execute(
                sql: "DELETE FROM homes WHERE id IN (\(placeholders))",
                arguments: StatementArguments(homesToCull)
            )

            // 6. Check if activeHomeId was culled
            if let currentActiveId = activeHomeId, homesToCull.contains(currentActiveId) {
                let remainingIDs = allHomeIDs.filter { homesToKeep.contains($0) }
                let newActiveId = remainingIDs.last
                logger.info(
                    "Active home was culled; suggesting replacement: \(newActiveId ?? "nil")")
                return newActiveId
            }

            return nil
        }
    }
}
