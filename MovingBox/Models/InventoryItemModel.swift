//
//  InventoryItemModel.swift
//  MovingBox
//
//  Created by Camden Webster on 4/9/24.
//

import Foundation
import SwiftData
import SwiftUI

struct AttachmentInfo: Codable, Hashable {
    let url: String
    let originalName: String
    let createdAt: Date
    
    init(url: String, originalName: String) {
        self.url = url
        self.originalName = originalName
        self.createdAt = Date()
    }
}

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
    var createdAt: Date = Date()
    
    // MARK: - Purchase & Ownership Tracking
    var purchaseDate: Date?
    var warrantyExpirationDate: Date?
    var purchaseLocation: String = ""
    var condition: String = ""
    var hasWarranty: Bool = false
    
    // MARK: - Financial & Legal
    var depreciationRate: Double?
    var replacementCost: Decimal?
    var attachments: [AttachmentInfo] = []
    
    // MARK: - Storage & Physical Properties
    var dimensions: String = ""
    var dimensionLength: String = ""
    var dimensionWidth: String = ""
    var dimensionHeight: String = ""
    var dimensionUnit: String = "inches"
    var weight: String = ""
    var weightValue: String = ""
    var weightUnit: String = "lbs"
    var color: String = ""
    var storageRequirements: String = ""
    
    // MARK: - Moving & Insurance Optimization
    var isFragile: Bool = false
    var movingPriority: Int = 3
    var roomDestination: String = ""
    
    @Attribute(.externalStorage) var data: Data?
    
    private var isMigrating = false
    
    // Helper function to detect test environment
    private func isRunningTests() -> Bool {
        return NSClassFromString("XCTestCase") != nil ||
               ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
               ProcessInfo.processInfo.arguments.contains { $0.contains("xctest") }
    }
    
    func migrateImageIfNeeded() async throws {
        // Skip migration in test environment or if context is destroyed
        guard !isRunningTests() else {
            return
        }
        
        guard let legacyData = data,
              let image = UIImage(data: legacyData),
              imageURL == nil,
              !isMigrating else {
            return
        }
        
        isMigrating = true
        defer { isMigrating = false }
        
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
    
    func hasAnalyzableImageAfterMigration() async -> Bool {
        // Skip migration in test environment
        if !isRunningTests() {
            // First ensure migration is complete
            if data != nil && imageURL == nil {
                do {
                    try await migrateImageIfNeeded()
                } catch {
                    print("📸 InventoryItem - Failed to migrate image for item: \(title), error: \(error)")
                    // Continue to check other image sources
                }
            }
        }
        
        // Check primary image URL
        if let imageURL = imageURL, !imageURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        
        // Check secondary photo URLs (filter out empty strings)
        if !secondaryPhotoURLs.isEmpty {
            let validURLs = secondaryPhotoURLs.filter { url in
                !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if !validURLs.isEmpty {
                return true
            }
        }
        
        // Check legacy data property (for items that migration failed on)
        if let data = data, !data.isEmpty {
            return true
        }
        
        return false
    }
    
    init() {
        self.createdAt = Date()
        migrateSecondaryPhotosIfNeeded()
        
        // Only migrate in non-test environment to avoid accessing destroyed contexts
        if !isRunningTests() {
            Task {
                try? await migrateImageIfNeeded()
            }
        }
    }
    
    init(title: String, quantityString: String, quantityInt: Int, desc: String, serial: String, model: String, make: String, location: InventoryLocation?, label: InventoryLabel?, price: Decimal, insured: Bool, assetId: String, notes: String, showInvalidQuantityAlert: Bool, hasUsedAI: Bool = false, secondaryPhotoURLs: [String] = [], purchaseDate: Date? = nil, warrantyExpirationDate: Date? = nil, purchaseLocation: String = "", condition: String = "", hasWarranty: Bool = false, depreciationRate: Double? = nil, replacementCost: Decimal? = nil, dimensions: String = "", dimensionLength: String = "", dimensionWidth: String = "", dimensionHeight: String = "", dimensionUnit: String = "inches", weight: String = "", weightValue: String = "", weightUnit: String = "lbs", color: String = "", storageRequirements: String = "", isFragile: Bool = false, movingPriority: Int = 3, roomDestination: String = "") {
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
        self.createdAt = Date()
        
        // Initialize new properties
        self.purchaseDate = purchaseDate
        self.warrantyExpirationDate = warrantyExpirationDate
        self.purchaseLocation = purchaseLocation
        self.condition = condition
        self.hasWarranty = hasWarranty
        self.depreciationRate = depreciationRate
        self.replacementCost = replacementCost
        self.dimensions = dimensions
        self.dimensionLength = dimensionLength
        self.dimensionWidth = dimensionWidth
        self.dimensionHeight = dimensionHeight
        self.dimensionUnit = dimensionUnit
        self.weight = weight
        self.weightValue = weightValue
        self.weightUnit = weightUnit
        self.color = color
        self.storageRequirements = storageRequirements
        self.isFragile = isFragile
        self.movingPriority = movingPriority
        self.roomDestination = roomDestination
        
        migrateSecondaryPhotosIfNeeded()
        
        // Only migrate in non-test environment to avoid accessing destroyed contexts
        if !isRunningTests() {
            Task {
                try? await migrateImageIfNeeded()
            }
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
        
        // Clean up the actual image file (skip in test environment)
        if !isRunningTests() {
            Task {
                do {
                    try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: urlString)
                } catch {
                    print("📸 InventoryItem - Failed to delete secondary image file: \(error)")
                }
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
        
        // Clean up the actual image files (skip in test environment)
        if !isRunningTests() {
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
    }
    
    func validateQuantityInput() {
        if !isInteger {
            showInvalidQuantityAlert = true
        } else {
            self.quantityInt = Int(quantityString) ?? 1
            showInvalidQuantityAlert = false
        }
    }
    
    // Computed property for AsyncImage thumbnail loading
    var thumbnailURL: URL? {
        guard let imageURL = imageURL else { return nil }
        let id = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")
        return OptimizedImageManager.shared.getThumbnailURL(for: id)
    }
    
    // MARK: - Attachment Management
    
    func addAttachment(url: String, originalName: String) {
        let attachment = AttachmentInfo(url: url, originalName: originalName)
        attachments.append(attachment)
    }
    
    func removeAttachment(url: String) {
        attachments.removeAll { $0.url == url }
    }
    
    func hasAttachments() -> Bool {
        return !attachments.isEmpty
    }
    
    func getAllAttachments() -> [AttachmentInfo] {
        return attachments
    }
}
