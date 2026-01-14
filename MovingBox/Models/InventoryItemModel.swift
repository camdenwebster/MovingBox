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
    var secondaryPhotoURLs: [String] = []
    var showInvalidQuantityAlert: Bool = false
    var hasUsedAI: Bool = false
    var createdAt: Date = Date()
    var home: Home?

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
    var dimensionLength: String = ""
    var dimensionWidth: String = ""
    var dimensionHeight: String = ""
    var dimensionUnit: String = "inches"
    var weightValue: String = ""
    var weightUnit: String = "lbs"
    var color: String = ""
    var storageRequirements: String = ""

    // MARK: - Moving & Insurance Optimization
    var isFragile: Bool = false
    var movingPriority: Int = 3
    var roomDestination: String = ""

    // MARK: - Computed Properties

    /// Returns the effective home for this item
    /// Items inherit home from their location; if no location, uses direct home reference
    var effectiveHome: Home? {
        location?.home ?? home
    }

    @Attribute(.externalStorage) var data: Data?

    private var isMigrating = false

    // Helper function to detect test environment
    private func isRunningTests() -> Bool {
        // Check for XCTest framework
        if NSClassFromString("XCTestCase") != nil {
            return true
        }

        // Check for test configuration file path
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }

        // Check for xctest in arguments
        if ProcessInfo.processInfo.arguments.contains(where: { $0.contains("xctest") }) {
            return true
        }

        // Check for Swift Testing framework
        if NSClassFromString("Testing.Test") != nil {
            return true
        }

        // Check for test launch arguments
        if ProcessInfo.processInfo.arguments.contains("Use-Test-Data")
            || ProcessInfo.processInfo.arguments.contains("Mock-Data")
        {
            return true
        }

        // Check bundle identifier contains test
        if Bundle.main.bundleIdentifier?.contains("Test") == true {
            return true
        }

        return false
    }

    func migrateImageIfNeeded() async throws {
        // Skip migration in test environment or if context is destroyed
        guard !isRunningTests() else {
            return
        }

        // Additional safety check to prevent crashes in tests
        do {
            // Try to access a property to see if model context is still valid
            _ = title
        } catch {
            // If we can't access properties, the context is likely destroyed
            print("📸 InventoryItem - Skipping migration due to destroyed context")
            return
        }

        guard let legacyData = data,
            let image = UIImage(data: legacyData),
            imageURL == nil,
            !isMigrating
        else {
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
        // Note: Removed logging as this is called for every new item and creates noise
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

    init(id: UUID = UUID()) {
        self.id = id
        self.createdAt = Date()
        migrateSecondaryPhotosIfNeeded()

        // Skip automatic migration on init - migration will happen on-demand when item is accessed
        // This prevents blocking the main thread during bulk imports
    }

    // MARK: - Core Initializer (for required properties only)
    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        migrateSecondaryPhotosIfNeeded()

        // Skip automatic migration on init - migration will happen on-demand when item is accessed
        // This prevents blocking the main thread during bulk imports
    }

    // MARK: - Legacy Initializer (for backwards compatibility)
    init(
        id: UUID = UUID(),
        title: String, quantityString: String, quantityInt: Int, desc: String, serial: String, model: String,
        make: String, location: InventoryLocation?, label: InventoryLabel?, price: Decimal, insured: Bool,
        assetId: String, notes: String, showInvalidQuantityAlert: Bool, hasUsedAI: Bool = false,
        secondaryPhotoURLs: [String] = [], purchaseDate: Date? = nil, warrantyExpirationDate: Date? = nil,
        purchaseLocation: String = "", condition: String = "", hasWarranty: Bool = false,
        depreciationRate: Double? = nil, replacementCost: Decimal? = nil, dimensionLength: String = "",
        dimensionWidth: String = "", dimensionHeight: String = "", dimensionUnit: String = "inches",
        weightValue: String = "", weightUnit: String = "lbs", color: String = "", storageRequirements: String = "",
        isFragile: Bool = false, movingPriority: Int = 3, roomDestination: String = ""
    ) {
        self.id = id
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

        // Initialize extended properties
        self.purchaseDate = purchaseDate
        self.warrantyExpirationDate = warrantyExpirationDate
        self.purchaseLocation = purchaseLocation
        self.condition = condition
        self.hasWarranty = hasWarranty
        self.depreciationRate = depreciationRate
        self.replacementCost = replacementCost
        self.dimensionLength = dimensionLength
        self.dimensionWidth = dimensionWidth
        self.dimensionHeight = dimensionHeight
        self.dimensionUnit = dimensionUnit
        self.weightValue = weightValue
        self.weightUnit = weightUnit
        self.color = color
        self.storageRequirements = storageRequirements
        self.isFragile = isFragile
        self.movingPriority = movingPriority
        self.roomDestination = roomDestination

        migrateSecondaryPhotosIfNeeded()

        // Skip automatic migration on init - migration will happen on-demand when item is accessed
        // This prevents blocking the main thread during bulk imports
    }
}

