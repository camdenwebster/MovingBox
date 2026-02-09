import Foundation
import GRDB
import SQLiteData
import UIKit

// MARK: - Table Definitions

@Table("inventoryItemPhotos")
nonisolated struct SQLiteInventoryItemPhoto: Hashable, Identifiable {
    let id: UUID
    var inventoryItemID: SQLiteInventoryItem.ID
    var data: Data
    var sortOrder: Int = 0
}

@Table("homePhotos")
nonisolated struct SQLiteHomePhoto: Hashable, Identifiable {
    let id: UUID
    var homeID: SQLiteHome.ID
    var data: Data
    var sortOrder: Int = 0
}

@Table("inventoryLocationPhotos")
nonisolated struct SQLiteInventoryLocationPhoto: Hashable, Identifiable {
    let id: UUID
    var inventoryLocationID: SQLiteInventoryLocation.ID
    var data: Data
    var sortOrder: Int = 0
}

// MARK: - Inventory Item Photo Queries

extension SQLiteInventoryItemPhoto {
    static func photos(for itemID: UUID, in db: Database) throws -> [Self] {
        try Self
            .where { $0.inventoryItemID == itemID }
            .order { $0.sortOrder.asc() }
            .fetchAll(db)
    }

    static func primaryPhoto(for itemID: UUID, in db: Database) throws -> Self? {
        try Self
            .where { $0.inventoryItemID == itemID }
            .order { $0.sortOrder.asc() }
            .limit(1)
            .fetchOne(db)
    }

    static func primaryImage(for itemID: UUID, in db: Database) throws -> UIImage? {
        guard let photo = try primaryPhoto(for: itemID, in: db) else { return nil }
        return UIImage(data: photo.data)
    }
}

// MARK: - Home Photo Queries

extension SQLiteHomePhoto {
    static func photos(for homeID: UUID, in db: Database) throws -> [Self] {
        try Self
            .where { $0.homeID == homeID }
            .order { $0.sortOrder.asc() }
            .fetchAll(db)
    }

    static func primaryPhoto(for homeID: UUID, in db: Database) throws -> Self? {
        try Self
            .where { $0.homeID == homeID }
            .order { $0.sortOrder.asc() }
            .limit(1)
            .fetchOne(db)
    }

    static func primaryImage(for homeID: UUID, in db: Database) throws -> UIImage? {
        guard let photo = try primaryPhoto(for: homeID, in: db) else { return nil }
        return UIImage(data: photo.data)
    }
}

// MARK: - Location Photo Queries

extension SQLiteInventoryLocationPhoto {
    static func photos(for locationID: UUID, in db: Database) throws -> [Self] {
        try Self
            .where { $0.inventoryLocationID == locationID }
            .order { $0.sortOrder.asc() }
            .fetchAll(db)
    }

    static func primaryPhoto(for locationID: UUID, in db: Database) throws -> Self? {
        try Self
            .where { $0.inventoryLocationID == locationID }
            .order { $0.sortOrder.asc() }
            .limit(1)
            .fetchOne(db)
    }

    static func primaryImage(for locationID: UUID, in db: Database) throws -> UIImage? {
        guard let photo = try primaryPhoto(for: locationID, in: db) else { return nil }
        return UIImage(data: photo.data)
    }
}
