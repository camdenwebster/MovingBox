//
//  MultiItemSelectionViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import Dependencies
import Foundation
import SQLiteData
import SwiftUI

// MARK: - Supporting Types

/// Custom error type for inventory item creation
enum InventoryItemCreationError: Error {
    case noImagesProvided
    case imageProcessingFailed
    case contextSaveFailure
    case invalidItemData

    var localizedDescription: String {
        switch self {
        case .noImagesProvided:
            return "No images provided for item creation"
        case .imageProcessingFailed:
            return "Failed to process item images"
        case .contextSaveFailure:
            return "Failed to save item to database"
        case .invalidItemData:
            return "Invalid item data provided"
        }
    }
}

@Observable
@MainActor
final class MultiItemSelectionViewModel {

    // MARK: - Properties

    /// The analysis response containing detected items
    let analysisResponse: MultiItemAnalysisResponse

    /// Images used for analysis
    var images: [UIImage]

    /// Location ID to assign to created items
    var locationID: UUID?

    /// Home ID to assign to created items
    var homeID: UUID?

    /// Database writer for sqlite-data operations
    @ObservationIgnored @Dependency(\.defaultDatabase) var database

    /// Settings manager for accessing active home
    var settingsManager: SettingsManager?

    /// Currently detected items from analysis
    var detectedItems: [DetectedInventoryItem] {
        analysisResponse.safeItems
    }

    /// Currently selected items for creation
    var selectedItems: Set<String> = []

    /// Current card index in the carousel
    var currentCardIndex: Int = 0

    /// Whether the view is currently processing item creation
    var isProcessingSelection: Bool = false

    /// Progress of item creation (0.0 to 1.0)
    var creationProgress: Double = 0.0

    /// Error message if item creation fails
    var errorMessage: String?

    // MARK: - Computed Properties

    /// Whether there are no detected items
    var hasNoItems: Bool {
        detectedItems.isEmpty
    }

    /// Number of selected items
    var selectedItemsCount: Int {
        selectedItems.count
    }

    /// Whether user can go to previous card
    var canGoToPreviousCard: Bool {
        currentCardIndex > 0
    }

    /// Whether user can go to next card
    var canGoToNextCard: Bool {
        currentCardIndex < detectedItems.count - 1
    }

    /// Current card item (if valid index)
    var currentItem: DetectedInventoryItem? {
        guard currentCardIndex < detectedItems.count else { return nil }
        return detectedItems[currentCardIndex]
    }

    // MARK: - Initialization

    init(
        analysisResponse: MultiItemAnalysisResponse,
        images: [UIImage],
        locationID: UUID?,
        homeID: UUID? = nil
    ) {
        self.analysisResponse = analysisResponse
        self.images = images
        self.locationID = locationID
        self.homeID = homeID
    }

    // MARK: - Location Management

    /// Update the selected location for items
    func updateSelectedLocationID(_ locationID: UUID?) {
        self.locationID = locationID
    }

    // MARK: - Card Navigation

    /// Navigate to the next card
    func goToNextCard() {
        guard canGoToNextCard else { return }
        currentCardIndex += 1
    }

    /// Navigate to the previous card
    func goToPreviousCard() {
        guard canGoToPreviousCard else { return }
        currentCardIndex -= 1
    }

    /// Jump to a specific card index
    func goToCard(at index: Int) {
        guard index >= 0 && index < detectedItems.count else { return }
        currentCardIndex = index
    }

    // MARK: - Item Selection

    /// Check if an item is currently selected
    func isItemSelected(_ item: DetectedInventoryItem) -> Bool {
        selectedItems.contains(item.id)
    }