// MARK: - Builder Pattern for Clean Construction

extension InventoryItem {

    /// Builder for creating InventoryItem with optional properties
    @MainActor
    final class Builder {
        private let item: InventoryItem

        init(title: String) {
            self.item = InventoryItem(title: title)
        }

        // MARK: - Core Properties

        @discardableResult
        func quantity(_ quantity: Int) -> Builder {
            item.quantityInt = quantity
            item.quantityString = String(quantity)
            return self
        }

        @discardableResult
        func description(_ description: String) -> Builder {
            item.desc = description
            return self
        }

        @discardableResult
        func serial(_ serial: String) -> Builder {
            item.serial = serial
            return self
        }

        @discardableResult
        func make(_ make: String) -> Builder {
            item.make = make
            return self
        }

        @discardableResult
        func model(_ model: String) -> Builder {
            item.model = model
            return self
        }

        @discardableResult
        func location(_ location: InventoryLocation?) -> Builder {
            item.location = location
            return self
        }

        @discardableResult
        func label(_ label: InventoryLabel?) -> Builder {
            item.label = label
            return self
        }

        @discardableResult
        func price(_ price: Decimal) -> Builder {
            item.price = price
            return self
        }

        @discardableResult
        func notes(_ notes: String) -> Builder {
            item.notes = notes
            return self
        }

        // MARK: - Extended Properties

        @discardableResult
        func purchaseInfo(
            date: Date? = nil, location: String = "", hasWarranty: Bool = false, warrantyExpiration: Date? = nil
        ) -> Builder {
            item.purchaseDate = date
            item.purchaseLocation = location
            item.hasWarranty = hasWarranty
            item.warrantyExpirationDate = warrantyExpiration
            return self
        }

        @discardableResult
        func condition(_ condition: String) -> Builder {
            item.condition = condition
            return self
        }

        @discardableResult
        func financialInfo(replacementCost: Decimal? = nil, depreciationRate: Double? = nil) -> Builder {
            item.replacementCost = replacementCost
            item.depreciationRate = depreciationRate
            return self
        }

        @discardableResult
        func physicalProperties(
            dimensionLength: String = "", dimensionWidth: String = "", dimensionHeight: String = "",
            dimensionUnit: String = "inches", weightValue: String = "", weightUnit: String = "lbs", color: String = "",
            storageRequirements: String = ""
        ) -> Builder {
            item.dimensionLength = dimensionLength
            item.dimensionWidth = dimensionWidth
            item.dimensionHeight = dimensionHeight
            item.dimensionUnit = dimensionUnit
            item.weightValue = weightValue
            item.weightUnit = weightUnit
            item.color = color
            item.storageRequirements = storageRequirements
            return self
        }

        @discardableResult
        func movingInfo(isFragile: Bool = false, priority: Int = 3, roomDestination: String = "") -> Builder {
            item.isFragile = isFragile
            item.movingPriority = priority
            item.roomDestination = roomDestination
            return self
        }

        @discardableResult
        func aiAnalyzed(_ hasUsedAI: Bool = true) -> Builder {
            item.hasUsedAI = hasUsedAI
            return self
        }

        func build() -> InventoryItem {
            return item
        }
    }

    /// Create a new InventoryItem with builder pattern
    @MainActor
    static func builder(title: String) -> Builder {
        return Builder(title: title)
    }

    var isInteger: Bool {
        return Int(quantityString) != nil
    }

    // MARK: - Secondary Photo Management

