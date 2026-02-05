//
//  MultiItemSelectionViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import Foundation
import SwiftData
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

    /// Location to assign to created items
    var location: InventoryLocation?

    /// SwiftData context for saving items
    let modelContext: ModelContext

    /// Settings manager for accessing active home
    var settingsManager: SettingsManager?

    /// Currently detected items from analysis
    var detectedItems: [DetectedInventoryItem] {
        filteredDetectedItems
    }

    /// All detected items from analysis (unfiltered)
    private var allDetectedItems: [DetectedInventoryItem] {
        analysisResponse.safeItems
    }

    /// Count of items filtered out by quality gates
    var filteredOutCount: Int {
        max(0, allDetectedItems.count - filteredDetectedItems.count)
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

    /// Cropped primary images keyed by item ID
    var croppedPrimaryImages: [String: UIImage] = [:]

    /// Cropped secondary images keyed by item ID
    var croppedSecondaryImages: [String: [UIImage]] = [:]

    /// Whether cropped images have been computed
    var hasCroppedImages: Bool = false

    /// AI analysis service for pass 2 enrichment
    var aiAnalysisService: AIAnalysisServiceProtocol?

    /// Enriched ImageDetails keyed by detected item ID
    var enrichedDetails: [String: ImageDetails] = [:]

    /// Enrichment progress counters
    var enrichmentCompleted: Int = 0
    var enrichmentTotal: Int = 0

    /// Enrichment state flags
    var isEnriching: Bool = false
    var enrichmentFinished: Bool = false

    /// Background enrichment task
    private var enrichmentTask: Task<Void, Never>?

    // MARK: - Quality Gates

    private let minimumConfidenceThreshold: Double = 0.6
    private let lowConfidenceCropThreshold: Double = 0.75
    private let minimumDetectionAreaFraction: Double = 0.01
    private let lowQualityTitlePhrases: [String] = [
        "indistinguishable",
        "indistinguisable",
        "unidentifiable",
        "unrecognizable",
        "unknown item",
        "unknown object",
        "unclear",
        "blurry",
        "can't identify",
        "cannot identify",
        "not sure",
        "unsure",
    ]

    private var filteredDetectedItems: [DetectedInventoryItem] {
        allDetectedItems.filter { !shouldFilter($0) }
    }

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
        modelContext: ModelContext,
        aiAnalysisService: AIAnalysisServiceProtocol? = nil
    ) {
        self.analysisResponse = analysisResponse
        self.images = images
        self.location = location
        self.modelContext = modelContext
        self.aiAnalysisService = aiAnalysisService
    }

    // MARK: - Bounding Box Cropping

    /// Update the source images for cropping, resetting any cached crops.
    func updateImages(_ newImages: [UIImage]) async {
        images = newImages
        croppedPrimaryImages.removeAll()
        croppedSecondaryImages.removeAll()
        hasCroppedImages = false
    }

    /// Compute cropped images for detected items from their bounding box detections.
    /// If a limit is provided, only compute the first N items without marking as complete.
    func computeCroppedImages(limit: Int? = nil) async {
        if hasCroppedImages, limit == nil { return }

        let items = detectedItems
        guard !items.isEmpty else { return }

        let maxCount = limit.map { min($0, items.count) } ?? items.count
        for (index, item) in items.enumerated() where index < maxCount {
            if croppedPrimaryImages[item.id] != nil { continue }
            let (primary, secondary) = await BoundingBoxCropper.cropDetections(for: item, from: images)
            if let primary { croppedPrimaryImages[item.id] = primary }
            if !secondary.isEmpty { croppedSecondaryImages[item.id] = secondary }
        }

        if limit == nil {
            hasCroppedImages = true
        }
    }

    /// Get the primary image for a detected item (cropped if available, falls back to first source image)
    func primaryImage(for item: DetectedInventoryItem) -> UIImage? {
        if let cropped = croppedPrimaryImages[item.id] {
            return cropped
        }

        guard images.count <= 1 else { return nil }

        return images.first
    }

    // MARK: - Pass 2 Enrichment

    func startEnrichment(settings: SettingsManager) {
        guard !isEnriching, !enrichmentFinished, let service = aiAnalysisService else { return }

        enrichmentCompleted = 0
        enrichmentTotal = detectedItems.count
        isEnriching = true

        let itemsToEnrich = detectedItems.map { item in
            var itemImages: [UIImage] = []
            if let primary = croppedPrimaryImages[item.id] {
                itemImages.append(primary)
            }
            if let secondaries = croppedSecondaryImages[item.id] {
                itemImages.append(contentsOf: secondaries)
            }
            return (id: item.id, title: item.title, images: itemImages)
        }

        enrichmentTask?.cancel()
        enrichmentTask = Task { @MainActor [weak self] in
            guard let self else { return }

            await withTaskGroup(of: (String, ImageDetails?).self) { group in
                for item in itemsToEnrich {
                    group.addTask { @MainActor in
                        guard !item.images.isEmpty else { return (item.id, nil) }
                        do {
                            let details = try await service.analyzeItem(
                                from: item.images, settings: settings, modelContext: self.modelContext)
                            return (item.id, details)
                        } catch {
                            print("Pass 2 failed for '\(item.title)': \(error.localizedDescription)")
                            return (item.id, nil)
                        }
                    }
                }

                for await (itemId, details) in group {
                    if Task.isCancelled {
                        group.cancelAll()
                        break
                    }
                    if let details {
                        enrichedDetails[itemId] = details
                    }
                    enrichmentCompleted += 1
                }
            }

            if Task.isCancelled {
                isEnriching = false
                enrichmentTask = nil
                return
            }

            isEnriching = false
            enrichmentFinished = true
            enrichmentTask = nil
        }
    }

    func cancelEnrichment() {
        enrichmentTask?.cancel()
        enrichmentTask = nil
        isEnriching = false
        enrichmentFinished = false
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

        if !hasCroppedImages {
            await computeCroppedImages()
        }

        isProcessingSelection = true
        creationProgress = 0.0
        errorMessage = nil

        // Fetch existing labels to match against categories
        var existingLabels = (try? modelContext.fetch(FetchDescriptor<InventoryLabel>())) ?? []

        var createdItems: [InventoryItem] = []
        let selectedDetectedItems = detectedItems.filter { selectedItems.contains($0.id) }
        let totalItems = selectedDetectedItems.count

        do {
            for (index, detectedItem) in selectedDetectedItems.enumerated() {
                // Update progress
                creationProgress = Double(index) / Double(totalItems)

                let matchedLabels = LabelAutoAssignment.labels(
                    for: [detectedItem.category],
                    existingLabels: existingLabels,
                    modelContext: modelContext
                )

                // Create inventory item with matched labels
                let inventoryItem = try await createInventoryItem(from: detectedItem, labels: matchedLabels)
                for label in matchedLabels
                where !existingLabels.contains(where: { $0.id == label.id }) {
                    existingLabels.append(label)
                }
                createdItems.append(inventoryItem)

                // Small delay for UI feedback
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
            }

            // Final progress update
            creationProgress = 1.0

            // Save all items to context
            try modelContext.save()

            // Reset processing flag on success
            isProcessingSelection = false

            return createdItems

        } catch {
            // Provide user-friendly error message
            let userMessage: String
            if let imageError = error as? OptimizedImageManager.ImageError {
                switch imageError {
                case .compressionFailed:
                    userMessage = "Failed to compress images. Please try again with different photos."
                case .invalidImageData:
                    userMessage = "Invalid image data. Please use a different photo."
                case .iCloudNotAvailable:
                    userMessage =
                        "iCloud is not available. Please check your iCloud settings or try again later."
                case .invalidBaseURL:
                    userMessage = "Storage configuration error. Please restart the app."
                }
            } else if let nsError = error as NSError? {
                // File system errors
                if nsError.domain == NSCocoaErrorDomain {
                    switch nsError.code {
                    case NSFileWriteOutOfSpaceError:
                        userMessage =
                            "Not enough storage space available. Please free up some space and try again."
                    case NSFileWriteNoPermissionError:
                        userMessage = "Permission denied. Please check app permissions in Settings."
                    case NSFileWriteVolumeReadOnlyError:
                        userMessage = "Storage is read-only. Please check your device settings."
                    default:
                        userMessage = "Failed to save images: \(nsError.localizedDescription)"
                    }
                } else {
                    userMessage = error.localizedDescription
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

    /// Create a single InventoryItem from a DetectedInventoryItem
    private func createInventoryItem(from detectedItem: DetectedInventoryItem, labels: [InventoryLabel])
        async throws -> InventoryItem
    {
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
            labels: labels,
            price: parsePrice(from: detectedItem.estimatedPrice),
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false
        )

        // Generate unique ID for this item
        let itemId = UUID().uuidString

        if let enriched = enrichedDetails[detectedItem.id] {
            let originalTitle = inventoryItem.title
            let labels = (try? modelContext.fetch(FetchDescriptor<InventoryLabel>())) ?? []
            let locations = (try? modelContext.fetch(FetchDescriptor<InventoryLocation>())) ?? []

            inventoryItem.updateFromImageDetails(
                enriched,
                labels: labels,
                locations: locations,
                modelContext: modelContext,
                preserveExistingLabels: true
            )
            if enriched.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || enriched.title == "Unknown Item"
                || enriched.title == "Unknown"
            {
                inventoryItem.title = originalTitle
            }
            inventoryItem.hasUsedAI = true
        }

        do {
            // Only save cropped images - discard original source photos
            if let croppedPrimary = croppedPrimaryImages[detectedItem.id] {
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(
                    croppedPrimary, id: itemId)
                inventoryItem.imageURL = primaryImageURL
            }

            // Save cropped secondary images (multi-angle crops) only
            if let croppedSecondaries = croppedSecondaryImages[detectedItem.id], !croppedSecondaries.isEmpty {
                let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(
                    croppedSecondaries, itemId: itemId)
                inventoryItem.secondaryPhotoURLs = secondaryURLs
            }

            // Assign active home if item has no location or location has no home
            if inventoryItem.location == nil || inventoryItem.location?.home == nil {
                // Get active home from SettingsManager
                if let activeHomeIdString = settingsManager?.activeHomeId,
                    let activeHomeId = UUID(uuidString: activeHomeIdString)
                {
                    let homeDescriptor = FetchDescriptor<Home>(predicate: #Predicate<Home> { $0.id == activeHomeId })
                    if let activeHome = try? modelContext.fetch(homeDescriptor).first {
                        inventoryItem.home = activeHome
                    } else {
                        // Fallback to primary home
                        let primaryHomeDescriptor = FetchDescriptor<Home>(predicate: #Predicate { $0.isPrimary })
                        if let primaryHome = try? modelContext.fetch(primaryHomeDescriptor).first {
                            inventoryItem.home = primaryHome
                        }
                    }
                } else {
                    // Fallback to primary home
                    let homeDescriptor = FetchDescriptor<Home>(predicate: #Predicate { $0.isPrimary })
                    if let primaryHome = try? modelContext.fetch(homeDescriptor).first {
                        inventoryItem.home = primaryHome
                    }
                }
            }

            // Insert into context
            modelContext.insert(inventoryItem)

            // Track telemetry
            TelemetryManager.shared.trackInventoryItemAdded(name: inventoryItem.title)

            return inventoryItem

        } catch {
            // Preserve the actual error message for better debugging
            print("❌ Failed to save images for item: \(error.localizedDescription)")
            throw error
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

    /// Find matching labels for a given category from existing labels
    private func matchingLabels(for category: String, in labels: [InventoryLabel]) -> [InventoryLabel] {
        LabelAutoAssignment.labels(for: [category], existingLabels: labels, modelContext: nil)
    }

    /// Get the label that would be matched for a detected item (for preview in card)
    func getMatchingLabel(for item: DetectedInventoryItem) -> InventoryLabel? {
        let existingLabels = (try? modelContext.fetch(FetchDescriptor<InventoryLabel>())) ?? []
        return matchingLabels(for: item.category, in: existingLabels).first
    }

    // MARK: - Quality Helpers

    private func shouldFilter(_ item: DetectedInventoryItem) -> Bool {
        let normalizedTitle = item.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedCategory = item.category
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedTitle.isEmpty {
            return true
        }

        if lowQualityTitlePhrases.contains(where: { normalizedTitle.contains($0) }) {
            return true
        }

        if item.confidence < minimumConfidenceThreshold {
            return true
        }

        if (normalizedCategory.isEmpty || normalizedCategory.contains("unknown"))
            && item.confidence < lowConfidenceCropThreshold
        {
            return true
        }

        if images.count > 1 {
            guard let detections = item.detections, !detections.isEmpty else {
                return true
            }

            let maxArea = detections.compactMap { detectionAreaFraction($0) }.max() ?? 0
            if maxArea < minimumDetectionAreaFraction && item.confidence < lowConfidenceCropThreshold {
                return true
            }
        }

        return false
    }

    private func detectionAreaFraction(_ detection: ItemDetection) -> Double? {
        guard detection.boundingBox.count >= 4 else { return nil }
        let ymin = detection.boundingBox[0]
        let xmin = detection.boundingBox[1]
        let ymax = detection.boundingBox[2]
        let xmax = detection.boundingBox[3]

        let width = max(0, xmax - xmin)
        let height = max(0, ymax - ymin)
        guard width > 0, height > 0 else { return nil }

        return Double(width * height) / 1_000_000.0
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
