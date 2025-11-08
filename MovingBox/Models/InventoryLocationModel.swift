//
//  LocationModel.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class InventoryLocation: PhotoManageable {
    var name: String = ""
    var desc: String = ""
    var sfSymbolName: String? = nil  // Optional SF Symbol for default room icons
    var imageURL: URL?
    var secondaryPhotoURLs: [String] = []
    var inventoryItems: [InventoryItem]? = [InventoryItem]()

    // Parent relationship for nested locations
    var parent: InventoryLocation?

    // ADD: Legacy Support
    @Attribute(.externalStorage) var data: Data?
    
    /// Migrates legacy image data to the new URL-based storage system
    func migrateImageIfNeeded() async throws {
        guard let legacyData = data,
              let image = UIImage(data: legacyData),
              imageURL == nil else {
            return
        }
        
        // Generate a unique identifier for the image
        let imageId = UUID().uuidString
        
        // Save the image using OptimizedImageManager
        imageURL = try await OptimizedImageManager.shared.saveImage(image, id: imageId)
        
        // Clear legacy data after successful migration
        data = nil
        
        print("📸 Location - Successfully migrated image for location: \(name)")
    }
    
    init(name: String = "", desc: String = "", parent: InventoryLocation? = nil) {
        self.name = name
        self.desc = desc
        self.parent = parent

        // Attempt migration on init
        Task {
            try? await migrateImageIfNeeded()
        }
    }
    
    // Computed property for AsyncImage thumbnail loading
    var thumbnailURL: URL? {
        guard let imageURL = imageURL else { return nil }
        let id = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")
        return OptimizedImageManager.shared.getThumbnailURL(for: id)
    }

    // MARK: - Nested Location Helpers

    /// Get all direct children of this location
    func getChildren(in context: ModelContext) -> [InventoryLocation] {
        let descriptor = FetchDescriptor<InventoryLocation>(
            predicate: #Predicate { location in
                location.parent?.persistentModelID == self.persistentModelID
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get the depth of this location in the hierarchy (0 for root locations)
    func getDepth() -> Int {
        var count = 0
        var current = parent
        while current != nil && count < 10 {
            count += 1
            current = current?.parent
        }
        return count
    }

    /// Check if this location can have children added (depth < 10)
    func canAddChild() -> Bool {
        return getDepth() < 10
    }

    /// Get the full path of this location (e.g., "House > Bedroom > Closet")
    func getFullPath() -> String {
        var path: [String] = [name]
        var current = parent
        while current != nil {
            path.insert(current!.name, at: 0)
            current = current?.parent
        }
        return path.joined(separator: " > ")
    }

    /// Get all ancestor locations from root to parent
    func getAncestors() -> [InventoryLocation] {
        var ancestors: [InventoryLocation] = []
        var current = parent
        while current != nil {
            ancestors.insert(current!, at: 0)
            current = current?.parent
        }
        return ancestors
    }

    /// Check if this location is a descendant of another location
    func isDescendant(of location: InventoryLocation) -> Bool {
        var current = parent
        while current != nil {
            if current?.persistentModelID == location.persistentModelID {
                return true
            }
            current = current?.parent
        }
        return false
    }
}
