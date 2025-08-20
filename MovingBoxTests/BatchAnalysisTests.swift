//
//  BatchAnalysisTests.swift
//  MovingBoxTests
//
//  Created by Claude on 8/20/25.
//

import Testing
import SwiftData
import UIKit
@testable import MovingBox

struct BatchAnalysisTests {
    
    // MARK: - Test Data Setup
    
    @MainActor
    static func createTestContainer() -> ModelContainer {
        let schema = Schema([
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            Home.self,
            InsurancePolicy.self
        ])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        return container
    }
    
    @MainActor
    static func createItemWithPrimaryImage() -> InventoryItem {
        let item = InventoryItem()
        item.title = "Item with Primary Image"
        item.imageURL = URL(string: "file:///test/primary.jpg")
        return item
    }
    
    @MainActor
    static func createItemWithSecondaryImages() -> InventoryItem {
        let item = InventoryItem()
        item.title = "Item with Secondary Images"
        item.secondaryPhotoURLs = ["file:///test/secondary1.jpg", "file:///test/secondary2.jpg"]
        return item
    }
    
    @MainActor
    static func createItemWithBothImages() -> InventoryItem {
        let item = InventoryItem()
        item.title = "Item with Both Images"
        item.imageURL = URL(string: "file:///test/primary.jpg")
        item.secondaryPhotoURLs = ["file:///test/secondary1.jpg"]
        return item
    }
    
    @MainActor
    static func createItemWithLegacyData() -> InventoryItem {
        let item = InventoryItem()
        item.title = "Item with Legacy Data"
        // Simulate legacy data without modern imageURL
        let testImage = UIImage(systemName: "photo")!
        item.data = testImage.jpegData(compressionQuality: 0.8)
        return item
    }
    
    @MainActor
    static func createItemWithNoImages() -> InventoryItem {
        let item = InventoryItem()
        item.title = "Item with No Images"
        return item
    }
    
    // MARK: - Test Helper Functions
    
    @MainActor
    func hasAnalyzableImage(_ item: InventoryItem) -> Bool {
        // Check primary image URL
        if let imageURL = item.imageURL, !imageURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        
        // Check secondary photo URLs (filter out empty strings)
        if !item.secondaryPhotoURLs.isEmpty {
            let validURLs = item.secondaryPhotoURLs.filter { url in
                !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !validURLs.isEmpty {
                return true
            }
        }
        
        // Check legacy data property (for items that haven't migrated yet)
        if let data = item.data, !data.isEmpty {
            return true
        }
        
        return false
    }
    
    @MainActor
    func hasImagesInSelection(selectedItemIDs: Set<PersistentIdentifier>, allItems: [InventoryItem]) -> Bool {
        guard !selectedItemIDs.isEmpty else { return false }
        return allItems.contains { item in
            guard selectedItemIDs.contains(item.persistentModelID) else { return false }
            return hasAnalyzableImage(item)
        }
    }
    
    // MARK: - Image Detection Logic Tests
    
    @Test("hasImagesInSelection should detect primary image")
    @MainActor
    func testHasImagesInSelectionWithPrimaryImage() throws {
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = Self.createItemWithPrimaryImage()
        context.insert(item)
        
        let selectedItemIDs: Set<PersistentIdentifier> = [item.persistentModelID]
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
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = Self.createItemWithSecondaryImages()
        context.insert(item)
        
        let selectedItemIDs: Set<PersistentIdentifier> = [item.persistentModelID]
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
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = Self.createItemWithBothImages()
        context.insert(item)
        
        let selectedItemIDs: Set<PersistentIdentifier> = [item.persistentModelID]
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
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = Self.createItemWithNoImages()
        context.insert(item)
        
        let selectedItemIDs: Set<PersistentIdentifier> = [item.persistentModelID]
        let allItems = [item]
        
        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )
        
        #expect(hasImages == false)
    }
    
    @Test("hasImagesInSelection should handle legacy data")
    @MainActor
    func testHasImagesInSelectionWithLegacyData() throws {
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = Self.createItemWithLegacyData()
        context.insert(item)
        
        let selectedItemIDs: Set<PersistentIdentifier> = [item.persistentModelID]
        let allItems = [item]
        
        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )
        
