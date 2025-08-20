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
    var imageURL: URL?
    var secondaryPhotoURLs: [String] = []
    var inventoryItems: [InventoryItem]? = [InventoryItem]()
    
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
    
    init(name: String = "", desc: String = "") {
        self.name = name
        self.desc = desc
        
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
}
