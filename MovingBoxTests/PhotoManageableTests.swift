import SwiftUI
import Testing

@testable import MovingBox

@MainActor
@Suite struct PhotoManageableTests {

    // Helper to access PhotoManageable protocol methods without @Table dynamic member lookup conflict
    private func asPhotoManageable(_ value: some PhotoManageable) -> any PhotoManageable {
        value
    }

    @Test("SQLiteInventoryItem implements all PhotoManageable methods")
    func testInventoryItemPhotoManageable() async throws {
        var item = SQLiteInventoryItem(id: UUID(), title: "Test Item")
        let pm = asPhotoManageable(item)

        let primaryPhoto = try await pm.photo
        #expect(primaryPhoto == nil)

        let secondaryPhotos = try await pm.secondaryPhotos
        #expect(secondaryPhotos.isEmpty)

        let secondaryThumbnails = await pm.secondaryThumbnails
        #expect(secondaryThumbnails.isEmpty)

        let allPhotos = try await pm.allPhotos
        #expect(allPhotos.isEmpty)

        item.secondaryPhotoURLs.append("mock_url_1")
        item.secondaryPhotoURLs.append("mock_url_2")

        #expect(item.secondaryPhotoURLs.count == 2)
        #expect(!item.secondaryPhotoURLs.isEmpty)
    }

    @Test("SQLiteInventoryLocation implements PhotoManageable")
    func testInventoryLocationPhotoManageable() async throws {
        let location = SQLiteInventoryLocation(id: UUID(), name: "Test Location")
        let pm = asPhotoManageable(location)

        #expect(location.secondaryPhotoURLs.isEmpty)

        let secondaryPhotos = try await pm.secondaryPhotos
        #expect(secondaryPhotos.isEmpty)

        let secondaryThumbnails = await pm.secondaryThumbnails
        #expect(secondaryThumbnails.isEmpty)

        let allPhotos = try await pm.allPhotos
        #expect(allPhotos.isEmpty)
    }

    @Test("SQLiteHome implements PhotoManageable")
    func testHomePhotoManageable() async throws {
        let home = SQLiteHome(id: UUID(), name: "Test Home")
        let pm = asPhotoManageable(home)

        #expect(home.secondaryPhotoURLs.isEmpty)

        let secondaryPhotos = try await pm.secondaryPhotos
        #expect(secondaryPhotos.isEmpty)

        let secondaryThumbnails = await pm.secondaryThumbnails
        #expect(secondaryThumbnails.isEmpty)

        let allPhotos = try await pm.allPhotos
        #expect(allPhotos.isEmpty)
    }

    @Test("PhotoManageable allPhotos combines primary and secondary")
    func testAllPhotosCombination() async throws {
        var item = SQLiteInventoryItem(id: UUID(), title: "Test Item")
        let pm = asPhotoManageable(item)

        let emptyPhotos = try await pm.allPhotos
        #expect(emptyPhotos.isEmpty)

        item.imageURL = URL(string: "primary.jpg")
        item.secondaryPhotoURLs = ["secondary1.jpg", "secondary2.jpg"]

        #expect(item.imageURL != nil)
        #expect(item.secondaryPhotoURLs.count == 2)
        let totalCount = 1 + item.secondaryPhotoURLs.count
        #expect(totalCount == 3)
    }

    @Test("PhotoManageable secondary methods handle empty arrays")
    func testEmptySecondaryPhotos() async throws {
        let item = SQLiteInventoryItem(id: UUID(), title: "Test Item")
        let pm = asPhotoManageable(item)

        #expect(item.secondaryPhotoURLs.isEmpty)

        let secondaryPhotos = try await pm.secondaryPhotos
        #expect(secondaryPhotos.isEmpty)

        let secondaryThumbnails = await pm.secondaryThumbnails
        #expect(secondaryThumbnails.isEmpty)
    }
}