    /// Toggle selection state of an item
    func toggleItemSelection(_ item: DetectedInventoryItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    /// Select all detected items
    func selectAllItems() {
        selectedItems = Set(detectedItems.map { $0.id })
    }

    /// Deselect all items
    func deselectAllItems() {
        selectedItems.removeAll()
    }

    // MARK: - Item Creation

    /// Create SQLiteInventoryItems from selected detected items
    func createSelectedInventoryItems() async throws -> [SQLiteInventoryItem] {
        guard !images.isEmpty else {
            throw InventoryItemCreationError.noImagesProvided
        }

        guard !selectedItems.isEmpty else {
            return []
        }

        isProcessingSelection = true
        creationProgress = 0.0
        errorMessage = nil

        let existingLabels =
            (try? await database.read { db in
                try SQLiteInventoryLabel.all.fetchAll(db)
            }) ?? []

        let resolvedHomeID = await resolveHomeID()

        var createdItems: [SQLiteInventoryItem] = []
        let selectedDetectedItems = detectedItems.filter { selectedItems.contains($0.id) }
        let totalItems = selectedDetectedItems.count

        do {
            for (index, detectedItem) in selectedDetectedItems.enumerated() {
                creationProgress = Double(index) / Double(totalItems)

                let matchingLabel = findMatchingLabel(for: detectedItem.category, in: existingLabels)
                let inventoryItem = try await createInventoryItem(
                    from: detectedItem, label: matchingLabel, resolvedHomeID: resolvedHomeID)
                createdItems.append(inventoryItem)

                try await Task.sleep(for: .milliseconds(100))
            }

            creationProgress = 1.0
            isProcessingSelection = false
            return createdItems

        } catch {
            let userMessage: String
            if let imageError = error as? OptimizedImageManager.ImageError {
                switch imageError {
                case .compressionFailed:
                    userMessage = "Failed to compress images. Please try again with different photos."
                case .invalidImageData:
                    userMessage = "Invalid image data. Please use a different photo."
                }
            } else {
                userMessage = error.localizedDescription
            }

            errorMessage = userMessage
            isProcessingSelection = false
            print("❌ Multi-item creation failed: \(error)")
            throw error
        }
    }

    // MARK: - Private Methods

    /// Create a single SQLiteInventoryItem from a DetectedInventoryItem
    private func createInventoryItem(
        from detectedItem: DetectedInventoryItem,
        label: SQLiteInventoryLabel?,
        resolvedHomeID: UUID?
    ) async throws -> SQLiteInventoryItem {
        let newID = UUID()
        let itemId = newID.uuidString

        var inventoryItem = SQLiteInventoryItem(
            id: newID,
            title: detectedItem.title.isEmpty ? "Untitled Item" : detectedItem.title,
            desc: detectedItem.description,
            model: detectedItem.model,
            make: detectedItem.make,
            price: parsePrice(from: detectedItem.estimatedPrice),
            assetId: itemId,
            notes: "Detected via AI with \(formattedConfidence(detectedItem.confidence)) confidence",
            hasUsedAI: true,
            locationID: locationID,
            homeID: resolvedHomeID
        )

        // Process images to JPEG data before DB write
        var photoDataList: [(Data, Int)] = []
        for (sortOrder, image) in images.enumerated() {
            if let imageData = await OptimizedImageManager.shared.processImage(image) {
                photoDataList.append((imageData, sortOrder))
            }
        }

        do {
            // Insert item + photos in a single transaction
            let itemToInsert = inventoryItem
            try await database.write { db in
                try SQLiteInventoryItem.insert { itemToInsert }.execute(db)

                for (imageData, sortOrder) in photoDataList {
                    try SQLiteInventoryItemPhoto.insert {
                        SQLiteInventoryItemPhoto(
                            id: UUID(),
                            inventoryItemID: itemToInsert.id,
                            data: imageData,
                            sortOrder: sortOrder
                        )
                    }.execute(db)
                }

                // Insert label join if matched
                if let label {
                    try SQLiteInventoryItemLabel.insert {
                        SQLiteInventoryItemLabel(
                            id: UUID(),
                            inventoryItemID: itemToInsert.id,
                            inventoryLabelID: label.id
                        )
                    }.execute(db)
                }
            }

            TelemetryManager.shared.trackInventoryItemAdded(name: inventoryItem.title)
            return inventoryItem

        } catch {
            print("❌ Failed to save item: \(error.localizedDescription)")
            throw error
        }
    }

    /// Resolves the homeID for a new item
    private func resolveHomeID() async -> UUID? {
        if let homeID { return homeID }

        if let locationID {
            if let location = try? await database.read({ db in
                try SQLiteInventoryLocation.find(locationID).fetchOne(db)
            }), let locationHomeID = location.homeID {
                return locationHomeID
            }
        }

        if let activeHomeIdString = settingsManager?.activeHomeId,
            let activeHomeId = UUID(uuidString: activeHomeIdString)
        {
            if (try? await database.read({ db in
                try SQLiteHome.find(activeHomeId).fetchOne(db)
            })) != nil {
                return activeHomeId
            }
        }

        return try? await database.read { db in
            try SQLiteHome.where { $0.isPrimary == true }.fetchOne(db)?.id
        }
    }

    /// Parse price string to Decimal
    private func parsePrice(from priceString: String) -> Decimal {
        guard !priceString.isEmpty else { return Decimal.zero }

        // Remove currency symbols and commas
        let cleanedString =
            priceString
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        return Decimal(string: cleanedString) ?? Decimal.zero
    }

    /// Format confidence as percentage string
    private func formattedConfidence(_ confidence: Double) -> String {
        let percentage = Int(confidence * 100)
        return "\(percentage)%"
    }

    /// Find matching label for a given category from existing labels
    private func findMatchingLabel(for category: String, in labels: [SQLiteInventoryLabel])
        -> SQLiteInventoryLabel?
    {
        guard !category.isEmpty else { return nil }
        return labels.first { $0.name.lowercased() == category.lowercased() }
    }

    /// Get the label that would be matched for a detected item (for preview in card)
    func getMatchingLabel(for item: DetectedInventoryItem) -> SQLiteInventoryLabel? {
        let existingLabels =
            (try? database.read { db in
                try SQLiteInventoryLabel.fetchAll(db)
            }) ?? []
        return findMatchingLabel(for: item.category, in: existingLabels)
    }
}

// MARK: - Extensions

extension DetectedInventoryItem {
    /// Formatted confidence percentage
    var formattedConfidence: String {
        let percentage = Int(confidence * 100)
        return "\(percentage)%"
    }

    /// Parsed price as Decimal
    var parsedPrice: Decimal {
        guard !estimatedPrice.isEmpty else { return Decimal.zero }

        let cleanedString =
            estimatedPrice
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        return Decimal(string: cleanedString) ?? Decimal.zero
    }

    /// Whether this item has sufficient confidence for reliable data
    var hasHighConfidence: Bool {
        confidence >= 0.8
    }

    /// Whether this item has basic required information
    var hasMinimumData: Bool {
        !title.isEmpty && !category.isEmpty
    }
}
