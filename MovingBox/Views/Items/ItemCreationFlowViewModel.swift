//
//  ItemCreationFlowViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import AVFoundation
import Dependencies
import Foundation
import MovingBoxAIAnalysis
import SQLiteData
import SwiftUI
import UIKit
import UserNotifications

@MainActor
class ItemCreationFlowViewModel: ObservableObject {

    // MARK: - Properties

    /// The capture mode (single item or multi-item)
    /// Can be updated if user switches modes during camera capture
    @Published var captureMode: CaptureMode

    /// Location ID to assign to created items
    let locationID: UUID?

    /// Home ID to assign to created items (resolved from location or active home)
    var homeID: UUID?

    /// Database writer for sqlite-data operations
    @Dependency(\.defaultDatabase) var database

    /// Shared AI analysis service for this flow instance
    private let sharedAIAnalysisService: AIAnalysisServiceProtocol

    /// Settings manager for OpenAI configuration
    var settingsManager: SettingsManager?

    /// Current step in the creation flow
    @Published var currentStep: ItemCreationStep = .camera

    /// Navigation flow based on capture mode and detected items
    var navigationFlow: [ItemCreationStep] {
        var flow = ItemCreationStep.getNavigationFlow(for: captureMode)

        // If in single-item mode but AI detected only one item, route through multi-item selection
        // for consistency and to allow user review
        if captureMode == .singleItem,
            let response = multiItemAnalysisResponse,
            response.safeItems.count == 1,
            !flow.contains(.multiItemSelection)
        {
            // Insert multiItemSelection before details
            if let detailsIndex = flow.firstIndex(of: .details) {
                flow.insert(.multiItemSelection, at: detailsIndex)
            }
        }

        return flow
    }

    /// Current step index in the navigation flow
    var currentStepIndex: Int {
        navigationFlow.firstIndex(of: currentStep) ?? 0
    }

    /// Captured images from camera
    @Published var capturedImages: [UIImage] = []

    /// Selected video asset for video analysis
    var videoAsset: AVAsset?

    /// Selected video URL (saved to Documents)
    var videoURL: URL?

    /// Video processing progress updates
    @Published var videoProcessingProgress: VideoAnalysisProgress?

    /// True while video batches are still being analyzed and merged.
    @Published var isVideoAnalysisStreaming: Bool = false

    /// Number of analyzed batches with results merged into the current streamed response.
    @Published var streamedBatchCount: Int = 0

    /// Total number of batches expected for the current video.
    @Published var totalBatchCount: Int = 0

    /// Whether image processing is in progress
    @Published var processingImage: Bool = false

    /// Whether analysis is complete
    @Published var analysisComplete: Bool = false

    /// Error message if analysis fails
    @Published var errorMessage: String?

    /// Multi-item analysis response (for multi-item mode)
    @Published var multiItemAnalysisResponse: MultiItemAnalysisResponse?

    /// Selected items from multi-item analysis
    @Published var selectedMultiItems: [DetectedInventoryItem] = []

    /// Created inventory items (saved to SQLite)
    @Published var createdItems: [SQLiteInventoryItem] = []

    /// Unique transition ID for animations
    @Published var transitionId = UUID()

    /// Whether the app is currently in background
    var isAppInBackground: Bool = false

    /// Whether we should navigate to multi-item selection on foreground
    var pendingNotificationNavigation: Bool = false

    private var hasScheduledAnalysisNotification: Bool = false
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var analysisInterruptedForBackground: Bool = false
    private var shouldRestartAnalysisOnForeground: Bool = false
    private var activeAIService: AIAnalysisServiceProtocol?
    private let videoAnalysisCoordinator: VideoAnalysisCoordinatorProtocol

    // MARK: - Computed Properties

    /// Whether user can go to the next step
    var canGoToNextStep: Bool {
        guard currentStepIndex < navigationFlow.count - 1 else { return false }
        return isReadyForNextStep
    }

    /// Whether user can go to the previous step
    var canGoToPreviousStep: Bool {
        return currentStepIndex > 0
    }

