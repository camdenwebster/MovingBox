//
//  ItemCreationFlowViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import AVFoundation
import Foundation
import MovingBoxAIAnalysis
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

@MainActor
@Observable
class ItemCreationFlowViewModel {

    // MARK: - Properties

    /// The capture mode (single item or multi-item)
    /// Can be updated if user switches modes during camera capture
    var captureMode: CaptureMode

    /// Location to assign to created items
    let location: InventoryLocation?

    /// SwiftData context for saving items
    var modelContext: ModelContext?

    /// Shared AI analysis service for this flow instance.
    /// Initialized once to avoid repeated service creation during SwiftUI view updates.
    @ObservationIgnored
    private let sharedAIAnalysisService: AIAnalysisServiceProtocol

    /// Settings manager for AI configuration
    var settingsManager: SettingsManager?

    /// Current step in the creation flow
    var currentStep: ItemCreationStep = .camera

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
    var capturedImages: [UIImage] = []

    /// Selected video asset for video analysis
    var videoAsset: AVAsset?

    /// Selected video URL (saved to Documents)
    var videoURL: URL?

    /// Video processing progress updates
    var videoProcessingProgress: VideoAnalysisProgress?

    /// True while video batches are still being analyzed and merged.
    var isVideoAnalysisStreaming: Bool = false

    /// Number of analyzed batches with results merged into the current streamed response.
    var streamedBatchCount: Int = 0

    /// Total number of batches expected for the current video.
    var totalBatchCount: Int = 0

    /// Whether image processing is in progress
    var processingImage: Bool = false

    /// Whether analysis is complete
    var analysisComplete: Bool = false

    /// Error message if analysis fails
    var errorMessage: String?

    /// Multi-item analysis response (for multi-item mode)
    var multiItemAnalysisResponse: MultiItemAnalysisResponse?

    /// Selected items from multi-item analysis
    var selectedMultiItems: [DetectedInventoryItem] = []

    /// Created inventory items
    var createdItems: [InventoryItem] = []

    /// Unique transition ID for animations
    var transitionId = UUID()

    /// Whether the app is currently in background
    var isAppInBackground: Bool = false

    /// Whether we should navigate to multi-item selection on foreground
    var pendingNotificationNavigation: Bool = false

