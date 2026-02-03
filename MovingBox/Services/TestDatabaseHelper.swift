import Foundation
import SQLiteData

/// Creates an in-memory sqlite-data database with all migrations applied.
/// Used by unit tests via `@testable import MovingBox`.
func makeInMemoryDatabase() throws -> DatabaseQueue {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    let db = try DatabaseQueue(configuration: configuration)

    var migrator = DatabaseMigrator()
    registerMigrations(&migrator)
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