    /// Whether the current step is ready to proceed to next step
    var isReadyForNextStep: Bool {
        switch currentStep {
        case .camera:
            return !capturedImages.isEmpty

        case .videoProcessing:
            return multiItemAnalysisResponse != nil

        case .analyzing:
            if captureMode == .multiItem {
                return analysisComplete && multiItemAnalysisResponse != nil
            } else {
                return analysisComplete && !createdItems.isEmpty
            }

        case .multiItemSelection:
            // For multi-item selection, items are created and passed via handleMultiItemSelection
            // So we check if items have been created, not if they've been "selected" in the DetectedItem sense
            return !createdItems.isEmpty

        case .details:
            return false  // Final step
        }
    }

    /// Progress percentage through the flow
    var progressPercentage: Double {
        Double(currentStepIndex) / Double(navigationFlow.count - 1)
    }

    var videoStreamingStatusText: String? {
        guard isVideoAnalysisStreaming else { return nil }
        if totalBatchCount > 0, streamedBatchCount > 0 {
            return "Analyzing more frames (\(streamedBatchCount)/\(totalBatchCount))..."
        }
        return "Analyzing more frames..."
    }

    // MARK: - Initialization

    init(
        captureMode: CaptureMode,
        locationID: UUID?,
        homeID: UUID? = nil,
        aiAnalysisService: AIAnalysisServiceProtocol? = nil,
        videoAnalysisCoordinator: VideoAnalysisCoordinatorProtocol = VideoAnalysisCoordinator()
    ) {
        self.captureMode = captureMode
        self.locationID = locationID
        self.homeID = homeID
        self.sharedAIAnalysisService = aiAnalysisService ?? AIAnalysisServiceFactory.create()
        self.videoAnalysisCoordinator = videoAnalysisCoordinator
    }

    /// Update the settings manager (called after view initialization)
    func updateSettingsManager(_ settings: SettingsManager) {
        self.settingsManager = settings
    }

    /// Update the capture mode (called when user switches modes in camera)
    func updateCaptureMode(_ mode: CaptureMode) {
        print("🔄 ItemCreationFlowViewModel - Updating capture mode from \(captureMode) to \(mode)")
        self.captureMode = mode
        print("✅ ItemCreationFlowViewModel - Capture mode updated. Current mode: \(captureMode)")
        print("📋 ItemCreationFlowViewModel - Navigation flow: \(navigationFlow.map { $0.displayName })")
    }

    /// Create AI Analysis service with mock support for UI testing
    private func createAIAnalysisService() -> AIAnalysisServiceProtocol {
        return sharedAIAnalysisService
    }

    /// Expose the flow-scoped AI service for child selection views.
    var selectionAIAnalysisService: AIAnalysisServiceProtocol {
        sharedAIAnalysisService
    }

    // MARK: - Navigation Methods

