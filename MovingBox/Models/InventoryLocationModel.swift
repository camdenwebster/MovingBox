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
class InventoryLocation: PhotoManageable, Syncable {
    var id: UUID = UUID()
    var name: String = ""
    var desc: String = ""
    var imageURL: URL?
    var inventoryItems: [InventoryItem]? = [InventoryItem]()
    
    // MARK: - Sync Properties
    var remoteId: String?
    var lastModified: Date = Date()
    var lastSynced: Date?
    var needsSync: Bool = false
    var isDeleted: Bool = false
    var syncServiceType: SyncServiceType?
    var version: Int = 1
    
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
        
        // Mark new locations for sync
        self.needsSync = true
        self.lastModified = Date()
        
        // Attempt migration on init
        Task {
            try? await migrateImageIfNeeded()
        }
    }
    
    /// Mark the location as requiring sync due to local changes
    func markForSync() {
        self.needsSync = true
        self.lastModified = Date()
        self.version += 1
    }
}
