import Testing
import Foundation
import SwiftData
@testable import MovingBox

@MainActor
@Suite struct InventoryListViewDeletionTests {
    
    // Test helper to create in-memory model container
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            Home.self,
            InsurancePolicy.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
    
    // Test helper to create test data
    private func createTestItems(in context: ModelContext) throws -> [InventoryItem] {
        let items = [
            InventoryItem(
                title: "Test Item 1",
                quantityString: "1",
                quantityInt: 1,
                desc: "Description 1",
                serial: "123",
                model: "Model1",
                make: "Make1",
                location: nil,
                label: nil,
                price: Decimal(10.0),
                insured: false,
                assetId: "asset1",
                notes: "Notes 1",
                showInvalidQuantityAlert: false
            ),
            InventoryItem(
                title: "Test Item 2", 
                quantityString: "1",
                quantityInt: 1,
                desc: "Description 2",
                serial: "456",
                model: "Model2",
                make: "Make2",
                location: nil,
                label: nil,
                price: Decimal(20.0),
                insured: false,
                assetId: "asset2",
                notes: "Notes 2",
                showInvalidQuantityAlert: false
            ),
            InventoryItem(
                title: "Test Item 3",
                quantityString: "1", 
                quantityInt: 1,
                desc: "Description 3",
                serial: "789",
                model: "Model3",
                make: "Make3",
                location: nil,
                label: nil,
                price: Decimal(30.0),
                insured: false,
                assetId: "asset3",
                notes: "Notes 3",
                showInvalidQuantityAlert: false
            )
        ]
        
        for item in items {
            context.insert(item)
        }
        
        try context.save()
        return items
    }
    
    @Test("Delete function removes selected items from context")
    func testDeleteFunctionRemovesItems() async throws {
        // Given: A model container with test items
        let container = try createTestContainer()
        let context = container.mainContext
        let testItems = try createTestItems(in: context)
        
        // Verify initial state
        let initialDescriptor = FetchDescriptor<InventoryItem>()
        let initialItems = try context.fetch(initialDescriptor)
        #expect(initialItems.count == 3)
        
        // When: We simulate the delete function logic
        let itemsToDelete = [testItems[0], testItems[2]] // Delete items 1 and 3
        
        for item in itemsToDelete {
            context.delete(item)
        }
        
        try context.save()
        
        // Then: Only the non-deleted items should remain
        let remainingDescriptor = FetchDescriptor<InventoryItem>()
        let remainingItems = try context.fetch(remainingDescriptor)
        
        #expect(remainingItems.count == 1)
        #expect(remainingItems[0].title == "Test Item 2")
    }
    
    @Test("Delete function with selectedItems property correctly identifies items to delete")
    func testSelectedItemsPropertyFiltering() async throws {
        // Given: A model container with test items
        let container = try createTestContainer()
        let context = container.mainContext
        let testItems = try createTestItems(in: context)
        
        // And: A set of selected item IDs (simulating selectedItemIDs)
        let selectedItemIDs = Set([testItems[0].persistentModelID, testItems[1].persistentModelID])
        
        // When: We simulate how selectedItems property works
        let allItemsDescriptor = FetchDescriptor<InventoryItem>()
        let allItems = try context.fetch(allItemsDescriptor)
        let selectedItems = allItems.filter { selectedItemIDs.contains($0.persistentModelID) }
        
        // Then: The correct items should be selected
        #expect(selectedItems.count == 2)
        #expect(selectedItems.contains { $0.title == "Test Item 1" })
        #expect(selectedItems.contains { $0.title == "Test Item 2" })
        #expect(!selectedItems.contains { $0.title == "Test Item 3" })
    }
    
    @Test("Delete function preserves unselected items")
    func testDeleteFunctionPreservesUnselectedItems() async throws {
        // Given: A model container with test items
        let container = try createTestContainer()
        let context = container.mainContext
        let testItems = try createTestItems(in: context)
        
        // And: Only one item is selected for deletion
        let selectedItemIDs = Set([testItems[1].persistentModelID]) // Select middle item
        
        let allItemsDescriptor = FetchDescriptor<InventoryItem>()
        let allItems = try context.fetch(allItemsDescriptor)
        let selectedItems = allItems.filter { selectedItemIDs.contains($0.persistentModelID) }
        
        // When: We delete the selected items
        for item in selectedItems {
            context.delete(item)
        }
        try context.save()
        
        // Then: The other items should remain
        let remainingDescriptor = FetchDescriptor<InventoryItem>()
        let remainingItems = try context.fetch(remainingDescriptor)
        
        #expect(remainingItems.count == 2)
        #expect(remainingItems.contains { $0.title == "Test Item 1" })
        #expect(remainingItems.contains { $0.title == "Test Item 3" })
        #expect(!remainingItems.contains { $0.title == "Test Item 2" })
    }
    
    @Test("Delete function handles empty selection gracefully")
    func testDeleteFunctionWithEmptySelection() async throws {
        // Given: A model container with test items
        let container = try createTestContainer()
        let context = container.mainContext
        _ = try createTestItems(in: context)
        
        // And: No items are selected
        let selectedItemIDs: Set<PersistentIdentifier> = Set()
        
        let allItemsDescriptor = FetchDescriptor<InventoryItem>()
        let allItems = try context.fetch(allItemsDescriptor)
        let selectedItems = allItems.filter { selectedItemIDs.contains($0.persistentModelID) }
        
        // When: We attempt to delete (should be no-op)
        for item in selectedItems {
            context.delete(item)
        }
        try context.save()
        
        // Then: All items should remain
        let remainingDescriptor = FetchDescriptor<InventoryItem>()
        let remainingItems = try context.fetch(remainingDescriptor)
        
        #expect(remainingItems.count == 3)
    }
}