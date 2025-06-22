//
//  InventoryItemModel.swift
//  MovingBox
//
//  Created by Camden Webster on 4/9/24.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class InventoryItem: ObservableObject, PhotoManageable, Syncable {
    var id: UUID = UUID()
    var title: String = ""
    var quantityString: String = "1"
    var quantityInt: Int = 1
    var desc: String = ""
    var serial: String = ""
    var model: String = ""
    var make: String = ""
    var location: InventoryLocation?
    var label: InventoryLabel?
    var price: Decimal = Decimal.zero
    var insured: Bool = false
    var assetId: String = ""
    var notes: String = ""
    var imageURL: URL?
    var showInvalidQuantityAlert: Bool = false
    var hasUsedAI: Bool = false
    
    // MARK: - Sync Properties
    var remoteId: String?
    var lastModified: Date = Date()
    var lastSynced: Date?
    var needsSync: Bool = false
    var isDeleted: Bool = false
    var syncServiceType: SyncServiceType?
    var version: Int = 1
    
    @Attribute(.externalStorage) var data: Data?
    
    func migrateImageIfNeeded() async throws {
        guard let legacyData = data,
              let image = UIImage(data: legacyData),
              imageURL == nil else {
            return
        }
        
        let imageId = UUID().uuidString
        
        imageURL = try await OptimizedImageManager.shared.saveImage(image, id: imageId)
        
        data = nil
        
        print("📸 InventoryItem - Successfully migrated image for item: \(title)")
    }
    
    init() {
        self.needsSync = true
        self.lastModified = Date()
        
        Task {
            try? await migrateImageIfNeeded()
        }
    }
    
    init(title: String, quantityString: String, quantityInt: Int, desc: String, serial: String, model: String, make: String, location: InventoryLocation?, label: InventoryLabel?, price: Decimal, insured: Bool, assetId: String, notes: String, showInvalidQuantityAlert: Bool, hasUsedAI: Bool = false) {
        self.title = title
        self.quantityString = quantityString
        self.quantityInt = quantityInt
        self.desc = desc
        self.serial = serial
        self.model = model
        self.make = make
        self.location = location
        self.label = label
        self.price = price
        self.insured = insured
        self.assetId = assetId
        self.notes = notes
        self.showInvalidQuantityAlert = showInvalidQuantityAlert
        self.hasUsedAI = hasUsedAI
        
        // Mark new items for sync
        self.needsSync = true
        self.lastModified = Date()
        
        Task {
            try? await migrateImageIfNeeded()
        }
    }
    
    var isInteger: Bool {
        return Int(quantityString) != nil
    }
    
    func validateQuantityInput() {
        if !isInteger {
            showInvalidQuantityAlert = true
        } else {
            self.quantityInt = Int(quantityString) ?? 1
            showInvalidQuantityAlert = false
            markForSync()
        }
    }
    
    /// Mark the inventory item as requiring sync due to local changes
    func markForSync() {
        self.needsSync = true
        self.lastModified = Date()
        self.version += 1
    }
}
