import Foundation
import GRDB
import OSLog
import SQLiteData
import UIKit

private let logger = Logger(subsystem: "com.mothersound.movingbox", category: "PhotoMigration")

/// Migrates photo files from iCloud Drive / Documents into BLOB columns in the
/// new per-entity photo tables. Runs once at first launch of v2.2.0, after
/// schema migrations have created the photo tables.
struct PhotoBlobMigrationCoordinator {

    enum MigrationResult {
        case noPhotos
        case alreadyCompleted
        case success(stats: MigrationStats)
        case error(String)
    }

    struct MigrationStats: CustomStringConvertible {
        var itemPhotos = 0
        var homePhotos = 0
        var locationPhotos = 0
        var filesCleanedUp = 0
        var errors = 0

        var description: String {
            "itemPhotos=\(itemPhotos), homePhotos=\(homePhotos), locationPhotos=\(locationPhotos), filesCleanedUp=\(filesCleanedUp), errors=\(errors)"
        }
    }

    private static let migrationCompleteKey = "com.mothersound.movingbox.photo.blob.migration.complete"
    private static let migrationAttemptsKey = "com.mothersound.movingbox.photo.blob.migration.attempts"
    private static let maxAttempts = 3

    // MARK: - Public API

    static func migrateIfNeeded(database: any DatabaseWriter) async -> MigrationResult {
        guard !UserDefaults.standard.bool(forKey: migrationCompleteKey) else {
            return .alreadyCompleted
        }

        let attempts = UserDefaults.standard.integer(forKey: migrationAttemptsKey)
        if attempts >= maxAttempts {
            let msg = "Photo migration abandoned after \(attempts) failed attempts"
            logger.error("\(msg)")
            return .error(msg)
        }
        UserDefaults.standard.set(attempts + 1, forKey: migrationAttemptsKey)

        do {
            let stats = try await performMigration(database: database)
            if stats.itemPhotos == 0 && stats.homePhotos == 0 && stats.locationPhotos == 0 {
                markComplete()
                UserDefaults.standard.removeObject(forKey: migrationAttemptsKey)
                logger.info("No photos to migrate")
                return .noPhotos
            }
            markComplete()
            UserDefaults.standard.removeObject(forKey: migrationAttemptsKey)
            logger.info("Photo migration succeeded: \(stats.description)")
            return .success(stats: stats)
        } catch {
            logger.error("Photo migration failed: \(error.localizedDescription)")
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Migration Core

    private static func performMigration(database: any DatabaseWriter) async throws -> MigrationStats {
        var stats = MigrationStats()

        // Read all entities with photo URLs from the database
        let itemPhotos: [Row] = try await database.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT "id", "imageURL", "secondaryPhotoURLs" FROM "inventoryItems"
                    WHERE "imageURL" IS NOT NULL OR ("secondaryPhotoURLs" IS NOT NULL AND "secondaryPhotoURLs" != '[]')
                    """)
        }

        let homePhotos: [Row] = try await database.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT "id", "imageURL", "secondaryPhotoURLs" FROM "homes"
                    WHERE "imageURL" IS NOT NULL OR ("secondaryPhotoURLs" IS NOT NULL AND "secondaryPhotoURLs" != '[]')
                    """)
        }

        let locationPhotos: [Row] = try await database.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT "id", "imageURL", "secondaryPhotoURLs" FROM "inventoryLocations"
                    WHERE "imageURL" IS NOT NULL OR ("secondaryPhotoURLs" IS NOT NULL AND "secondaryPhotoURLs" != '[]')
                    """)
        }

        // Migrate each entity type
        for row in itemPhotos {
            let entityID: String = row["id"]
            let urls = collectPhotoURLs(
                imageURL: row["imageURL"] as String?,
                secondaryPhotoURLsJSON: row["secondaryPhotoURLs"] as String?
            )
            let migrated = await migratePhotos(
                urls: urls,
                entityID: entityID,
                table: "inventoryItemPhotos",
                fkColumn: "inventoryItemID",
                database: database
            )
            stats.itemPhotos += migrated.count
            stats.errors += migrated.errors
        }

        for row in homePhotos {
            let entityID: String = row["id"]
            let urls = collectPhotoURLs(
                imageURL: row["imageURL"] as String?,
                secondaryPhotoURLsJSON: row["secondaryPhotoURLs"] as String?
            )
            let migrated = await migratePhotos(
                urls: urls,
                entityID: entityID,
                table: "homePhotos",
                fkColumn: "homeID",
                database: database
            )
            stats.homePhotos += migrated.count
            stats.errors += migrated.errors
        }

        for row in locationPhotos {
            let entityID: String = row["id"]
            let urls = collectPhotoURLs(
                imageURL: row["imageURL"] as String?,
                secondaryPhotoURLsJSON: row["secondaryPhotoURLs"] as String?
            )
            let migrated = await migratePhotos(
                urls: urls,
                entityID: entityID,
                table: "inventoryLocationPhotos",
                fkColumn: "inventoryLocationID",
                database: database
            )
            stats.locationPhotos += migrated.count
            stats.errors += migrated.errors
        }

        // Clear old URL columns after all photos are migrated
        try await database.write { db in
            try db.execute(
                sql: """
                    UPDATE "inventoryItems" SET "imageURL" = NULL, "secondaryPhotoURLs" = '[]'
                    WHERE "imageURL" IS NOT NULL OR "secondaryPhotoURLs" != '[]'
                    """)
            try db.execute(
                sql: """
                    UPDATE "homes" SET "imageURL" = NULL, "secondaryPhotoURLs" = '[]'
                    WHERE "imageURL" IS NOT NULL OR "secondaryPhotoURLs" != '[]'
                    """)
            try db.execute(
                sql: """
                    UPDATE "inventoryLocations" SET "imageURL" = NULL, "secondaryPhotoURLs" = '[]'
                    WHERE "imageURL" IS NOT NULL OR "secondaryPhotoURLs" != '[]'
                    """)
        }

        // Clean up old photo files
        stats.filesCleanedUp = cleanupOldPhotoFiles()

        return stats
    }

    // MARK: - Photo File Reading

    private struct PhotoMigrationResult {
        var count: Int
        var errors: Int
    }

    private static func migratePhotos(
        urls: [URL],
        entityID: String,
        table: String,
        fkColumn: String,
        database: any DatabaseWriter
    ) async -> PhotoMigrationResult {
        var result = PhotoMigrationResult(count: 0, errors: 0)

        for (sortOrder, url) in urls.enumerated() {
            do {
                let data = try loadPhotoData(from: url)
                let photoID = UUID().uuidString.lowercased()

                try await database.write { db in
                    try db.execute(
                        sql: """
                            INSERT INTO "\(table)" ("id", "\(fkColumn)", "data", "sortOrder")
                            VALUES (?, ?, ?, ?)
                            """,
                        arguments: [photoID, entityID, data, sortOrder]
                    )
                }
                result.count += 1
                logger.debug("Migrated photo \(sortOrder) for \(table) entity \(entityID)")
            } catch {
                logger.warning("Failed to migrate photo at \(url.path): \(error.localizedDescription)")
                result.errors += 1
            }
        }

        return result
    }

    private static func loadPhotoData(from url: URL) throws -> Data {
        // Try direct file access first
        if FileManager.default.fileExists(atPath: url.path) {
            return try Data(contentsOf: url)
        }

        // Try reconstructing path via OptimizedImageManager's known directories
        let id = url.deletingPathExtension().lastPathComponent
        let possiblePaths = photoSearchPaths(for: id)

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return try Data(contentsOf: path)
            }
        }

        throw PhotoMigrationError.fileNotFound(url.path)
    }

    private static func photoSearchPaths(for id: String) -> [URL] {
        var paths: [URL] = []

        // iCloud Drive ubiquitous container
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let iCloudImages = containerURL.appendingPathComponent("Images")
            paths.append(iCloudImages.appendingPathComponent("\(id).jpg"))
        }

        // Documents directory fallback
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let documentsImages = documentsURL.appendingPathComponent("Images", isDirectory: true)
        paths.append(documentsImages.appendingPathComponent("\(id).jpg"))

        return paths
    }

    // MARK: - URL Parsing

    private static func collectPhotoURLs(imageURL: String?, secondaryPhotoURLsJSON: String?) -> [URL] {
        var urls: [URL] = []

        // Primary photo first (sortOrder 0)
        if let urlString = imageURL, let url = URL(string: urlString) {
            urls.append(url)
        }

        // Secondary photos (sortOrder 1, 2, ...)
        if let json = secondaryPhotoURLsJSON,
            json != "[]",
            let data = json.data(using: .utf8),
            let array = try? JSONDecoder().decode([String].self, from: data)
        {
            for urlString in array {
                if let url = URL(string: urlString) {
                    urls.append(url)
                }
            }
        }

        return urls
    }

    // MARK: - Cleanup

    private static func cleanupOldPhotoFiles() -> Int {
        var count = 0

        // Clean iCloud Drive Images directory
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let iCloudImages = containerURL.appendingPathComponent("Images")
            count += removeDirectoryContents(at: iCloudImages)
        }

        // Clean Documents/Images directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let documentsImages = documentsURL.appendingPathComponent("Images", isDirectory: true)
        count += removeDirectoryContents(at: documentsImages)

        return count
    }

    private static func removeDirectoryContents(at url: URL) -> Int {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return 0 }

        var count = 0
        do {
            let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            for fileURL in contents {
                do {
                    try fm.removeItem(at: fileURL)
                    count += 1
                } catch {
                    logger.warning("Failed to remove \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
            // Try to remove the directory itself
            try? fm.removeItem(at: url)
        } catch {
            logger.warning("Failed to enumerate \(url.path): \(error.localizedDescription)")
        }
        return count
    }

    // MARK: - Completion

    private static func markComplete() {
        UserDefaults.standard.set(true, forKey: migrationCompleteKey)
    }
}

enum PhotoMigrationError: LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Photo file not found: \(path)"
        }
    }
}
