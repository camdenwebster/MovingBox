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
    var imageURLs: [URL] = []
    var primaryImageIndex: Int = 0
    var inventoryItems: [InventoryItem]? = [InventoryItem]()
    
    @Attribute(.externalStorage) var data: Data?
    
    /// Migrates legacy image data to the new URL-based storage system
    func migrateImageIfNeeded() async throws {
        guard let legacyData = data,
              let image = UIImage(data: legacyData),
              imageURLs.isEmpty else {
            return
        }
        
        let imageId = UUID().uuidString
        
        if let newImageURL = try await OptimizedImageManager.shared.saveImage(image, id: imageId) {
            imageURLs.append(newImageURL)
        }
        
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
}
