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
final class InventoryItem: ObservableObject, PhotoManageable {
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
    var secondaryPhotoURLs: [String] = []
    var showInvalidQuantityAlert: Bool = false
    var hasUsedAI: Bool = false
    
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
    
    func migrateSecondaryPhotosIfNeeded() {
        // Ensure secondaryPhotoURLs is initialized as empty array for existing items
        // SwiftData should handle this automatically, but this provides explicit migration
        if secondaryPhotoURLs.isEmpty {
            print("📸 InventoryItem - Secondary photos array initialized for item: \(title)")
        }
    }
    
    init() {
        migrateSecondaryPhotosIfNeeded()
        Task {
            try? await migrateImageIfNeeded()
        }
    }
    
    init(title: String, quantityString: String, quantityInt: Int, desc: String, serial: String, model: String, make: String, location: InventoryLocation?, label: InventoryLabel?, price: Decimal, insured: Bool, assetId: String, notes: String, showInvalidQuantityAlert: Bool, hasUsedAI: Bool = false, secondaryPhotoURLs: [String] = []) {
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
        self.secondaryPhotoURLs = secondaryPhotoURLs
        
        migrateSecondaryPhotosIfNeeded()
        Task {
            try? await migrateImageIfNeeded()
        }
    }
    
    var isInteger: Bool {
        return Int(quantityString) != nil
    }
    
    // MARK: - Secondary Photo Management
    
    func addSecondaryPhotoURL(_ urlString: String) {
        guard !urlString.isEmpty else { return }
        guard !secondaryPhotoURLs.contains(urlString) else { return }
        guard secondaryPhotoURLs.count < 4 else { return } // Max 4 secondary (5 total with primary)
        
        secondaryPhotoURLs.append(urlString)
        print("📸 InventoryItem - Added secondary photo URL for item: \(title)")
    }
    
    func removeSecondaryPhotoURL(_ urlString: String) {
        guard let index = secondaryPhotoURLs.firstIndex(of: urlString) else { return }
        
        secondaryPhotoURLs.remove(at: index)
        print("📸 InventoryItem - Removed secondary photo URL for item: \(title)")
        
        // Clean up the actual image file
        Task {
            do {
                try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: urlString)
            } catch {
                print("📸 InventoryItem - Failed to delete secondary image file: \(error)")
            }
        }
    }
    
    func removeSecondaryPhotoAt(index: Int) {
        guard index >= 0 && index < secondaryPhotoURLs.count else { return }
        
        let urlString = secondaryPhotoURLs[index]
        removeSecondaryPhotoURL(urlString)
    }
    
    func getAllPhotoURLs() -> [String] {
        var allURLs: [String] = []
        
        // Add primary photo URL if it exists
        if let primaryURL = imageURL {
            allURLs.append(primaryURL.absoluteString)
        }
        
        // Add secondary photo URLs
        allURLs.append(contentsOf: secondaryPhotoURLs)
        
        return allURLs
    }
    
    func getSecondaryPhotoCount() -> Int {
        return secondaryPhotoURLs.count
    }
    
    func getTotalPhotoCount() -> Int {
        let primaryCount = imageURL != nil ? 1 : 0
        return primaryCount + secondaryPhotoURLs.count
    }
    
    func hasSecondaryPhotos() -> Bool {
        return !secondaryPhotoURLs.isEmpty
    }
    
    func canAddMorePhotos() -> Bool {
        return getTotalPhotoCount() < 5
    }
    
    func getRemainingPhotoSlots() -> Int {
        return max(0, 5 - getTotalPhotoCount())
    }
    
    func clearAllSecondaryPhotos() {
        let urlsToDelete = secondaryPhotoURLs
        secondaryPhotoURLs.removeAll()
        
        print("📸 InventoryItem - Cleared all secondary photos for item: \(title)")
        
        // Clean up the actual image files
        Task {
            for urlString in urlsToDelete {
                do {
                    try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: urlString)
                } catch {
                    print("📸 InventoryItem - Failed to delete secondary image file: \(error)")
                }
            }
        }
    }
    
    func validateQuantityInput() {
        if !isInteger {
            showInvalidQuantityAlert = true
        } else {
            self.quantityInt = Int(quantityString) ?? 1
            showInvalidQuantityAlert = false
        }
    }
}
