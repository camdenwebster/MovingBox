//
//  BatchAnalysisTests.swift
//  MovingBoxTests
//
//  Created by Claude on 8/20/25.
//

import SQLiteData
import Testing
import UIKit

@testable import MovingBox

@Suite struct BatchAnalysisTests {

    // MARK: - Test Data Setup

    @MainActor
    private func createItemWithPhoto(in database: DatabaseQueue) throws -> SQLiteInventoryItem {
        let item = SQLiteInventoryItem(id: UUID(), title: "Item with Photo")
        let imageData = UIImage(systemName: "star.fill")!.pngData()!
        try database.write { db in
            try SQLiteInventoryItem.insert { item }.execute(db)
            try SQLiteInventoryItemPhoto.insert {
                SQLiteInventoryItemPhoto(id: UUID(), inventoryItemID: item.id, data: imageData)
            }.execute(db)
        }
        return item
    }

    @MainActor
    private func createItemWithMultiplePhotos(in database: DatabaseQueue) throws -> SQLiteInventoryItem {
        let item = SQLiteInventoryItem(id: UUID(), title: "Item with Multiple Photos")
        let imageData = UIImage(systemName: "star.fill")!.pngData()!
        try database.write { db in
            try SQLiteInventoryItem.insert { item }.execute(db)
            try SQLiteInventoryItemPhoto.insert {
                SQLiteInventoryItemPhoto(id: UUID(), inventoryItemID: item.id, data: imageData, sortOrder: 0)
            }.execute(db)
            try SQLiteInventoryItemPhoto.insert {
                SQLiteInventoryItemPhoto(id: UUID(), inventoryItemID: item.id, data: imageData, sortOrder: 1)
            }.execute(db)
        }
        return item
    }

    @MainActor
    private func createItemWithNoPhotos(in database: DatabaseQueue) throws -> SQLiteInventoryItem {
        let item = SQLiteInventoryItem(id: UUID(), title: "Item with No Photos")
        try database.write { db in
            try SQLiteInventoryItem.insert { item }.execute(db)
        }
        return item
    }

    // MARK: - Test Helper Functions

    @MainActor
    func hasAnalyzableImage(_ itemID: UUID, in database: DatabaseQueue) throws -> Bool {
        let count = try database.read { db in
            try SQLiteInventoryItemPhoto.where { $0.inventoryItemID == itemID }.fetchCount(db)
        }
        return count > 0
    }

    @MainActor
    func hasImagesInSelection(selectedItemIDs: Set<UUID>, in database: DatabaseQueue) throws -> Bool {
        guard !selectedItemIDs.isEmpty else { return false }
        return try selectedItemIDs.contains { itemID in
            try hasAnalyzableImage(itemID, in: database)
        }
    }

    // MARK: - Image Detection Logic Tests

    @Test("hasImagesInSelection should detect photo")
    @MainActor
    func testHasImagesInSelectionWithPhoto() throws {
        let database = try makeInMemoryDatabase()
        let item = try createItemWithPhoto(in: database)

        let result = try hasImagesInSelection(selectedItemIDs: [item.id], in: database)
        #expect(result == true)
    }

    @Test("hasImagesInSelection should detect multiple photos")
    @MainActor
    func testHasImagesInSelectionWithMultiplePhotos() throws {
        let database = try makeInMemoryDatabase()
        let item = try createItemWithMultiplePhotos(in: database)

        let result = try hasImagesInSelection(selectedItemIDs: [item.id], in: database)
        #expect(result == true)
    }

    @Test("hasImagesInSelection should return false for no photos")
    @MainActor
    func testHasImagesInSelectionWithNoPhotos() throws {
        let database = try makeInMemoryDatabase()
        let item = try createItemWithNoPhotos(in: database)

        let result = try hasImagesInSelection(selectedItemIDs: [item.id], in: database)
        #expect(result == false)
    }

    @Test("hasImagesInSelection should handle mixed selection")
    @MainActor
    func testHasImagesInSelectionMixed() throws {
        let database = try makeInMemoryDatabase()
        let itemWithPhotos = try createItemWithPhoto(in: database)
        let itemWithoutPhotos = try createItemWithNoPhotos(in: database)

        let result = try hasImagesInSelection(
            selectedItemIDs: [itemWithPhotos.id, itemWithoutPhotos.id],
            in: database
        )
        #expect(result == true)
    }

    @Test("hasImagesInSelection should return false for empty selection")
    @MainActor
    func testHasImagesInSelectionEmptySelection() throws {
        let database = try makeInMemoryDatabase()
        _ = try createItemWithPhoto(in: database)

        let result = try hasImagesInSelection(selectedItemIDs: [], in: database)
        #expect(result == false)
    }

    // MARK: - Filter Logic Tests

    @Test("Filter should correctly separate items with and without photos")
    @MainActor
    func testFilterLogic() throws {
        let database = try makeInMemoryDatabase()

        let itemWithPhoto = try createItemWithPhoto(in: database)
        let itemWithMultiple = try createItemWithMultiplePhotos(in: database)
        let itemWithNone = try createItemWithNoPhotos(in: database)

        let allItems = [itemWithPhoto, itemWithMultiple, itemWithNone]

        let itemsWithPhotos = try allItems.filter { item in
            try hasAnalyzableImage(item.id, in: database)
        }

        #expect(itemsWithPhotos.count == 2)
        #expect(itemsWithPhotos.contains(where: { $0.id == itemWithPhoto.id }))
        #expect(itemsWithPhotos.contains(where: { $0.id == itemWithMultiple.id }))
        #expect(!itemsWithPhotos.contains(where: { $0.id == itemWithNone.id }))
    }
}