    /// Move to the next step in the flow
    func goToNextStep() {
        guard canGoToNextStep else { return }

        let nextIndex = currentStepIndex + 1
        let nextStep = navigationFlow[nextIndex]

        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = nextStep
            transitionId = UUID()
        }
    }

    /// Move to the previous step in the flow
    func goToPreviousStep() {
        guard canGoToPreviousStep else { return }

        let previousIndex = currentStepIndex - 1
        let previousStep = navigationFlow[previousIndex]

        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = previousStep
            transitionId = UUID()
        }
    }

    /// Jump directly to a specific step
    func goToStep(_ step: ItemCreationStep) {
        guard navigationFlow.contains(step) else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
            transitionId = UUID()
        }
    }

    // MARK: - Home Assignment

    /// Resolves the homeID for a new item: uses location's home, then active home, then primary home.
    private func resolveHomeID() async -> UUID? {
        // If homeID is already set (e.g., from the calling view), use it
        if let homeID { return homeID }

        // If location has a home, use it
        if let locationID {
            if let location = try? await database.read({ db in
                try SQLiteInventoryLocation.find(locationID).fetchOne(db)
            }), let locationHomeID = location.homeID {
                return locationHomeID
            }
        }

        // Try active home from settings
        if let activeHomeIdString = settingsManager?.activeHomeId,
            let activeHomeId = UUID(uuidString: activeHomeIdString)
        {
            if (try? await database.read({ db in
                try SQLiteHome.find(activeHomeId).fetchOne(db)
            })) != nil {
                return activeHomeId
            }
        }

        // Fallback to primary home
        if let primaryHome = try? await database.read({ db in
            try SQLiteHome.where { $0.isPrimary == true }.fetchOne(db)
        }) {
            return primaryHome.id
        }

        return nil
    }

    // MARK: - Image Processing

    /// Handle captured images from camera
    func handleCapturedImages(_ images: [UIImage]) async {
        await MainActor.run {
            capturedImages = images
        }

        print("📸 ItemCreationFlowViewModel - handleCapturedImages called. Capture mode: \(captureMode)")

        // For single item mode, create the inventory item immediately
        if captureMode == .singleItem {
            print("➡️ ItemCreationFlowViewModel - Running single item creation flow")
            do {
                let newItem = try await createSingleInventoryItem()
                await MainActor.run {
                    if let item = newItem {
                        createdItems = [item]
                    }
                }
            } catch {
                print("❌ ItemCreationFlowViewModel: Analysis error: \(error)")
                if let aiError = error as? AIAnalysisError {
                    print("   AI Analysis Error Details: \(aiError)")
                }
                await MainActor.run {
                    let detailedError =
                        "Analysis failed: \(error.localizedDescription)\n\nError type: \(type(of: error))"
                    errorMessage = detailedError
                    processingImage = false
                }
            }
        }
    }

    /// Handle selected video from picker
    func handleSelectedVideo(_ url: URL) async {
        resetAnalysisState()
        updateCaptureMode(.video)
        do {
            let savedURL = try await OptimizedImageManager.shared.saveVideo(url)
            startVideoProcessingFlow(with: savedURL)
        } catch {
            errorMessage = "Failed to save video: \(error.localizedDescription)"
        }
    }

    /// Start video analysis flow for an already-saved local video URL.
    func handleSavedVideo(_ url: URL) {
        resetAnalysisState()
        updateCaptureMode(.video)
        startVideoProcessingFlow(with: url)
    }

    private func startVideoProcessingFlow(with savedURL: URL) {
        videoURL = savedURL
        videoAsset = AVAsset(url: savedURL)
        capturedImages = []
        goToStep(.videoProcessing)
    }

    /// Create a single inventory item (for single item mode)
    func createSingleInventoryItem() async throws -> SQLiteInventoryItem? {
        guard !capturedImages.isEmpty else {
            throw InventoryItemCreationError.noImagesProvided
        }

        let newID = UUID()
        let itemId = newID.uuidString
        let resolvedHomeID = await resolveHomeID()

        var newItem = SQLiteInventoryItem(
            id: newID,
            assetId: itemId,
            locationID: locationID,
            homeID: resolvedHomeID
        )

        do {
            // Process images to JPEG data before DB write
            var photoDataList: [(Data, Int)] = []
            for (sortOrder, image) in capturedImages.enumerated() {
                if let imageData = await OptimizedImageManager.shared.processImage(image) {
                    photoDataList.append((imageData, sortOrder))
                }
            }

            // Insert into SQLite
            let itemToInsert = newItem
            try await database.write { db in
                try SQLiteInventoryItem.insert { itemToInsert }.execute(db)

                for (imageData, sortOrder) in photoDataList {
                    try SQLiteInventoryItemPhoto.insert {
                        SQLiteInventoryItemPhoto(
                            id: UUID(),
                            inventoryItemID: newItem.id,
                            data: imageData,
                            sortOrder: sortOrder
                        )
                    }.execute(db)
                }
            }

            TelemetryManager.shared.trackInventoryItemAdded(name: newItem.title)
            return newItem

        } catch {
            throw InventoryItemCreationError.imageProcessingFailed
        }
    }

    // MARK: - Analysis Methods

    /// Perform image analysis (single item mode)
    func performAnalysis() async {
        guard var item = createdItems.first else { return }

        await MainActor.run {
            analysisComplete = false
            errorMessage = nil
            processingImage = true
        }

        analysisInterruptedForBackground = false
        beginBackgroundTaskIfNeeded()
        defer {
            endBackgroundTaskIfNeeded()
            activeAIService = nil
        }

        do {
            guard let settings = settingsManager else {
                await MainActor.run {
                    errorMessage = "Settings manager not available"
                    processingImage = false
                }
                return
            }

            let aiService = sharedAIAnalysisService
            activeAIService = aiService
            print("🔍 ItemCreationFlowViewModel: Using AI Analysis service: \(type(of: aiService))")

            // Build AIAnalysisContext from database
            let context = await AIAnalysisContext.from(database: database, settings: settings)

            let imageDetails = try await aiService.getImageDetails(
                from: capturedImages,
                settings: settings,
                context: context
            )

            // Load labels and locations from SQLite
            let labels =
                (try? await database.read { db in
                    try SQLiteInventoryLabel.all.fetchAll(db)
                }) ?? []
            let locations =
                (try? await database.read { db in
                    try SQLiteInventoryLocation.all.fetchAll(db)
                }) ?? []

            // Update item from AI results
            updateItemFromImageDetails(&item, imageDetails: imageDetails, labels: labels, locations: locations)

            // Save updated item to SQLite
            let updatedItem = item
            do {
                try await database.write { db in
                    try SQLiteInventoryItem.find(updatedItem.id).update {
                        $0.title = updatedItem.title
                        $0.quantityString = updatedItem.quantityString
                        $0.quantityInt = updatedItem.quantityInt
                        $0.desc = updatedItem.desc
                        $0.serial = updatedItem.serial
                        $0.model = updatedItem.model
                        $0.make = updatedItem.make
                        $0.price = updatedItem.price
                        $0.condition = updatedItem.condition
                        $0.color = updatedItem.color
                        $0.purchaseLocation = updatedItem.purchaseLocation
                        $0.replacementCost = updatedItem.replacementCost
                        $0.depreciationRate = updatedItem.depreciationRate
                        $0.storageRequirements = updatedItem.storageRequirements
                        $0.isFragile = updatedItem.isFragile
                        $0.dimensionLength = updatedItem.dimensionLength
                        $0.dimensionWidth = updatedItem.dimensionWidth
                        $0.dimensionHeight = updatedItem.dimensionHeight
                        $0.dimensionUnit = updatedItem.dimensionUnit
                        $0.weightValue = updatedItem.weightValue
                        $0.weightUnit = updatedItem.weightUnit
                        $0.hasUsedAI = updatedItem.hasUsedAI
                        $0.locationID = updatedItem.locationID
                    }.execute(db)

                    // Save matched labels
                    let categoriesToMatch =
                        imageDetails.categories.isEmpty
                        ? [imageDetails.category] : imageDetails.categories
                    for categoryName in categoriesToMatch {
                        if let matchedLabel = labels.first(where: {
                            $0.name.lowercased() == categoryName.lowercased()
                        }) {
                            try SQLiteInventoryItemLabel.insert {
                                SQLiteInventoryItemLabel(
                                    id: UUID(),
                                    inventoryItemID: updatedItem.id,
                                    inventoryLabelID: matchedLabel.id
                                )
                            }.execute(db)
                        }
                    }
                }
            } catch {
                print("Error saving analysis results: \(error)")
            }

            await MainActor.run {
                createdItems = [item]

                let detectedItem = DetectedInventoryItem(
                    id: UUID().uuidString,
                    title: imageDetails.title,
                    description: imageDetails.description,
                    category: imageDetails.category,
                    make: imageDetails.make,
                    model: imageDetails.model,
                    estimatedPrice: imageDetails.price,
                    confidence: 0.95
                )

                multiItemAnalysisResponse = MultiItemAnalysisResponse(
                    items: [detectedItem],
                    detectedCount: 1,
                    analysisType: "single_item_as_multi",
                    confidence: 0.95
                )

                analysisComplete = true
                processingImage = false
                analysisInterruptedForBackground = false
                shouldRestartAnalysisOnForeground = false
            }

        } catch {
            let isCancellation = error is CancellationError
            let isBackgrounded =
                isAppInBackground || UIApplication.shared.applicationState == .background
            if analysisInterruptedForBackground || isCancellation || isBackgrounded {
                await MainActor.run {
                    if analysisInterruptedForBackground || isBackgrounded {
                        shouldRestartAnalysisOnForeground = true
                    }
                    processingImage = false
                }
                return
            }
            print("❌ ItemCreationFlowViewModel (Single): Analysis error: \(error)")
            if let aiError = error as? AIAnalysisError {
                print("   AI Analysis Error Details: \(aiError)")
            }
            await MainActor.run {
                let detailedError =
                    "Analysis failed: \(error.localizedDescription)\n\nError type: \(type(of: error))"
                errorMessage = detailedError
                processingImage = false
            }
        }
    }

    /// Perform multi-item analysis
    func performMultiItemAnalysis() async {
        await MainActor.run {
            analysisComplete = false
            errorMessage = nil
            processingImage = true
        }

        analysisInterruptedForBackground = false
        beginBackgroundTaskIfNeeded()
        defer {
            endBackgroundTaskIfNeeded()
            activeAIService = nil
        }

        do {
            guard let settings = settingsManager else {
                await MainActor.run {
                    errorMessage = "Settings manager not available"
                    processingImage = false
                }
                return
            }

            // Force high quality for multi-item analysis
            let originalHighDetail = settings.isHighDetail
            settings.isHighDetail = true

            let aiService = sharedAIAnalysisService
            activeAIService = aiService
            print("🔍 ItemCreationFlowViewModel (Multi-Item): Using AI Analysis service: \(type(of: aiService))")

            // Build AIAnalysisContext from database
            let context = await AIAnalysisContext.from(database: database, settings: settings)

            let response = try await aiService.getMultiItemDetails(
                from: capturedImages,
                settings: settings,
                context: context,
                narrationContext: nil
            )

            // Restore original setting
            await MainActor.run {
                settings.isHighDetail = originalHighDetail
            }

            await MainActor.run {
                multiItemAnalysisResponse = response
                analysisComplete = true
                processingImage = false
                analysisInterruptedForBackground = false
                shouldRestartAnalysisOnForeground = false
                handleMultiItemAnalysisReady()
            }

        } catch {
            let isCancellation = error is CancellationError
            let isBackgrounded =
                isAppInBackground || UIApplication.shared.applicationState == .background
            if analysisInterruptedForBackground || isCancellation || isBackgrounded {
                await MainActor.run {
                    if analysisInterruptedForBackground || isBackgrounded {
                        shouldRestartAnalysisOnForeground = true
                    }
                    processingImage = false
                }
                return
            }
            print("❌ ItemCreationFlowViewModel (Multi-Item): Analysis error: \(error)")
            if let aiError = error as? AIAnalysisError {
                print("   AI Analysis Error Details: \(aiError)")
            }
            await MainActor.run {
                let detailedError =
                    "Multi-item analysis failed: \(error.localizedDescription)\n\nError type: \(type(of: error))"
                errorMessage = detailedError
                processingImage = false
            }
        }
    }

    /// Perform video processing: frame extraction, transcription, AI analysis, and deduplication
    func performVideoProcessing() async {
        guard let asset = videoAsset else { return }
        guard let settings = settingsManager else {
            errorMessage = "Settings manager not available"
            return
        }

        processingImage = true
        videoProcessingProgress = VideoAnalysisProgress(phase: .extractingFrames, progress: 0.0, overallProgress: 0.0)
        isVideoAnalysisStreaming = true
        streamedBatchCount = 0
        totalBatchCount = 0

        let aiService = sharedAIAnalysisService
        activeAIService = aiService
        defer {
            activeAIService = nil
        }

        do {
            let response = try await videoAnalysisCoordinator.analyze(
                videoAsset: asset,
                settings: settings,
                database: database,
                aiService: aiService,
                onProgress: { [weak self] progress in
                    guard let self else { return }
                    Task { @MainActor in
                        self.videoProcessingProgress = progress
                        if self.capturedImages.isEmpty,
                            let coordinator = self.videoAnalysisCoordinator as? VideoAnalysisCoordinator,
                            !coordinator.extractedFrames.isEmpty
                        {
                            self.capturedImages = coordinator.extractedFrames.map { $0.image }
                        }

                        if let coordinator = self.videoAnalysisCoordinator as? VideoAnalysisCoordinator {
                            self.totalBatchCount = coordinator.totalBatchCount
                            self.streamedBatchCount = coordinator.completedBatchCount

                            if let streamedResponse = coordinator.progressiveMergedResponse {
                                self.multiItemAnalysisResponse = streamedResponse
                                if self.currentStep == .videoProcessing, !streamedResponse.safeItems.isEmpty {
                                    self.goToStep(.multiItemSelection)
                                }
                            }
                        }
                    }
                }
            )

            if let coordinator = videoAnalysisCoordinator as? VideoAnalysisCoordinator {
                capturedImages = coordinator.extractedFrames.map { $0.image }
            }

            multiItemAnalysisResponse = response
            processingImage = false
            analysisComplete = true
            isVideoAnalysisStreaming = false
            if currentStep == .videoProcessing {
                goToStep(.multiItemSelection)
            }
        } catch let error as VideoExtractionError {
            processingImage = false
            isVideoAnalysisStreaming = false
            switch error {
            case .videoTooLong(let duration):
                errorMessage = "Video is too long (\(Int(duration)) seconds). Please select a video under 3 minutes."
            case .noVideoTrack:
                errorMessage = "No video track found. Please select a valid video."
            case .cancelled:
                errorMessage = "Video processing was cancelled."
            case .extractionFailed:
                errorMessage = "Failed to extract frames from the video."
            }
        } catch {
            processingImage = false
            isVideoAnalysisStreaming = false
            errorMessage = "Video processing failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Multi-Item Processing

    /// Process selected multi-items and create inventory items
    func processSelectedMultiItems() async throws -> [SQLiteInventoryItem] {
        guard !selectedMultiItems.isEmpty else { return [] }
        guard !capturedImages.isEmpty else {
            throw InventoryItemCreationError.noImagesProvided
        }

        let resolvedHomeID = await resolveHomeID()
        let existingLabels =
            (try? await database.read { db in
                try SQLiteInventoryLabel.all.fetchAll(db)
            }) ?? []

        var items: [SQLiteInventoryItem] = []
        var photoDataByItem: [UUID: [(Data, Int)]] = [:]

        for detectedItem in selectedMultiItems {
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
                notes:
                    "AI-detected \(detectedItem.category) with \(Int(detectedItem.confidence * 100))% confidence",
                hasUsedAI: true,
                locationID: locationID,
                homeID: resolvedHomeID
            )

            do {
                items.append(inventoryItem)

                // Process primary image for this item
                if let primaryImage = capturedImages.first,
                    let imageData = await OptimizedImageManager.shared.processImage(primaryImage)
                {
                    photoDataByItem[inventoryItem.id] = [(imageData, 0)]
                }
            } catch {
                throw InventoryItemCreationError.imageProcessingFailed
            }
        }

        // Batch insert all items into SQLite
        do {
            try await database.write { [selectedMultiItems] db in
                for (index, item) in items.enumerated() {
                    try SQLiteInventoryItem.insert { item }.execute(db)

                    // Insert photo BLOBs
                    if let photoEntries = photoDataByItem[item.id] {
                        for (imageData, sortOrder) in photoEntries {
                            try SQLiteInventoryItemPhoto.insert {
                                SQLiteInventoryItemPhoto(
                                    id: UUID(),
                                    inventoryItemID: item.id,
                                    data: imageData,
                                    sortOrder: sortOrder
                                )
                            }.execute(db)
                        }
                    }

                    // Match label for this item's category
                    let detectedCategory = selectedMultiItems[index].category
                    if let existingLabel = existingLabels.first(where: {
                        $0.name.lowercased() == detectedCategory.lowercased()
                    }) {
                        try SQLiteInventoryItemLabel.insert {
                            SQLiteInventoryItemLabel(
                                id: UUID(),
                                inventoryItemID: item.id,
                                inventoryLabelID: existingLabel.id
                            )
                        }.execute(db)
                    }

                    TelemetryManager.shared.trackInventoryItemAdded(name: item.title)
                }
            }
        } catch {
            throw InventoryItemCreationError.contextSaveFailure
        }

        await MainActor.run {
            createdItems = items
        }

        return items
    }

    // MARK: - State Management

    /// Reset the view model state
    func resetState() {
        currentStep = .camera
        capturedImages = []
        videoAsset = nil
        videoURL = nil
        videoProcessingProgress = nil
        isVideoAnalysisStreaming = false
        streamedBatchCount = 0
        totalBatchCount = 0
        processingImage = false
        analysisComplete = false
        errorMessage = nil
        multiItemAnalysisResponse = nil
        selectedMultiItems = []
        createdItems = []
        transitionId = UUID()
        pendingNotificationNavigation = false
        hasScheduledAnalysisNotification = false
        analysisInterruptedForBackground = false
        shouldRestartAnalysisOnForeground = false
        activeAIService = nil
        endBackgroundTaskIfNeeded()
    }

    /// Reset only the analysis state (for re-analyzing)
    func resetAnalysisState() {
        analysisComplete = false
        errorMessage = nil
        multiItemAnalysisResponse = nil
        videoProcessingProgress = nil
        isVideoAnalysisStreaming = false
        streamedBatchCount = 0
        totalBatchCount = 0
        processingImage = false
        transitionId = UUID()
        pendingNotificationNavigation = false
        hasScheduledAnalysisNotification = false
        analysisInterruptedForBackground = false
        shouldRestartAnalysisOnForeground = false
        activeAIService = nil
        endBackgroundTaskIfNeeded()
    }

    /// Handle multi-item selection completion
    func handleMultiItemSelection(_ items: [SQLiteInventoryItem]) {
        createdItems = items
        goToNextStep()  // Move to details step
    }

    // MARK: - Background Notification Handling

    func updateScenePhase(_ phase: ScenePhase) {
        isAppInBackground = phase == .background

        if phase == .background {
            if processingImage {
                beginBackgroundTaskIfNeeded()
            }
            return
        }

        if phase == .active {
            if pendingNotificationNavigation {
                navigateToMultiItemSelectionIfReady()
                pendingNotificationNavigation = false
            }
            if shouldRestartAnalysisOnForeground,
                currentStep == .analyzing,
                !processingImage,
                !analysisComplete
            {
                shouldRestartAnalysisOnForeground = false
                analysisInterruptedForBackground = false
                Task {
                    if captureMode == .video {
                        return
                    } else if captureMode == .multiItem {
                        await performMultiItemAnalysis()
                    } else {
                        await performAnalysis()
                    }
                }
            }
        }
    }

    func handleAnalysisNotificationTapped() {
        pendingNotificationNavigation = true
        navigateToMultiItemSelectionIfReady()
    }

    private func handleMultiItemAnalysisReady() {
        guard captureMode == .multiItem else { return }
        guard multiItemAnalysisResponse != nil else { return }

        let isBackgrounded = isAppInBackground || UIApplication.shared.applicationState == .background
        if isBackgrounded {
            pendingNotificationNavigation = true
            scheduleAnalysisReadyNotificationIfNeeded()
        }
    }

    private func navigateToMultiItemSelectionIfReady() {
        guard captureMode == .multiItem else { return }
        guard multiItemAnalysisResponse != nil else { return }
        guard currentStep != .multiItemSelection else { return }

        goToStep(.multiItemSelection)
    }

    private func scheduleAnalysisReadyNotificationIfNeeded() {
        guard !hasScheduledAnalysisNotification else { return }
        hasScheduledAnalysisNotification = true

        let itemCount = multiItemAnalysisResponse?.safeItems.count ?? 0
        Task {
            await scheduleAnalysisReadyNotification(itemCount: itemCount)
        }
    }

    private func scheduleAnalysisReadyNotification(itemCount: Int) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let status = settings.authorizationStatus
        guard status == .authorized || status == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Item analysis ready"
        content.body =
            itemCount == 1
            ? "Tap to review the detected item."
            : "Tap to review \(itemCount) detected items."
        content.sound = .default
        content.userInfo = ["destination": "multiItemSelection"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: AnalysisNotificationConstants.multiItemAnalysisReadyIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("❌ Failed to schedule analysis notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Background Task Handling

    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskId == .invalid else { return }
        guard isAppInBackground || UIApplication.shared.applicationState == .background else { return }

        analysisInterruptedForBackground = false

        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "ItemAnalysis") { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.analysisInterruptedForBackground = true
                self.shouldRestartAnalysisOnForeground = true
                self.activeAIService?.cancelCurrentRequest()
                self.endBackgroundTaskIfNeeded()
            }
        }
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
    }

    // MARK: - Helper Methods

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

    /// Assign appropriate color for category labels
    private func assignColorForCategory(_ category: String) -> String {
        // Predefined color mapping for common categories
        let categoryColors: [String: String] = [
            "electronics": "#007AFF",  // Blue
            "furniture": "#8E4EC6",  // Purple
            "clothing": "#FF69B4",  // Pink
            "kitchen": "#FF9500",  // Orange
            "books": "#34C759",  // Green
            "tools": "#FF3B30",  // Red
            "toys": "#FFCC02",  // Yellow
            "jewelry": "#AF52DE",  // Violet
            "sports": "#32D74B",  // Light Green
            "automotive": "#64D2FF",  // Light Blue
            "appliances": "#BF5AF2",  // Light Purple
            "art": "#FF6482",  // Light Red
        ]

        // Return predefined color or generate based on category hash
        let lowercaseCategory = category.lowercased()
        if let predefinedColor = categoryColors[lowercaseCategory] {
            return predefinedColor
        }

        // Generate consistent color based on category string hash
        let colors = ["#007AFF", "#8E4EC6", "#FF9500", "#34C759", "#FF3B30", "#FFCC02"]
        let colorIndex = abs(category.hashValue) % colors.count
        return colors[colorIndex]
    }

    /// Get current step title for UI
    var currentStepTitle: String {
        currentStep.displayName
    }

    /// Whether the current step allows going back
    var allowsBackNavigation: Bool {
        switch currentStep {
        case .camera:
            return true
        case .videoProcessing:
            return !processingImage
        case .analyzing:
            return !processingImage
        case .multiItemSelection:
            return true
        case .details:
            // Don't allow back navigation from details in multi-item mode (success state)
            return captureMode == .singleItem
        }
    }

    // MARK: - AI Update Helper

    private func updateItemFromImageDetails(
        _ item: inout SQLiteInventoryItem,
        imageDetails: ImageDetails,
        labels: [SQLiteInventoryLabel],
        locations: [SQLiteInventoryLocation]
    ) {
        item.title = imageDetails.title
        item.quantityString = imageDetails.quantity
        if let quantity = Int(imageDetails.quantity) {
            item.quantityInt = quantity
        }
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        item.serial = imageDetails.serialNumber

        let priceString = imageDetails.price
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespaces)
        if let price = Decimal(string: priceString) {
            item.price = price
        }

        // Location handling - NEVER overwrite existing location
        if item.locationID == nil {
            if let matchedLocation = locations.first(where: { $0.name == imageDetails.location }) {
                item.locationID = matchedLocation.id
            }
        }

        if let condition = imageDetails.condition, !condition.isEmpty {
            item.condition = condition
        }
        if let color = imageDetails.color, !color.isEmpty {
            item.color = color
        }
        if let purchaseLocation = imageDetails.purchaseLocation, !purchaseLocation.isEmpty {
            item.purchaseLocation = purchaseLocation
        }
        if let replacementCostString = imageDetails.replacementCost, !replacementCostString.isEmpty {
            let cleaned =
                replacementCostString
                .replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
            if let val = Decimal(string: cleaned) { item.replacementCost = val }
        }
        if let depreciationRateString = imageDetails.depreciationRate, !depreciationRateString.isEmpty {
            let cleaned =
                depreciationRateString
                .replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            if let val = Double(cleaned) { item.depreciationRate = val / 100.0 }
        }
        if let storageRequirements = imageDetails.storageRequirements, !storageRequirements.isEmpty {
            item.storageRequirements = storageRequirements
        }
        if let isFragileString = imageDetails.isFragile, !isFragileString.isEmpty {
            item.isFragile = isFragileString.lowercased() == "true"
        }
        if let dimensionLength = imageDetails.dimensionLength, !dimensionLength.isEmpty {
            item.dimensionLength = dimensionLength
        }
        if let dimensionWidth = imageDetails.dimensionWidth, !dimensionWidth.isEmpty {
            item.dimensionWidth = dimensionWidth
        }
        if let dimensionHeight = imageDetails.dimensionHeight, !dimensionHeight.isEmpty {
            item.dimensionHeight = dimensionHeight
        }
        if let dimensionUnit = imageDetails.dimensionUnit, !dimensionUnit.isEmpty {
            item.dimensionUnit = dimensionUnit
        }
        if let weightValue = imageDetails.weightValue, !weightValue.isEmpty {
            item.weightValue = weightValue
            item.weightUnit = imageDetails.weightUnit ?? "lbs"
        }

        item.hasUsedAI = true
    }
}
