import Testing
@testable import MovingBox
import SwiftData
import UIKit

@MainActor
@Suite struct HomeMigrationTests {
    
    func createTestContainer() throws -> (ModelContainer, ModelContext) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Home.self, configurations: configuration)
        return (container, container.mainContext)
    }
    
    @Test("Home with legacy data successfully migrates to URL-based storage")
    func testSuccessfulMigration() async throws {
        // Given
        let (_, context) = try createTestContainer()
        let home = Home(name: "Test Home")
        let testImage = UIImage(systemName: "house.fill")!
        home.legacyImageData = testImage.pngData()
        context.insert(home)
        
        // When
        try await home.migrateImageIfNeeded()
        
        // Then
        #expect(home.legacyImageData == nil, "Legacy data should be cleared after migration")
        #expect(home.imageURL != nil, "Image URL should be set after migration")
        
        // Verify the image was properly saved
        let savedImage = try await OptimizedImageManager.shared.loadImage(url: home.imageURL!)
        let savedImageData = savedImage.pngData()
        let originalImageData = testImage.pngData()
        #expect(savedImageData == originalImageData, "Saved image should match original")
        
        // Cleanup
        try? FileManager.default.removeItem(at: OptimizedImageManager.shared.imagesDirectoryURL)
    }
    
    @Test("Home without legacy data skips migration")
    func testSkipMigrationWhenNoLegacyData() async throws {
        // Given
        let (_, context) = try createTestContainer()
        let home = Home(name: "Test Home")
        context.insert(home)
        
        // When
        try await home.migrateImageIfNeeded()
        
        // Then
        #expect(home.imageURL == nil, "Image URL should remain nil when no legacy data exists")
        
        // Cleanup
        try? FileManager.default.removeItem(at: OptimizedImageManager.shared.imagesDirectoryURL)
    }
    
    @Test("Home with existing URL skips migration")
    func testSkipMigrationWhenURLExists() async throws {
        // Given
        let (_, context) = try createTestContainer()
        let home = Home(name: "Test Home")
        let testImage = UIImage(systemName: "house.fill")!
        
        // Save the image first to get a valid URL
        let imageId = UUID().uuidString
        let imageURL = try await OptimizedImageManager.shared.saveImage(testImage, id: imageId)
        
        home.legacyImageData = testImage.pngData()
        home.imageURL = imageURL
        context.insert(home)
        
        // When
        try await home.migrateImageIfNeeded()
        
        // Then
        #expect(home.legacyImageData != nil, "Legacy data should not be cleared if URL already exists")
        #expect(home.imageURL == imageURL, "Existing URL should not be changed")
        
        // Cleanup
        try? FileManager.default.removeItem(at: OptimizedImageManager.shared.imagesDirectoryURL)
    }
    
    @Test("ModelContainerManager successfully migrates all homes")
    func testBulkMigration() async throws {
        // Given
        let (container, context) = try createTestContainer()
        let manager = ModelContainerManager(testContainer: container)
        
        let homes = [
            createTestHome(name: "Home 1", hasImage: true),
            createTestHome(name: "Home 2", hasImage: true),
            createTestHome(name: "Home 3", hasImage: false)
        ]
        homes.forEach { context.insert($0) }
        
        // When
        try await manager.migrateHomes()
        
        // Then
        let migratedHomes = try context.fetch(FetchDescriptor<Home>())
        for home in migratedHomes where home.legacyImageData != nil {
            #expect(home.imageURL != nil, "Homes with legacy data should have URLs after migration")
            #expect(OptimizedImageManager.shared.imageExists(for: home.imageURL), "Image file should exist at URL")
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: OptimizedImageManager.shared.imagesDirectoryURL)
    }
    
    // MARK: - Helper Methods
    
    private func createTestHome(name: String, hasImage: Bool) -> Home {
        let home = Home(name: name)
        if hasImage {
            home.legacyImageData = UIImage(systemName: "house.fill")!.pngData()
        }
        return home
    }
}
