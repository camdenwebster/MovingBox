import Foundation
import SQLiteData
import Testing

@testable import MovingBox

@MainActor
@Suite struct InventoryListViewDeletionTests {

    private func createTestItems(in database: DatabaseQueue) async throws -> [SQLiteInventoryItem] {
        let items = [
            SQLiteInventoryItem(
                id: UUID(),
                title: "Test Item 1",
                quantityString: "1",
                quantityInt: 1,
                desc: "Description 1",
                serial: "123",
                model: "Model1",
                make: "Make1",
                price: Decimal(10.0),
                insured: false,
                assetId: "asset1",
                notes: "Notes 1"
            ),
            SQLiteInventoryItem(
                id: UUID(),
                title: "Test Item 2",
                quantityString: "1",
                quantityInt: 1,
                desc: "Description 2",
                serial: "456",
                model: "Model2",
                make: "Make2",
                price: Decimal(20.0),
                insured: false,
                assetId: "asset2",
                notes: "Notes 2"
            ),
            SQLiteInventoryItem(
                id: UUID(),
                title: "Test Item 3",
                quantityString: "1",
                quantityInt: 1,
                desc: "Description 3",
                serial: "789",
                model: "Model3",
                make: "Make3",
                price: Decimal(30.0),
                insured: false,
                assetId: "asset3",
                notes: "Notes 3"
            ),
        ]

        try await database.write { db in
            for item in items {
                try SQLiteInventoryItem.insert { item }.execute(db)
            }
        }

        return items
    }

    @Test("Delete function removes selected items from context")
    func testDeleteFunctionRemovesItems() async throws {
        let database = try makeInMemoryDatabase()
        let testItems = try await createTestItems(in: database)

        let initialItems = try await database.read { db in
            try SQLiteInventoryItem.fetchAll(db)
        }
        #expect(initialItems.count == 3)

        let itemsToDelete = [testItems[0], testItems[2]]

        try await database.write { db in
            for item in itemsToDelete {
                try SQLiteInventoryItem.find(item.id).delete().execute(db)
            }
        }

        let remainingItems = try await database.read { db in
            try SQLiteInventoryItem.fetchAll(db)
        }

        #expect(remainingItems.count == 1)
        #expect(remainingItems[0].title == "Test Item 2")
    }

    @Test("Delete function with selectedItems property correctly identifies items to delete")
    func testSelectedItemsPropertyFiltering() async throws {
        let database = try makeInMemoryDatabase()
        let testItems = try await createTestItems(in: database)

        let selectedItemIDs = Set([testItems[0].id, testItems[1].id])

        let allItems = try await database.read { db in
            try SQLiteInventoryItem.fetchAll(db)
        }
        let selectedItems = allItems.filter { selectedItemIDs.contains($0.id) }

        #expect(selectedItems.count == 2)
        #expect(selectedItems.contains { $0.title == "Test Item 1" })
        #expect(selectedItems.contains { $0.title == "Test Item 2" })
        #expect(!selectedItems.contains { $0.title == "Test Item 3" })
    }

    @Test("Delete function preserves unselected items")
    func testDeleteFunctionPreservesUnselectedItems() async throws {
        let database = try makeInMemoryDatabase()
        let testItems = try await createTestItems(in: database)

        let selectedItemIDs = Set([testItems[1].id])

        let allItems = try await database.read { db in
            try SQLiteInventoryItem.fetchAll(db)
        }
        let selectedItems = allItems.filter { selectedItemIDs.contains($0.id) }

        try await database.write { db in
            for item in selectedItems {
                try SQLiteInventoryItem.find(item.id).delete().execute(db)
            }
        }

        let remainingItems = try await database.read { db in
            try SQLiteInventoryItem.fetchAll(db)
        }

        #expect(remainingItems.count == 2)
        #expect(remainingItems.contains { $0.title == "Test Item 1" })
        #expect(remainingItems.contains { $0.title == "Test Item 3" })
        #expect(!remainingItems.contains { $0.title == "Test Item 2" })
    }

    @Test("Delete function handles empty selection gracefully")
    func testDeleteFunctionWithEmptySelection() async throws {
        let database = try makeInMemoryDatabase()
        _ = try await createTestItems(in: database)

        let selectedItemIDs: Set<UUID> = Set()

        let allItems = try await database.read { db in
            try SQLiteInventoryItem.fetchAll(db)
        }
        let selectedItems = allItems.filter { selectedItemIDs.contains($0.id) }

        try await database.write { db in
            for item in selectedItems {
                try SQLiteInventoryItem.find(item.id).delete().execute(db)
            }
        }

        let remainingItems = try await database.read { db in
            try SQLiteInventoryItem.fetchAll(db)
        }

        #expect(remainingItems.count == 3)
    }
}
