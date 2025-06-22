import Testing
import SwiftUI
@testable import MovingBox

@MainActor
@Suite struct PhotoManageableTests {
    
    @Test("InventoryItem implements all PhotoManageable methods")
    func testInventoryItemPhotoManageable() async throws {
        let item = InventoryItem()
        
        // Test primary photo loading (no photos initially)
        let primaryPhoto = try await item.photo
        #expect(primaryPhoto == nil)
        
        // Test secondary photos loading (empty initially)
        let secondaryPhotos = try await item.secondaryPhotos
        #expect(secondaryPhotos.isEmpty)
        
        // Test secondary thumbnails loading
        let secondaryThumbnails = await item.secondaryThumbnails
        #expect(secondaryThumbnails.isEmpty)
        
        // Test all photos loading
        let allPhotos = try await item.allPhotos
        #expect(allPhotos.isEmpty)
        
        // Add some secondary photo URLs (mock URLs for testing)
        item.addSecondaryPhotoURL("mock_url_1")
        item.addSecondaryPhotoURL("mock_url_2")
        
        // Verify the URLs were added
        #expect(item.secondaryPhotoURLs.count == 2)
        #expect(item.hasSecondaryPhotos() == true)
    }
    
    @Test("InventoryLocation implements PhotoManageable")
    func testInventoryLocationPhotoManageable() async throws {
        let location = InventoryLocation(name: "Test Location")
        
        // Test secondary photos property exists and is empty
        #expect(location.secondaryPhotoURLs.isEmpty)
        
        // Test we can access PhotoManageable methods
        let secondaryPhotos = try await location.secondaryPhotos
        #expect(secondaryPhotos.isEmpty)
        
        let secondaryThumbnails = await location.secondaryThumbnails
        #expect(secondaryThumbnails.isEmpty)
        
        let allPhotos = try await location.allPhotos
        #expect(allPhotos.isEmpty)
    }
    
    @Test("Home implements PhotoManageable")
    func testHomePhotoManageable() async throws {
        let home = Home(name: "Test Home")
        
        // Test secondary photos property exists and is empty
        #expect(home.secondaryPhotoURLs.isEmpty)
        
        // Test we can access PhotoManageable methods
        let secondaryPhotos = try await home.secondaryPhotos
        #expect(secondaryPhotos.isEmpty)
        
        let secondaryThumbnails = await home.secondaryThumbnails
        #expect(secondaryThumbnails.isEmpty)
        
        let allPhotos = try await home.allPhotos
        #expect(allPhotos.isEmpty)
    }
    
    @Test("PhotoManageable allPhotos combines primary and secondary")
    func testAllPhotosCombination() async throws {
        let item = InventoryItem()
        
        // Initially no photos
        let emptyPhotos = try await item.allPhotos
        #expect(emptyPhotos.isEmpty)
        
        // Add primary photo URL (mock)
        item.imageURL = URL(string: "primary.jpg")
        
        // Add secondary photo URLs (mock)
        item.addSecondaryPhotoURL("secondary1.jpg")
        item.addSecondaryPhotoURL("secondary2.jpg")
        
        // Verify the setup
        #expect(item.imageURL != nil)
        #expect(item.secondaryPhotoURLs.count == 2)
        #expect(item.getTotalPhotoCount() == 3) // 1 primary + 2 secondary
        
        // Note: We can't test actual image loading without real image files,
        // but we can verify the structure is correct
    }
    
    @Test("PhotoManageable secondary methods handle empty arrays")
    func testEmptySecondaryPhotos() async throws {
        let item = InventoryItem()
        
        // Ensure empty secondary photos are handled correctly
        #expect(item.secondaryPhotoURLs.isEmpty)
        
        let secondaryPhotos = try await item.secondaryPhotos
        #expect(secondaryPhotos.isEmpty)
        
        let secondaryThumbnails = await item.secondaryThumbnails
        #expect(secondaryThumbnails.isEmpty)
    }
}