//
//  MultiItemSelectionViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import Dependencies
import Foundation
import MovingBoxAIAnalysis
import SQLiteData
import SwiftUI
import UIKit

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
    private(set) var analysisResponse: MultiItemAnalysisResponse

    /// Normalized detected items with unique IDs for stable selection/cropping keys
    private var normalizedDetectedItems: [DetectedInventoryItem]

    /// Images used for analysis
    var images: [UIImage]

    /// Location ID to assign to created items
    var locationID: UUID?

    /// Home ID to assign to created items
    var homeID: UUID?

    /// Database writer for sqlite-data operations
    @ObservationIgnored @Dependency(\.defaultDatabase) var database
    private let injectedDatabase: (any DatabaseWriter)?

    /// Settings manager for accessing active home
    var settingsManager: SettingsManager?

    /// Currently detected items from analysis
    var detectedItems: [DetectedInventoryItem] {
        filteredDetectedItems
    }

    /// All detected items from analysis (unfiltered)
    private var allDetectedItems: [DetectedInventoryItem] {
        normalizedDetectedItems
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

    /// Lightweight in-memory thumbnails for list row rendering keyed by item ID.
    private var rowThumbnails: [String: UIImage] = [:]

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
    @ObservationIgnored private var enrichmentTask: Task<Void, Never>?

    /// Cached duplicate grouping and label matching to avoid repeated expensive recomputation per row render.
    private var duplicateLookupCache: [String: DuplicateGroup] = [:]
    private var matchingLabelCache: [String: SQLiteInventoryLabel?] = [:]
    private var availableLabelsCache: [SQLiteInventoryLabel] = []

    // MARK: - Supporting Types

    /// Represents a group of detected items for display (e.g., potential duplicates)
    struct DetectedItemDisplayGroup: Identifiable {
        let id: String
        let items: [DetectedInventoryItem]
        let isPotentialDuplicateGroup: Bool
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

    /// Groups of detected items for display
    var detectedItemGroups: [DetectedItemDisplayGroup] {
        let items = detectedItems
        guard !items.isEmpty else { return [] }

        var emittedGroupIDs = Set<String>()
        var groups: [DetectedItemDisplayGroup] = []

        for item in items {
            if let duplicateGroup = duplicateLookupCache[item.id] {
                guard !emittedGroupIDs.contains(duplicateGroup.id) else { continue }
                emittedGroupIDs.insert(duplicateGroup.id)
                groups.append(
                    DetectedItemDisplayGroup(
                        id: duplicateGroup.id,
                        items: duplicateGroup.items,
                        isPotentialDuplicateGroup: true
                    ))
            } else {
                groups.append(
                    DetectedItemDisplayGroup(
                        id: "single-\(item.id)",
                        items: [item],
                        isPotentialDuplicateGroup: false
                    ))
            }
        }

        return groups
    }

    /// Count of items filtered out by quality gates
    var filteredOutCount: Int {
        max(0, allDetectedItems.count - filteredDetectedItems.count)
    }

    /// Get duplicate hint for an item
    func duplicateHint(for item: DetectedInventoryItem) -> String? {
        guard let group = duplicateLookupCache[item.id], group.items.count > 1 else { return nil }
        return "Potential duplicate (\(group.items.count) similar)"
    }

    // MARK: - Quality Gates

    private let minimumConfidenceThreshold: Double = 0.6
    private let lowConfidenceCropThreshold: Double = 0.75
    private let minimumDetectionAreaFraction: Double = 0.01
    private let maxCroppedImagesPerItem = 4
    private let rowThumbnailMaxDimension: CGFloat = 144
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

    private var activeDatabase: any DatabaseWriter {
        injectedDatabase ?? database
    }

    // MARK: - Initialization

    init(
        analysisResponse: MultiItemAnalysisResponse,
        images: [UIImage],
        location: SQLiteInventoryLocation? = nil,
        homeID: UUID? = nil,
        database: (any DatabaseWriter)? = nil,
        aiAnalysisService: (any AIAnalysisServiceProtocol)? = nil
    ) {
        self.analysisResponse = analysisResponse
        self.normalizedDetectedItems = Self.normalizeDetectedItems(analysisResponse.safeItems)
        self.images = images
        self.locationID = location?.id
        self.homeID = homeID
        self.injectedDatabase = database
        self.aiAnalysisService = aiAnalysisService
        refreshDisplayCaches()
    }

    init(
        analysisResponse: MultiItemAnalysisResponse,
        images: [UIImage],
        locationID: UUID? = nil,
        homeID: UUID? = nil,
        database: (any DatabaseWriter)? = nil,
        aiAnalysisService: (any AIAnalysisServiceProtocol)? = nil
    ) {
        self.analysisResponse = analysisResponse
        self.normalizedDetectedItems = Self.normalizeDetectedItems(analysisResponse.safeItems)
        self.images = images
        self.locationID = locationID
        self.homeID = homeID
        self.injectedDatabase = database
        self.aiAnalysisService = aiAnalysisService
        refreshDisplayCaches()
    }

    /// Update the analysis response (for streaming scenarios)
    func updateAnalysisResponse(_ response: MultiItemAnalysisResponse) {
        let previousIDs = Set(normalizedDetectedItems.map(\.id))
        analysisResponse = response
        normalizedDetectedItems = Self.normalizeDetectedItems(response.safeItems)

        let validIDs = Set(normalizedDetectedItems.map(\.id))
        if previousIDs != validIDs {
            hasCroppedImages = false
            enrichmentFinished = false
            if isEnriching {
                cancelEnrichment()
            }
        }
        selectedItems = selectedItems.intersection(validIDs)
        croppedPrimaryImages = croppedPrimaryImages.filter { validIDs.contains($0.key) }
        croppedSecondaryImages = croppedSecondaryImages.filter { validIDs.contains($0.key) }
        rowThumbnails = rowThumbnails.filter { validIDs.contains($0.key) }
        enrichedDetails = enrichedDetails.filter { validIDs.contains($0.key) }
        matchingLabelCache = matchingLabelCache.filter { validIDs.contains($0.key) }
        duplicateLookupCache = duplicateLookupCache.filter { validIDs.contains($0.key) }

        refreshDisplayCaches()

        if currentCardIndex >= detectedItems.count {
            currentCardIndex = max(0, detectedItems.count - 1)
        }
    }

    /// Start enrichment process
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
            let curated = ImageQualityCurator.curate(
                itemImages,
                keepAtMost: maxCroppedImagesPerItem,
                ensureAtLeast: 1
            )
            return (id: item.id, title: item.title, images: curated)
        }

        enrichmentTask?.cancel()
        enrichmentTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let aiContext = await AIAnalysisContext.from(database: self.activeDatabase, settings: settings)
            await withTaskGroup(of: (String, ImageDetails?).self) { group in
                for item in itemsToEnrich {
                    group.addTask { @MainActor in
                        guard !item.images.isEmpty else { return (item.id, nil) }
                        do {
                            let details = try await service.analyzeItem(
                                from: item.images, settings: settings, context: aiContext)
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
                        self.enrichedDetails[itemId] = details
                    }
                    self.enrichmentCompleted += 1
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

    /// Compute cropped images for detected items
    func computeCroppedImages(limit: Int? = nil) async {
        if hasCroppedImages, limit == nil { return }
        if Task.isCancelled { return }

        let items = detectedItems
        guard !items.isEmpty else { return }

        let maxCount = limit.map { min($0, items.count) } ?? items.count
        for (index, item) in items.enumerated() where index < maxCount {
            if Task.isCancelled { return }
            if croppedPrimaryImages[item.id] != nil { continue }
            let (primary, secondary) = await BoundingBoxCropper.cropDetections(for: item, from: images)

            var candidates: [UIImage] = []
            if let primary { candidates.append(primary) }
            candidates.append(contentsOf: secondary)

            let curatedPayload = await curateCandidatesForDisplay(candidates)

            if let bestPrimary = curatedPayload.primary {
                croppedPrimaryImages[item.id] = bestPrimary
                if rowThumbnails[item.id] == nil, let thumbnail = curatedPayload.rowThumbnail {
                    rowThumbnails[item.id] = thumbnail
                }
            }

            if !curatedPayload.secondary.isEmpty {
                croppedSecondaryImages[item.id] = curatedPayload.secondary
            }

            if index % 2 == 0 {
                await Task.yield()
            }
        }

        if limit == nil {
            hasCroppedImages = true
        }
    }

    /// Get thumbnail for a detected item row
    func rowThumbnail(for item: DetectedInventoryItem) -> UIImage? {
        if let thumbnail = rowThumbnails[item.id] {
            return thumbnail
        }

        if let primary = croppedPrimaryImages[item.id] {
            let thumbnail = RowThumbnailFactory.make(from: primary, maxDimension: rowThumbnailMaxDimension)
            rowThumbnails[item.id] = thumbnail
            return thumbnail
        }

        guard images.count <= 1, let firstImage = images.first else { return nil }

        let thumbnail = RowThumbnailFactory.make(from: firstImage, maxDimension: rowThumbnailMaxDimension)
        rowThumbnails[item.id] = thumbnail
        return thumbnail
    }

    /// Release temporary image memory
    func releaseTemporaryImageMemory(clearSourceImages: Bool = false) {
        cancelEnrichment()
        croppedPrimaryImages.removeAll()
        croppedSecondaryImages.removeAll()
        rowThumbnails.removeAll()
        enrichedDetails.removeAll()
        duplicateLookupCache.removeAll()
        matchingLabelCache.removeAll()
        availableLabelsCache.removeAll()
        hasCroppedImages = false

        if clearSourceImages {
            images.removeAll(keepingCapacity: false)
        }
    }

    /// Update images for the view model
    func updateImages(_ newImages: [UIImage]) async {
        images = newImages
        croppedPrimaryImages.removeAll()
        croppedSecondaryImages.removeAll()
        rowThumbnails.removeAll()
        duplicateLookupCache.removeAll()
        matchingLabelCache.removeAll()
        hasCroppedImages = false
        refreshDisplayCaches()
    }

    /// Update selected location
    func updateSelectedLocation(_ location: SQLiteInventoryLocation?) {
        self.locationID = location?.id
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
    func selectAllItems(avoidingPotentialDuplicates: Bool = false) {
        selectedItems = selectAllTargetItemIDs(avoidingPotentialDuplicates: avoidingPotentialDuplicates)
    }

    /// Whether current selection satisfies the "select all" target set.
    func hasSatisfiedSelectAll(avoidingPotentialDuplicates: Bool = false) -> Bool {
        let targetIDs = selectAllTargetItemIDs(avoidingPotentialDuplicates: avoidingPotentialDuplicates)
        return selectedItems.isSuperset(of: targetIDs)
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

        if !hasCroppedImages {
            await computeCroppedImages()
        }

        isProcessingSelection = true
        creationProgress = 0.0
        errorMessage = nil

        var existingLabels =
            (try? await activeDatabase.read { db in
                try SQLiteInventoryLabel.all.fetchAll(db)
            }) ?? []
        availableLabelsCache = existingLabels
        let existingLocations =
            (try? await activeDatabase.read { db in
                try SQLiteInventoryLocation.all.fetchAll(db)
            }) ?? []

        let resolvedHomeID = await resolveHomeID()

        var createdItems: [SQLiteInventoryItem] = []
        let selectedDetectedItems = detectedItems.filter { selectedItems.contains($0.id) }
        let totalItems = selectedDetectedItems.count
        let progressUpdateStride = max(1, totalItems / 20)

        do {
            for (index, detectedItem) in selectedDetectedItems.enumerated() {
                if index == 0 || index == totalItems - 1 || index % progressUpdateStride == 0 {
                    creationProgress = Double(index) / Double(totalItems)
                }

                let matchedLabels = matchingLabels(for: detectedItem.category, in: existingLabels)
                let inventoryItem = try await createInventoryItem(
                    from: detectedItem,
                    labels: matchedLabels,
                    availableLabels: existingLabels,
                    availableLocations: existingLocations,
                    resolvedHomeID: resolvedHomeID
                )
                createdItems.append(inventoryItem)

                for label in matchedLabels where !existingLabels.contains(where: { $0.id == label.id }) {
                    existingLabels.append(label)
                }
            }

            creationProgress = 1.0
            releaseTemporaryImageMemory(clearSourceImages: true)
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
        labels: [SQLiteInventoryLabel],
        availableLabels: [SQLiteInventoryLabel],
        availableLocations: [SQLiteInventoryLocation],
        resolvedHomeID: UUID?
    ) async throws -> SQLiteInventoryItem {
        let newID = UUID()
        let itemId = newID.uuidString

        var inventoryItem = SQLiteInventoryItem(
            id: newID,
            title: detectedItem.title.isEmpty ? "Untitled Item" : detectedItem.title,
            desc: detectedItem.description,
            serial: "",
            model: detectedItem.model,
            make: detectedItem.make,
            price: parsePrice(from: detectedItem.estimatedPrice),
            assetId: itemId,
            notes: "",
            locationID: locationID,
            homeID: resolvedHomeID
        )
        inventoryItem.labelIDs = labels.map(\.id)

        if let enriched = enrichedDetails[detectedItem.id] {
            applyEnrichedDetails(
                to: &inventoryItem,
                enriched: enriched,
                availableLocations: availableLocations
            )
            let enrichedTitle = enriched.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if enrichedTitle.isEmpty || enrichedTitle == "Unknown Item" || enrichedTitle == "Unknown" {
                inventoryItem.title = detectedItem.title.isEmpty ? "Untitled Item" : detectedItem.title
            }
            inventoryItem.hasUsedAI = true
        } else {
            inventoryItem.notes =
                "AI-detected \(detectedItem.category) with \(Int(detectedItem.confidence * 100))% confidence"
            inventoryItem.hasUsedAI = true
        }

        do {
            let primaryImage = croppedPrimaryImages[detectedItem.id] ?? fallbackPrimaryImage(for: detectedItem)
            let secondaryImages = croppedSecondaryImages[detectedItem.id] ?? []

            var photoDataList: [(Data, Int)] = []
            if let primaryImage, let primaryImageData = await OptimizedImageManager.shared.processImage(primaryImage) {
                photoDataList.append((primaryImageData, 0))
            }
            for (index, image) in secondaryImages.enumerated() {
                if let imageData = await OptimizedImageManager.shared.processImage(image) {
                    photoDataList.append((imageData, index + 1))
                }
            }
            let photoEntries = photoDataList

            // Insert item + photos in a single transaction
            let itemToInsert = inventoryItem
            try await activeDatabase.write { db in
                try SQLiteInventoryItem.insert { itemToInsert }.execute(db)

                for (imageData, sortOrder) in photoEntries {
                    try SQLiteInventoryItemPhoto.insert {
                        SQLiteInventoryItemPhoto(
                            id: UUID(),
                            inventoryItemID: itemToInsert.id,
                            data: imageData,
                            sortOrder: sortOrder
                        )
                    }.execute(db)
                }

                // Insert label joins if matched
                for label in labels {
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
            if let location = try? await activeDatabase.read({ db in
                try SQLiteInventoryLocation.find(locationID).fetchOne(db)
            }), let locationHomeID = location.homeID {
                return locationHomeID
            }
        }

        if let activeHomeIdString = settingsManager?.activeHomeId,
            let activeHomeId = UUID(uuidString: activeHomeIdString)
        {
            if (try? await activeDatabase.read({ db in
                try SQLiteHome.find(activeHomeId).fetchOne(db)
            })) != nil {
                return activeHomeId
            }
        }

        return try? await activeDatabase.read { db in
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

    private func selectAllTargetItemIDs(avoidingPotentialDuplicates: Bool) -> Set<String> {
        guard avoidingPotentialDuplicates else {
            return Set(detectedItems.map(\.id))
        }

        var targetIDs = Set<String>()
        for group in detectedItemGroups {
            if let firstItem = group.items.first {
                targetIDs.insert(firstItem.id)
            }
        }
        return targetIDs
    }

    /// Format confidence as percentage string
    private func formattedConfidence(_ confidence: Double) -> String {
        let percentage = Int(confidence * 100)
        return "\(percentage)%"
    }

    /// Find matching labels for a given category from existing labels
    private func matchingLabels(for category: String, in labels: [SQLiteInventoryLabel])
        -> [SQLiteInventoryLabel]
    {
        guard !category.isEmpty else { return [] }
        if let exact = labels.first(where: { $0.name.lowercased() == category.lowercased() }) {
            return [exact]
        }
        return []
    }

    /// Get the label that would be matched for a detected item (for preview in card)
    func getMatchingLabel(for item: DetectedInventoryItem) -> SQLiteInventoryLabel? {
        if let cached = matchingLabelCache[item.id] {
            return cached
        }
        return nil
    }

    private func applyEnrichedDetails(
        to item: inout SQLiteInventoryItem,
        enriched: ImageDetails,
        availableLocations: [SQLiteInventoryLocation]
    ) {
        item.title = enriched.title
        item.quantityString = enriched.quantity
        if let quantity = Int(enriched.quantity) {
            item.quantityInt = quantity
        }
        item.desc = enriched.description
        item.make = enriched.make
        item.model = enriched.model
        item.serial = enriched.serialNumber
        item.price = parsePrice(from: enriched.price)

        if item.locationID == nil {
            if let matchedLocation = availableLocations.first(where: {
                $0.name.lowercased() == enriched.location.lowercased()
            }) {
                item.locationID = matchedLocation.id
            }
        }

        if let condition = enriched.condition, !condition.isEmpty {
            item.condition = condition
        }
        if let color = enriched.color, !color.isEmpty {
            item.color = color
        }
        if let purchaseLocation = enriched.purchaseLocation, !purchaseLocation.isEmpty {
            item.purchaseLocation = purchaseLocation
        }
        if let replacementCost = enriched.replacementCost {
            item.replacementCost = parsePrice(from: replacementCost)
        }
        if let depreciationRate = enriched.depreciationRate {
            let cleaned =
                depreciationRate
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let val = Double(cleaned) {
                item.depreciationRate = val / 100.0
            }
        }
        if let storageRequirements = enriched.storageRequirements, !storageRequirements.isEmpty {
            item.storageRequirements = storageRequirements
        }
        if let isFragile = enriched.isFragile, !isFragile.isEmpty {
            item.isFragile = isFragile.lowercased() == "true"
        }
        if let dimensionLength = enriched.dimensionLength, !dimensionLength.isEmpty {
            item.dimensionLength = dimensionLength
        }
        if let dimensionWidth = enriched.dimensionWidth, !dimensionWidth.isEmpty {
            item.dimensionWidth = dimensionWidth
        }
        if let dimensionHeight = enriched.dimensionHeight, !dimensionHeight.isEmpty {
            item.dimensionHeight = dimensionHeight
        }
        if let dimensionUnit = enriched.dimensionUnit, !dimensionUnit.isEmpty {
            item.dimensionUnit = dimensionUnit
        }
        if let weightValue = enriched.weightValue, !weightValue.isEmpty {
            item.weightValue = weightValue
            item.weightUnit = enriched.weightUnit ?? "lbs"
        }
    }

    private func fallbackPrimaryImage(for detectedItem: DetectedInventoryItem) -> UIImage? {
        if images.count == 1 {
            return images.first
        }

        guard
            let sourceImageIndex = detectedItem.detections?.first?.sourceImageIndex,
            images.indices.contains(sourceImageIndex)
        else {
            return nil
        }

        return images[sourceImageIndex]
    }

    private struct CuratedImagePayload {
        let primary: UIImage?
        let secondary: [UIImage]
        let rowThumbnail: UIImage?
    }

    private func curateCandidatesForDisplay(_ candidates: [UIImage]) async -> CuratedImagePayload {
        guard !candidates.isEmpty else {
            return CuratedImagePayload(primary: nil, secondary: [], rowThumbnail: nil)
        }

        let keepAtMost = maxCroppedImagesPerItem
        let thumbnailMaxDimension = rowThumbnailMaxDimension

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let payload = autoreleasepool { () -> CuratedImagePayload in
                    let curated = ImageQualityCurator.curate(
                        candidates,
                        keepAtMost: keepAtMost,
                        ensureAtLeast: 1
                    )
                    let primary = curated.first
                    let secondary = Array(curated.dropFirst())
                    let thumbnail = primary.map {
                        RowThumbnailFactory.make(from: $0, maxDimension: thumbnailMaxDimension)
                    }
                    return CuratedImagePayload(primary: primary, secondary: secondary, rowThumbnail: thumbnail)
                }
                continuation.resume(returning: payload)
            }
        }
    }

    func cancelEnrichment() {
        enrichmentTask?.cancel()
        enrichmentTask = nil
        isEnriching = false
        enrichmentFinished = false
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

    private struct DuplicateGroup {
        let id: String
        let items: [DetectedInventoryItem]
    }

    private func duplicateGroupLookup(for items: [DetectedInventoryItem]) -> [String: DuplicateGroup] {
        guard items.count > 1 else { return [:] }

        var parent: [String: String] = [:]
        for item in items {
            parent[item.id] = item.id
        }

        func find(_ id: String, _ parent: inout [String: String]) -> String {
            let root = parent[id] ?? id
            if root == id { return id }
            let flattened = find(root, &parent)
            parent[id] = flattened
            return flattened
        }

        func union(_ lhs: String, _ rhs: String, _ parent: inout [String: String]) {
            let lhsRoot = find(lhs, &parent)
            let rhsRoot = find(rhs, &parent)
            if lhsRoot != rhsRoot {
                parent[rhsRoot] = lhsRoot
            }
        }

        for i in 0..<items.count {
            for j in (i + 1)..<items.count {
                if isPotentialDuplicate(items[i], items[j]) {
                    union(items[i].id, items[j].id, &parent)
                }
            }
        }

        var components: [String: [DetectedInventoryItem]] = [:]
        for item in items {
            let root = find(item.id, &parent)
            components[root, default: []].append(item)
        }

        var lookup: [String: DuplicateGroup] = [:]
        for componentItems in components.values where componentItems.count > 1 {
            let ordered = items.filter { item in
                componentItems.contains(where: { $0.id == item.id })
            }
            let groupID = "duplicates-\(ordered.map(\.id).joined(separator: "-"))"
            let group = DuplicateGroup(id: groupID, items: ordered)
            for item in ordered {
                lookup[item.id] = group
            }
        }

        return lookup
    }

    private func refreshDisplayCaches() {
        let items = detectedItems
        duplicateLookupCache = duplicateGroupLookup(for: items)

        if availableLabelsCache.isEmpty {
            availableLabelsCache =
                (try? activeDatabase.read { db in
                    try SQLiteInventoryLabel.fetchAll(db)
                }) ?? []
        }

        var updatedLabelCache: [String: SQLiteInventoryLabel?] = [:]
        for item in items {
            updatedLabelCache[item.id] =
                matchingLabels(
                    for: item.category,
                    in: availableLabelsCache
                ).first
        }
        matchingLabelCache = updatedLabelCache
    }

    private func isPotentialDuplicate(_ lhs: DetectedInventoryItem, _ rhs: DetectedInventoryItem) -> Bool {
        let lhsTitle = normalizedTitle(lhs.title)
        let rhsTitle = normalizedTitle(rhs.title)
        guard !lhsTitle.isEmpty, !rhsTitle.isEmpty else { return false }

        let lhsCategory = lhs.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rhsCategory = rhs.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let categoriesCompatible = lhsCategory.isEmpty || rhsCategory.isEmpty || lhsCategory == rhsCategory
        guard categoriesCompatible else { return false }

        let lhsMakeModel = "\(lhs.make) \(lhs.model)".trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rhsMakeModel = "\(rhs.make) \(rhs.model)".trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !lhsMakeModel.isEmpty, !rhsMakeModel.isEmpty, lhsMakeModel == rhsMakeModel {
            return true
        }

        if lhsTitle == rhsTitle {
            return true
        }

        if lhsTitle.contains(rhsTitle) || rhsTitle.contains(lhsTitle) {
            return true
        }

        let distance = levenshtein(lhsTitle, rhsTitle)
        if distance <= 2 {
            return true
        }

        let lhsTokens = Set(lhsTitle.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhsTitle.split(separator: " ").map(String.init))
        let overlapCount = lhsTokens.intersection(rhsTokens).count
        let tokenSimilarity = Double(overlapCount) / Double(max(lhsTokens.count, rhsTokens.count))
        if overlapCount >= 2 && tokenSimilarity >= 0.67 {
            return true
        }

        return false
    }

    private func normalizedTitle(_ value: String) -> String {
        let stopWords: Set<String> = ["a", "an", "the", "item", "object"]
        return
            value
            .lowercased()
            .split(separator: " ")
            .map { token -> String in
                let cleaned = token.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
                return String(String.UnicodeScalarView(cleaned))
            }
            .filter { !$0.isEmpty && !stopWords.contains($0) }
            .joined(separator: " ")
    }

    private func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        if lhsChars.isEmpty { return rhsChars.count }
        if rhsChars.isEmpty { return lhsChars.count }

        var distances = Array(repeating: Array(repeating: 0, count: rhsChars.count + 1), count: lhsChars.count + 1)
        for i in 0...lhsChars.count { distances[i][0] = i }
        for j in 0...rhsChars.count { distances[0][j] = j }

        for i in 1...lhsChars.count {
            for j in 1...rhsChars.count {
                if lhsChars[i - 1] == rhsChars[j - 1] {
                    distances[i][j] = distances[i - 1][j - 1]
                } else {
                    let deletion = distances[i - 1][j] + 1
                    let insertion = distances[i][j - 1] + 1
                    let substitution = distances[i - 1][j - 1] + 1
                    distances[i][j] = min(deletion, insertion, substitution)
                }
            }
        }
        return distances[lhsChars.count][rhsChars.count]
    }

    private static func normalizeDetectedItems(_ items: [DetectedInventoryItem]) -> [DetectedInventoryItem] {
        var seenCounts: [String: Int] = [:]

        return items.enumerated().map { index, item in
            let baseID = item.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedBaseID = baseID.isEmpty ? "detected-item-\(index)" : baseID
            let seenCount = seenCounts[normalizedBaseID, default: 0]
            seenCounts[normalizedBaseID] = seenCount + 1

            if seenCount == 0 {
                return copy(item, withID: normalizedBaseID)
            }

            return copy(item, withID: "\(normalizedBaseID)--\(seenCount)")
        }
    }

    private static func copy(_ item: DetectedInventoryItem, withID id: String) -> DetectedInventoryItem {
        DetectedInventoryItem(
            id: id,
            title: item.title,
            description: item.description,
            category: item.category,
            make: item.make,
            model: item.model,
            estimatedPrice: item.estimatedPrice,
            confidence: item.confidence,
            detections: item.detections
        )
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

private enum RowThumbnailFactory {
    static func make(from image: UIImage, maxDimension: CGFloat) -> UIImage {
        guard maxDimension > 0 else { return image }

        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return image }

        let widthScale = maxDimension / originalSize.width
        let heightScale = maxDimension / originalSize.height
        let scale = min(1.0, min(widthScale, heightScale))
        guard scale < 1.0 else { return image }

        let targetSize = CGSize(
            width: max(1, floor(originalSize.width * scale)),
            height: max(1, floor(originalSize.height * scale))
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private enum ImageQualityCurator {
    private struct ScoredImage {
        let image: UIImage
        let sharpness: Double
        let contrast: Double
        let perceptualHash: UInt64
    }

    private static let minimumSharpness: Double = 0.04
    private static let minimumContrast: Double = 0.035
    private static let duplicateHashDistanceThreshold: Int = 5

    static func curate(
        _ images: [UIImage],
        keepAtMost: Int,
        ensureAtLeast minimumCount: Int = 1
    ) -> [UIImage] {
        guard !images.isEmpty else { return [] }
        guard keepAtMost > 0 else { return Array(images.prefix(max(minimumCount, 1))) }

        let scored = images.compactMap(score)
        guard !scored.isEmpty else { return Array(images.prefix(max(minimumCount, 1))) }

        let filtered = scored.filter {
            $0.sharpness >= minimumSharpness && $0.contrast >= minimumContrast
        }

        let candidates = filtered.isEmpty ? scored : filtered
        let deduplicated = deduplicate(candidates)

        let sorted = deduplicated.sorted {
            if $0.sharpness == $1.sharpness {
                return $0.contrast > $1.contrast
            }
            return $0.sharpness > $1.sharpness
        }

        var selected = Array(sorted.prefix(keepAtMost)).map(\.image)
        if selected.count < minimumCount {
            let fallback = scored.sorted { $0.sharpness > $1.sharpness }.map(\.image)
            for image in fallback where selected.count < minimumCount {
                if !selected.contains(where: { $0 === image }) {
                    selected.append(image)
                }
            }
        }

        return selected
    }

    private static func deduplicate(_ scored: [ScoredImage]) -> [ScoredImage] {
        var kept: [ScoredImage] = []
        let ranked = scored.sorted {
            if $0.sharpness == $1.sharpness {
                return $0.contrast > $1.contrast
            }
            return $0.sharpness > $1.sharpness
        }

        for candidate in ranked {
            let isDuplicate = kept.contains {
                hammingDistance($0.perceptualHash, candidate.perceptualHash) <= duplicateHashDistanceThreshold
            }
            if !isDuplicate {
                kept.append(candidate)
            }
        }
        return kept
    }

    private static func score(_ image: UIImage) -> ScoredImage? {
        guard let downsampled = downsampledGrayscalePixels(for: image, side: 64) else { return nil }
        let sharpness = gradientSharpness(
            pixels: downsampled.pixels,
            width: downsampled.width,
            height: downsampled.height
        )
        let contrast = luminanceStdDev(downsampled.pixels)
        let hash = perceptualHash(for: image)
        return ScoredImage(image: image, sharpness: sharpness, contrast: contrast, perceptualHash: hash)
    }

    private static func perceptualHash(for image: UIImage) -> UInt64 {
        guard let sample = downsampledGrayscalePixels(for: image, width: 9, height: 8) else { return 0 }
        var hash: UInt64 = 0
        var bit: UInt64 = 1
        for row in 0..<8 {
            for col in 0..<8 {
                let left = sample.pixels[row * 9 + col]
                let right = sample.pixels[row * 9 + col + 1]
                if left > right {
                    hash |= bit
                }
                bit <<= 1
            }
        }
        return hash
    }

    private static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }

    private static func gradientSharpness(pixels: [UInt8], width: Int, height: Int) -> Double {
        guard width > 1, height > 1 else { return 0 }
        var total: Double = 0
        var count = 0

        for y in 0..<(height - 1) {
            for x in 0..<(width - 1) {
                let idx = y * width + x
                let p = Double(pixels[idx])
                let right = Double(pixels[idx + 1])
                let down = Double(pixels[idx + width])
                total += abs(p - right) + abs(p - down)
                count += 2
            }
        }

        guard count > 0 else { return 0 }
        return total / Double(count * 255)
    }

    private static func luminanceStdDev(_ pixels: [UInt8]) -> Double {
        guard !pixels.isEmpty else { return 0 }
        let values = pixels.map { Double($0) / 255.0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance =
            values.reduce(0) { partial, value in
                let delta = value - mean
                return partial + (delta * delta)
            } / Double(values.count)
        return sqrt(variance)
    }

    private static func downsampledGrayscalePixels(for image: UIImage, side: Int) -> (
        pixels: [UInt8], width: Int, height: Int
    )? {
        downsampledGrayscalePixels(for: image, width: side, height: side)
    }

    private static func downsampledGrayscalePixels(for image: UIImage, width: Int, height: Int) -> (
        pixels: [UInt8], width: Int, height: Int
    )? {
        guard let cgImage = image.cgImage else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard
            let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        else { return nil }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (pixels: pixels, width: width, height: height)
    }
}