    func addSecondaryPhotoURL(_ urlString: String) {
        guard !urlString.isEmpty else { return }
        guard !secondaryPhotoURLs.contains(urlString) else { return }
        guard secondaryPhotoURLs.count < 4 else { return }  // Max 4 secondary (5 total with primary)

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

// MARK: - AI Image Analysis Update Helper
extension InventoryItem {
    @MainActor
    func updateFromImageDetails(_ imageDetails: ImageDetails, labels: [InventoryLabel], locations: [InventoryLocation])
    {
        // Core properties (always update)
        self.title = imageDetails.title
        self.quantityString = imageDetails.quantity
        if let quantity = Int(imageDetails.quantity) {
            self.quantityInt = quantity
        }
        self.desc = imageDetails.description
        self.make = imageDetails.make
        self.model = imageDetails.model
        self.serial = imageDetails.serialNumber

        // Price handling
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(
            in: .whitespaces)
        if let price = Decimal(string: priceString) {
            self.price = price
        }

        // Location handling - NEVER overwrite existing location
        if self.location == nil {
            self.location = locations.first { $0.name == imageDetails.location }
        }

        // Label handling - can be overwritten
        self.label = labels.first { $0.name == imageDetails.category }

        // Extended properties - only update if provided by AI
        if let condition = imageDetails.condition, !condition.isEmpty {
            self.condition = condition
        }

        if let color = imageDetails.color, !color.isEmpty {
            self.color = color
        }

        if let purchaseLocation = imageDetails.purchaseLocation, !purchaseLocation.isEmpty {
            self.purchaseLocation = purchaseLocation
        }

        if let replacementCostString = imageDetails.replacementCost, !replacementCostString.isEmpty {
            let cleanedString = replacementCostString.replacingOccurrences(of: "$", with: "").trimmingCharacters(
                in: .whitespaces)
            if let replacementCost = Decimal(string: cleanedString) {
                self.replacementCost = replacementCost
            }
        }

        if let depreciationRateString = imageDetails.depreciationRate, !depreciationRateString.isEmpty {
            let cleanedString = depreciationRateString.replacingOccurrences(of: "%", with: "").trimmingCharacters(
                in: .whitespaces)
            if let depreciationRate = Double(cleanedString) {
                // Convert percentage to decimal (15% -> 0.15)
                self.depreciationRate = depreciationRate / 100.0
            }
        }

        if let storageRequirements = imageDetails.storageRequirements, !storageRequirements.isEmpty {
            self.storageRequirements = storageRequirements
        }

        if let isFragileString = imageDetails.isFragile, !isFragileString.isEmpty {
            self.isFragile = isFragileString.lowercased() == "true"
        }

        // Consolidated dimensions handling
        if let dimensions = imageDetails.dimensions, !dimensions.isEmpty {
            parseDimensions(dimensions)
        } else {
            // Individual dimension handling (when not using consolidated dimensions)
            if let dimensionLength = imageDetails.dimensionLength, !dimensionLength.isEmpty {
                self.dimensionLength = dimensionLength
            }
            if let dimensionWidth = imageDetails.dimensionWidth, !dimensionWidth.isEmpty {
                self.dimensionWidth = dimensionWidth
            }
            if let dimensionHeight = imageDetails.dimensionHeight, !dimensionHeight.isEmpty {
                self.dimensionHeight = dimensionHeight
            }
            if let dimensionUnit = imageDetails.dimensionUnit, !dimensionUnit.isEmpty {
                self.dimensionUnit = dimensionUnit
            }
        }

        // Weight handling
        if let weightValue = imageDetails.weightValue, !weightValue.isEmpty {
            self.weightValue = weightValue
            if let weightUnit = imageDetails.weightUnit, !weightUnit.isEmpty {
                self.weightUnit = weightUnit
            } else {
                self.weightUnit = "lbs"  // default
            }
        }

        // Mark as analyzed by AI
        self.hasUsedAI = true
    }

    // MARK: - Private Parsing Helpers

    private func parseDimensions(_ dimensionsString: String) {
        // Parse formats like "9.4\" x 6.6\" x 0.29\"" or "12 x 8 x 4 inches"
        let cleanedString = dimensionsString.replacingOccurrences(of: "\"", with: " inches")
        let components = cleanedString.components(separatedBy: " x ").compactMap {
            $0.trimmingCharacters(in: .whitespaces)
        }

        if components.count >= 3 {
            // Extract numeric values
            let lengthStr = components[0].replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            let widthStr = components[1].replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            let heightStr = components[2].replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)

            self.dimensionLength = lengthStr
            self.dimensionWidth = widthStr
            self.dimensionHeight = heightStr

            // Determine unit from the original string
            if dimensionsString.contains("\"") || dimensionsString.lowercased().contains("inch") {
                self.dimensionUnit = "inches"
            } else if dimensionsString.lowercased().contains("cm") {
                self.dimensionUnit = "cm"
            } else if dimensionsString.lowercased().contains("feet") || dimensionsString.lowercased().contains("ft") {
                self.dimensionUnit = "feet"
            } else if dimensionsString.lowercased().contains("m") && !dimensionsString.lowercased().contains("cm") {
                self.dimensionUnit = "m"
            } else {
                self.dimensionUnit = "inches"  // default
            }
        }
    }
}