    private var hasScheduledAnalysisNotification: Bool = false
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var analysisInterruptedForBackground: Bool = false
    private var shouldRestartAnalysisOnForeground: Bool = false
    @ObservationIgnored
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
        location: InventoryLocation?,
        modelContext: ModelContext? = nil,
        aiAnalysisService: AIAnalysisServiceProtocol? = nil,
        videoAnalysisCoordinator: VideoAnalysisCoordinatorProtocol = VideoAnalysisCoordinator()
    ) {
        self.captureMode = captureMode
        self.location = location
        self.modelContext = modelContext
        self.sharedAIAnalysisService = aiAnalysisService ?? AIAnalysisServiceFactory.create()
        self.videoAnalysisCoordinator = videoAnalysisCoordinator
    }

    /// Update the model context (called after view initialization)
    func updateModelContext(_ context: ModelContext) {
        self.modelContext = context
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

    /// Assigns the appropriate home to an item if it doesn't already have one through its location.
    /// Uses active home from settings, with fallback to primary home.
    /// - Parameters:
    ///   - item: The item to assign a home to
    ///   - context: The model context for fetching homes
    private func assignHomeToItemIfNeeded(_ item: InventoryItem, context: ModelContext) {
        // Skip if item already has an effective home through its location
        guard item.location == nil || item.location?.home == nil else {
            return
        }

        // Try active home from settings first
        if let activeHomeIdString = settingsManager?.activeHomeId,
            let activeHomeId = UUID(uuidString: activeHomeIdString)
        {
            let homeDescriptor = FetchDescriptor<Home>(predicate: #Predicate<Home> { $0.id == activeHomeId })
            if let activeHome = try? context.fetch(homeDescriptor).first {
                item.home = activeHome
                return
            }
        }

        // Fallback to primary home
        let primaryHomeDescriptor = FetchDescriptor<Home>(predicate: #Predicate { $0.isPrimary })
        if let primaryHome = try? context.fetch(primaryHomeDescriptor).first {
            item.home = primaryHome
            return
        }

        // Log warning if no home could be assigned
        print(
            "⚠️ ItemCreationFlowViewModel - Could not assign home to item '\(item.title)'. No active or primary home found."
        )
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
                if let aiAnalysisError = error as? AIAnalysisError {
                    print("   AI Analysis Error Details: \(aiAnalysisError)")
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

    /// Perform video processing: frame extraction, transcription, AI analysis, and deduplication
    func performVideoProcessing() async {
        guard let asset = videoAsset else { return }
        guard let context = modelContext else {
            errorMessage = "Model context not available"
            return
        }
        guard let settings = settingsManager else {
            errorMessage = "Settings manager not available"
            return
        }

        processingImage = true
        videoProcessingProgress = VideoAnalysisProgress(phase: .extractingFrames, progress: 0.0, overallProgress: 0.0)
        isVideoAnalysisStreaming = true
        streamedBatchCount = 0
        totalBatchCount = 0

        do {
            let response = try await videoAnalysisCoordinator.analyze(
                videoAsset: asset,
                settings: settings,
                modelContext: context,
                aiService: sharedAIAnalysisService,
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

    /// Create a single inventory item (for single item mode)
    func createSingleInventoryItem() async throws -> InventoryItem? {
        guard !capturedImages.isEmpty else {
            throw InventoryItemCreationError.noImagesProvided
        }

        let newItem = InventoryItem(
            title: "",
            quantityString: "1",
            quantityInt: 1,
            desc: "",
            serial: "",
            model: "",
            make: "",
            location: location,
            labels: [],
            price: Decimal.zero,
            insured: false,
            assetId: "",
            notes: "",
            showInvalidQuantityAlert: false
        )

        // Generate unique ID for this item
        let itemId = UUID().uuidString

        do {
            if let primaryImage = capturedImages.first {
                // Save the primary image
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(
                    primaryImage, id: itemId)
                newItem.imageURL = primaryImageURL

                // Save secondary images if there are more than one
                if capturedImages.count > 1 {
                    let secondaryImages = Array(capturedImages.dropFirst())
                    let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(
                        secondaryImages, itemId: itemId)
                    newItem.secondaryPhotoURLs = secondaryURLs
                }
            }

            guard let context = modelContext else {
                throw InventoryItemCreationError.imageProcessingFailed
            }

            assignHomeToItemIfNeeded(newItem, context: context)
            context.insert(newItem)
            try context.save()
            TelemetryManager.shared.trackInventoryItemAdded(name: newItem.title)

            return newItem

        } catch {
            throw InventoryItemCreationError.imageProcessingFailed
        }
    }

    // MARK: - Analysis Methods

    /// Perform image analysis (single item mode)
    func performAnalysis() async {
        guard let item = createdItems.first else { return }

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
            guard let context = modelContext else {
                await MainActor.run {
                    errorMessage = "Model context not available"
                    processingImage = false
                }
                return
            }

            guard let settings = settingsManager else {
                await MainActor.run {
                    errorMessage = "Settings manager not available"
                    processingImage = false
                }
                return
            }

            let aiService = sharedAIAnalysisService
            activeAIService = aiService
            print("🔍 ItemCreationFlowViewModel: Using AI service: \(type(of: aiService))")
            let aiContext = AIAnalysisContext.from(modelContext: context, settings: settings)
            let imageDetails = try await aiService.getImageDetails(
                from: capturedImages,
                settings: settings,
                context: aiContext
            )

            try await MainActor.run {
                // Get all labels and locations for the unified update
                let labels = (try? context.fetch(FetchDescriptor<InventoryLabel>())) ?? []
                let locations = (try? context.fetch(FetchDescriptor<InventoryLocation>())) ?? []

                item.updateFromImageDetails(
                    imageDetails,
                    labels: labels,
                    locations: locations,
                    modelContext: context
                )
                try context.save()

                // For single-item mode, also create a MultiItemAnalysisResponse
                // This allows routing through multi-item selection view for consistency
                let detectedItem = DetectedInventoryItem(
                    id: UUID().uuidString,
                    title: imageDetails.title,
                    description: imageDetails.description,
                    category: imageDetails.category,
                    make: imageDetails.make,
                    model: imageDetails.model,
                    estimatedPrice: imageDetails.price,
                    confidence: 0.95  // Single item AI analysis is highly confident
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
            if let aiAnalysisError = error as? AIAnalysisError {
                print("   AI Analysis Error Details: \(aiAnalysisError)")
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
            guard let context = modelContext else {
                await MainActor.run {
                    errorMessage = "Model context not available"
                    processingImage = false
                }
                return
            }

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
            defer {
                settings.isHighDetail = originalHighDetail
            }

            let aiService = sharedAIAnalysisService
            activeAIService = aiService
            print("🔍 ItemCreationFlowViewModel (Multi-Item): Using AI service: \(type(of: aiService))")
            let response: MultiItemAnalysisResponse
            let batchSize = 5
            let multiContext = AIAnalysisContext.from(modelContext: context, settings: settings)
            if capturedImages.count > batchSize {
                response = try await performBatchedMultiItemAnalysis(
                    images: capturedImages,
                    batchSize: batchSize,
                    settings: settings,
                    context: multiContext,
                    aiService: aiService
                )
            } else {
                response = try await aiService.getMultiItemDetails(
                    from: capturedImages,
                    settings: settings,
                    context: multiContext,
                    narrationContext: nil
                )
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
            if let aiAnalysisError = error as? AIAnalysisError {
                print("   AI Analysis Error Details: \(aiAnalysisError)")
            }
            await MainActor.run {
                let detailedError =
                    "Multi-item analysis failed: \(error.localizedDescription)\n\nError type: \(type(of: error))"
                errorMessage = detailedError
                processingImage = false
            }
        }
    }

    private func performBatchedMultiItemAnalysis(
        images: [UIImage],
        batchSize: Int,
        settings: AIAnalysisSettings,
        context: AIAnalysisContext,
        aiService: AIAnalysisServiceProtocol
    ) async throws -> MultiItemAnalysisResponse {
        guard !images.isEmpty else {
            return MultiItemAnalysisResponse(items: [], detectedCount: 0, analysisType: "multi_item", confidence: 0.0)
        }

        let totalBatches = Int(ceil(Double(images.count) / Double(max(batchSize, 1))))
        var batchResults: [(response: MultiItemAnalysisResponse, batchOffset: Int)] = []
        batchResults.reserveCapacity(totalBatches)

        for batchIndex in 0..<totalBatches {
            let start = batchIndex * batchSize
            let end = min(start + batchSize, images.count)
            let batchImages = Array(images[start..<end])

            let response = try await aiService.getMultiItemDetails(
                from: batchImages,
                settings: settings,
                context: context,
                narrationContext: nil
            )

            batchResults.append((response: response, batchOffset: start))
        }

        return VideoItemDeduplicator.deduplicate(batchResults: batchResults)
    }

    // MARK: - Multi-Item Processing

    /// Process selected multi-items and create inventory items
    func processSelectedMultiItems() async throws -> [InventoryItem] {
        guard !selectedMultiItems.isEmpty else { return [] }
        guard !capturedImages.isEmpty else {
            throw InventoryItemCreationError.noImagesProvided
        }

        // Note: Primary image is saved per-item to ensure unique URLs
        // No pre-processing needed as OptimizedImageManager handles this efficiently

        var items: [InventoryItem] = []

        for detectedItem in selectedMultiItems {
            let inventoryItem = InventoryItem(
                title: detectedItem.title.isEmpty ? "Untitled Item" : detectedItem.title,
                quantityString: "1",
                quantityInt: 1,
                desc: detectedItem.description,
                serial: "",
                model: detectedItem.model,
                make: detectedItem.make,
                location: location,
                labels: [],
                price: parsePrice(from: detectedItem.estimatedPrice),
                insured: false,
                assetId: "",
                notes:
                    "AI-detected \(detectedItem.category) with \(Int(detectedItem.confidence * 100))% confidence",
                showInvalidQuantityAlert: false
            )

            // Generate unique ID for this item
            let itemId = UUID().uuidString

            do {
                // Save primary image
                if let primaryImage = capturedImages.first {
                    let primaryImageURL = try await OptimizedImageManager.shared.saveImage(
                        primaryImage, id: itemId)
                    inventoryItem.imageURL = primaryImageURL
                }

                items.append(inventoryItem)

            } catch {
                throw InventoryItemCreationError.imageProcessingFailed
            }
        }

        // Batch insert all items and save once for better performance
        guard let context = modelContext else {
            throw InventoryItemCreationError.imageProcessingFailed
        }

        // Auto-create labels based on AI categories and assign to items
        await MainActor.run {
            var existingLabels = (try? context.fetch(FetchDescriptor<InventoryLabel>())) ?? []

            for (index, item) in items.enumerated() {
                let detectedCategory = selectedMultiItems[index].category
                let matchedLabels = LabelAutoAssignment.labels(
                    for: [detectedCategory],
                    existingLabels: existingLabels,
                    modelContext: context
                )
                item.labels = matchedLabels

                for label in matchedLabels
                where !existingLabels.contains(where: { $0.id == label.id }) {
                    existingLabels.append(label)
                }
            }
        }

        // Insert all items in batch
        for item in items {
            assignHomeToItemIfNeeded(item, context: context)
            context.insert(item)
            // Track telemetry for each item
            TelemetryManager.shared.trackInventoryItemAdded(name: item.title)
        }

        // Single save operation for all items
        try context.save()

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
    func handleMultiItemSelection(_ items: [InventoryItem]) {
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
}