        // Should detect legacy data as having images
        #expect(hasImages == true)
    }
    
    @Test("hasImagesInSelection should handle mixed selection")
    @MainActor
    func testHasImagesInSelectionMixed() throws {
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let itemWithImages = Self.createItemWithPrimaryImage()
        let itemWithoutImages = Self.createItemWithNoImages()
        context.insert(itemWithImages)
        context.insert(itemWithoutImages)
        
        let selectedItemIDs: Set<PersistentIdentifier> = [
            itemWithImages.persistentModelID,
            itemWithoutImages.persistentModelID
        ]
        let allItems = [itemWithImages, itemWithoutImages]
        
        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )
        
        // Should return true if any selected item has images
        #expect(hasImages == true)
    }
    
    @Test("hasImagesInSelection should return false for empty selection")
    @MainActor
    func testHasImagesInSelectionEmptySelection() throws {
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = Self.createItemWithPrimaryImage()
        context.insert(item)
        
        let selectedItemIDs: Set<PersistentIdentifier> = []
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
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let itemWithPrimary = Self.createItemWithPrimaryImage()
        let itemWithSecondary = Self.createItemWithSecondaryImages()
        let itemWithNoImages = Self.createItemWithNoImages()
        
        let allItems = [itemWithPrimary, itemWithSecondary, itemWithNoImages]
        allItems.forEach { context.insert($0) }
        
        let itemsWithImages = allItems.filter { hasAnalyzableImage($0) }
        
        #expect(itemsWithImages.count == 2)
        #expect(itemsWithImages.contains(itemWithPrimary))
        #expect(itemsWithImages.contains(itemWithSecondary))
        #expect(!itemsWithImages.contains(itemWithNoImages))
    }
    
    // MARK: - New Async Method Tests
    
    @Test("hasAnalyzableImageAfterMigration should detect primary image")
    @MainActor
    func testHasAnalyzableImageAfterMigrationWithPrimaryImage() async throws {
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = Self.createItemWithPrimaryImage()
        context.insert(item)
        
        let hasImages = await item.hasAnalyzableImageAfterMigration()
        
        #expect(hasImages == true)
    }
    
    @Test("hasAnalyzableImageAfterMigration should detect secondary images")
    @MainActor
    func testHasAnalyzableImageAfterMigrationWithSecondaryImages() async throws {
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = Self.createItemWithSecondaryImages()
        context.insert(item)
        
        let hasImages = await item.hasAnalyzableImageAfterMigration()
        
        #expect(hasImages == true)
    }
    
    @Test("hasAnalyzableImageAfterMigration should handle legacy data")
    @MainActor
    func testHasAnalyzableImageAfterMigrationWithLegacyData() async throws {
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = Self.createItemWithLegacyData()
        context.insert(item)
        
        let hasImages = await item.hasAnalyzableImageAfterMigration()
        
        // Should detect legacy data as having images (migration will fail in test but data should still be detected)
        #expect(hasImages == true)
    }
    
    @Test("hasAnalyzableImageAfterMigration should return false for no images")
    @MainActor
    func testHasAnalyzableImageAfterMigrationWithNoImages() async throws {
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = Self.createItemWithNoImages()
        context.insert(item)
        
        let hasImages = await item.hasAnalyzableImageAfterMigration()
        
        #expect(hasImages == false)
    }
    
    // MARK: - Edge Cases and Error Conditions
    
    @Test("should handle empty imageURL")
    @MainActor
    func testEmptyImageURL() throws {
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = InventoryItem()
        item.title = "Item with empty URL"
        item.imageURL = URL(string: "")  // Empty URL string
        context.insert(item)
        
        let selectedItemIDs: Set<PersistentIdentifier> = [item.persistentModelID]
        let allItems = [item]
        
        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )
        
        // Should handle gracefully - empty URL means no image
        #expect(hasImages == false)
    }
    
    @Test("should handle empty secondaryPhotoURLs array")
    @MainActor
    func testEmptySecondaryPhotoURLs() throws {
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = InventoryItem()
        item.title = "Item with empty secondary array"
        item.secondaryPhotoURLs = []  // Explicitly empty
        context.insert(item)
        
        let selectedItemIDs: Set<PersistentIdentifier> = [item.persistentModelID]
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
        let container = Self.createTestContainer()
        let context = container.mainContext
        
        let item = InventoryItem()
        item.title = "Item with empty string URLs"
        item.secondaryPhotoURLs = ["", "  ", ""]  // Empty and whitespace strings
        context.insert(item)
        
        let selectedItemIDs: Set<PersistentIdentifier> = [item.persistentModelID]
        let allItems = [item]
        
        let hasImages = hasImagesInSelection(
            selectedItemIDs: selectedItemIDs,
            allItems: allItems
        )
        
        // Should be smart about empty string URLs
        #expect(hasImages == false)
    }
}

