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
    private func createItemWithPrimaryImage(in database: DatabaseQueue) throws -> SQLiteInventoryItem {
        var item = SQLiteInventoryItem(id: UUID(), title: "Item with Primary Image")
        item.imageURL = URL(string: "file:///test/primary.jpg")
        try database.write { db in
            try SQLiteInventoryItem.insert { item }.execute(db)
        }
        return item
    }

    @MainActor
    private func createItemWithSecondaryImages(in database: DatabaseQueue) throws -> SQLiteInventoryItem {
        var item = SQLiteInventoryItem(id: UUID(), title: "Item with Secondary Images")
        item.secondaryPhotoURLs = ["file:///test/secondary1.jpg", "file:///test/secondary2.jpg"]
        try database.write { db in
            try SQLiteInventoryItem.insert { item }.execute(db)
        }
        return item
    }

    @MainActor
    private func createItemWithBothImages(in database: DatabaseQueue) throws -> SQLiteInventoryItem {
        var item = SQLiteInventoryItem(id: UUID(), title: "Item with Both Images")
        item.imageURL = URL(string: "file:///test/primary.jpg")
        item.secondaryPhotoURLs = ["file:///test/secondary1.jpg"]
        try database.write { db in
            try SQLiteInventoryItem.insert { item }.execute(db)
        }
        return item
    }

    @MainActor
    private func createItemWithNoImages(in database: DatabaseQueue) throws -> SQLiteInventoryItem {
        let item = SQLiteInventoryItem(id: UUID(), title: "Item with No Images")
        try database.write { db in
            try SQLiteInventoryItem.insert { item }.execute(db)
        }
        return item
    }

    // MARK: - Test Helper Functions

    @MainActor
    func hasAnalyzableImage(_ item: SQLiteInventoryItem) -> Bool {
        if let imageURL = item.imageURL,
            !imageURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return true
        }

        if !item.secondaryPhotoURLs.isEmpty {
            let validURLs = item.secondaryPhotoURLs.filter { url in
                !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !validURLs.isEmpty {
                return true
            }
        }

        return false
    }

    @MainActor
    func hasImagesInSelection(selectedItemIDs: Set<UUID>, allItems: [SQLiteInventoryItem])
        -> Bool
    {
        guard !selectedItemIDs.isEmpty else { return false }
        return allItems.contains { item in
            guard selectedItemIDs.contains(item.id) else { return false }
            return hasAnalyzableImage(item)
        }
    }

    // MARK: - Image Detection Logic Tests

    @Test("hasImagesInSelection should detect primary image")
    @MainActor
    func testHasImagesInSelectionWithPrimaryImage() throws {
        let database = try makeInMemoryDatabase()

        let item = try createItemWithPrimaryImage(in: database)

        let selectedItemIDs: Set<UUID> = [item.id]
        let allItems = [item]

        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )

        #expect(hasImages == true)
    }

    @Test("hasImagesInSelection should detect secondary images")
    @MainActor
    func testHasImagesInSelectionWithSecondaryImages() throws {
        let database = try makeInMemoryDatabase()

        let item = try createItemWithSecondaryImages(in: database)

        let selectedItemIDs: Set<UUID> = [item.id]
        let allItems = [item]

        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )

        #expect(hasImages == true)
    }

    @Test("hasImagesInSelection should detect both image types")
    @MainActor
    func testHasImagesInSelectionWithBothImages() throws {
        let database = try makeInMemoryDatabase()

        let item = try createItemWithBothImages(in: database)

        let selectedItemIDs: Set<UUID> = [item.id]
        let allItems = [item]

        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )

        #expect(hasImages == true)
    }

    @Test("hasImagesInSelection should return false for no images")
    @MainActor
    func testHasImagesInSelectionWithNoImages() throws {
        let database = try makeInMemoryDatabase()

        let item = try createItemWithNoImages(in: database)

        let selectedItemIDs: Set<UUID> = [item.id]
        let allItems = [item]

        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )

        #expect(hasImages == false)
    }

    @Test("hasImagesInSelection should handle mixed selection")
    @MainActor
    func testHasImagesInSelectionMixed() throws {
        let database = try makeInMemoryDatabase()

        let itemWithImages = try createItemWithPrimaryImage(in: database)
        let itemWithoutImages = try createItemWithNoImages(in: database)

        let selectedItemIDs: Set<UUID> = [
            itemWithImages.id,
            itemWithoutImages.id,
        ]
        let allItems = [itemWithImages, itemWithoutImages]

        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )

        #expect(hasImages == true)
    }

    @Test("hasImagesInSelection should return false for empty selection")
    @MainActor
    func testHasImagesInSelectionEmptySelection() throws {
        let database = try makeInMemoryDatabase()

        let item = try createItemWithPrimaryImage(in: database)

        let selectedItemIDs: Set<UUID> = []
        let allItems = [item]

        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )

        #expect(hasImages == false)
    }

    // MARK: - BatchAnalysisView Filter Logic Tests

    @Test("BatchAnalysisView filter should work correctly")
    @MainActor
    func testBatchAnalysisViewFilter() throws {
        let database = try makeInMemoryDatabase()

        let itemWithPrimary = try createItemWithPrimaryImage(in: database)
        let itemWithSecondary = try createItemWithSecondaryImages(in: database)
        let itemWithNoImages = try createItemWithNoImages(in: database)

        let allItems = [itemWithPrimary, itemWithSecondary, itemWithNoImages]

        let itemsWithImages = allItems.filter { hasAnalyzableImage($0) }

        #expect(itemsWithImages.count == 2)
        #expect(itemsWithImages.contains(where: { $0.id == itemWithPrimary.id }))
        #expect(itemsWithImages.contains(where: { $0.id == itemWithSecondary.id }))
        #expect(!itemsWithImages.contains(where: { $0.id == itemWithNoImages.id }))
    }

    // MARK: - Edge Cases and Error Conditions

    @Test("should handle empty imageURL")
    @MainActor
    func testEmptyImageURL() throws {
        let database = try makeInMemoryDatabase()

        var item = SQLiteInventoryItem(id: UUID(), title: "Item with empty URL")
        item.imageURL = URL(string: "")
        try database.write { db in
            try SQLiteInventoryItem.insert { item }.execute(db)
        }

        let selectedItemIDs: Set<UUID> = [item.id]
        let allItems = [item]

        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )

        #expect(hasImages == false)
    }

    @Test("should handle empty secondaryPhotoURLs array")
    @MainActor
    func testEmptySecondaryPhotoURLs() throws {
        let database = try makeInMemoryDatabase()

        var item = SQLiteInventoryItem(id: UUID(), title: "Item with empty secondary array")
        item.secondaryPhotoURLs = []
        try database.write { db in
            try SQLiteInventoryItem.insert { item }.execute(db)
        }

        let selectedItemIDs: Set<UUID> = [item.id]
        let allItems = [item]

        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )

        #expect(hasImages == false)
    }

    @Test("should handle secondaryPhotoURLs with empty strings")
    @MainActor
    func testSecondaryPhotoURLsWithEmptyStrings() throws {
        let database = try makeInMemoryDatabase()

        var item = SQLiteInventoryItem(id: UUID(), title: "Item with empty string URLs")
        item.secondaryPhotoURLs = ["", "  ", ""]
        try database.write { db in
            try SQLiteInventoryItem.insert { item }.execute(db)
        }

        let selectedItemIDs: Set<UUID> = [item.id]
        let allItems = [item]

        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )

        #expect(hasImages == false)
    }
}
