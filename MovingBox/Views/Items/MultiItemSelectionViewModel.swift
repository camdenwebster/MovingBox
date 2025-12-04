//
//  MultiItemSelectionViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import SwiftUI
import SwiftData
import Foundation

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

    /// Location to assign to created items
    var location: InventoryLocation?

    /// SwiftData context for saving items
    let modelContext: ModelContext

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
        location: InventoryLocation?,
        modelContext: ModelContext
    ) {
        self.analysisResponse = analysisResponse
        self.images = images
        self.location = location
        self.modelContext = modelContext
    }
    
    // MARK: - Location Management

    /// Update the selected location for items
    func updateSelectedLocation(_ newLocation: InventoryLocation?) {
        self.location = newLocation
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
    
    /// Create InventoryItems from selected detected items
    func createSelectedInventoryItems() async throws -> [InventoryItem] {
        guard !images.isEmpty else {
            throw InventoryItemCreationError.noImagesProvided
        }
        
        guard !selectedItems.isEmpty else {
            return []
        }
        
        isProcessingSelection = true
        creationProgress = 0.0
        errorMessage = nil
        
        var createdItems: [InventoryItem] = []
        let selectedDetectedItems = detectedItems.filter { selectedItems.contains($0.id) }
        let totalItems = selectedDetectedItems.count
        
        do {
            for (index, detectedItem) in selectedDetectedItems.enumerated() {
                // Update progress
                creationProgress = Double(index) / Double(totalItems)
                
                // Create inventory item
                let inventoryItem = try await createInventoryItem(from: detectedItem)
                createdItems.append(inventoryItem)
                
                // Small delay for UI feedback
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            // Final progress update
            creationProgress = 1.0
            
            // Save all items to context
            try modelContext.save()
            
            // Reset processing flag on success
            isProcessingSelection = false
            
            return createdItems
            
        } catch {
            errorMessage = error.localizedDescription
            isProcessingSelection = false
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    /// Create a single InventoryItem from a DetectedInventoryItem
    private func createInventoryItem(from detectedItem: DetectedInventoryItem) async throws -> InventoryItem {
        // Create new inventory item
        let inventoryItem = InventoryItem(
            title: detectedItem.title.isEmpty ? "Untitled Item" : detectedItem.title,
            quantityString: "1",
            quantityInt: 1,
            desc: detectedItem.description,
            serial: "",
            model: detectedItem.model,
            make: detectedItem.make,
            location: location,
            label: nil,
            price: parsePrice(from: detectedItem.estimatedPrice),
            insured: false,
            assetId: "",
            notes: "Detected via AI with \(formattedConfidence(detectedItem.confidence)) confidence",
            showInvalidQuantityAlert: false
        )
        
        // Generate unique ID for this item
        let itemId = UUID().uuidString
        
        do {
            // Save primary image
            if let primaryImage = images.first {
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(primaryImage, id: itemId)
                inventoryItem.imageURL = primaryImageURL
            }
            
            // Save secondary images if available
            if images.count > 1 {
                let secondaryImages = Array(images.dropFirst())
                let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(secondaryImages, itemId: itemId)
                inventoryItem.secondaryPhotoURLs = secondaryURLs
            }
            
            // Insert into context
            modelContext.insert(inventoryItem)
            
            // Track telemetry
            TelemetryManager.shared.trackInventoryItemAdded(name: inventoryItem.title)
            
            return inventoryItem
            
        } catch {
            throw InventoryItemCreationError.imageProcessingFailed
        }
    }
    
    /// Parse price string to Decimal
    private func parsePrice(from priceString: String) -> Decimal {
        guard !priceString.isEmpty else { return Decimal.zero }
        
        // Remove currency symbols and commas
        let cleanedString = priceString
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
        
        let cleanedString = estimatedPrice
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