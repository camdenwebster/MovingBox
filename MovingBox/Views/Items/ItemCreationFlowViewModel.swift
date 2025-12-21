//
//  ItemCreationFlowViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/19/25.
//

import SwiftUI
import SwiftData
import Foundation

@MainActor
class ItemCreationFlowViewModel: ObservableObject {
    
    // MARK: - Properties

    /// The capture mode (single item or multi-item)
    /// Can be updated if user switches modes during camera capture
    @Published var captureMode: CaptureMode
    
    /// Location to assign to created items
    let location: InventoryLocation?
    
    /// SwiftData context for saving items
    var modelContext: ModelContext?
    
    /// OpenAI service for image analysis (injected for testing)
    private let openAIService: OpenAIServiceProtocol?

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
           !flow.contains(.multiItemSelection) {
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
    
    /// Created inventory items
    @Published var createdItems: [InventoryItem] = []
    
    /// Unique transition ID for animations
    @Published var transitionId = UUID()
    
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
            return false // Final step
        }
    }
    
    /// Progress percentage through the flow
    var progressPercentage: Double {
        Double(currentStepIndex) / Double(navigationFlow.count - 1)
    }
    
    // MARK: - Initialization
    
    init(
        captureMode: CaptureMode,
        location: InventoryLocation?,
        modelContext: ModelContext? = nil,
        openAIService: OpenAIServiceProtocol? = nil
    ) {
        self.captureMode = captureMode
        self.location = location
        self.modelContext = modelContext
        self.openAIService = openAIService
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
    
    /// Create OpenAI service with mock support for UI testing
    private func createOpenAIService() -> OpenAIServiceProtocol {
        return OpenAIServiceFactory.create()
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
                if let openAIError = error as? OpenAIError {
                    print("   OpenAI Error Details: \(openAIError)")
                }
                await MainActor.run {
                    let detailedError = "Analysis failed: \(error.localizedDescription)\n\nError type: \(type(of: error))"
                    errorMessage = detailedError
                    processingImage = false
                }
            }
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
            label: nil,
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
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(primaryImage, id: itemId)
                newItem.imageURL = primaryImageURL
                
                // Save secondary images if there are more than one
                if capturedImages.count > 1 {
                    let secondaryImages = Array(capturedImages.dropFirst())
                    let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(secondaryImages, itemId: itemId)
                    newItem.secondaryPhotoURLs = secondaryURLs
                }
            }
            
            await MainActor.run {
                if let context = modelContext {
                    context.insert(newItem)
                    try? context.save()
                }
                TelemetryManager.shared.trackInventoryItemAdded(name: newItem.title)
            }
            
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

            let openAi = openAIService ?? createOpenAIService()
            print("🔍 ItemCreationFlowViewModel: Using OpenAI service: \(type(of: openAi))")
            let imageDetails = try await openAi.getImageDetails(
                from: capturedImages,
                settings: settings,
                modelContext: context
            )
            
            await MainActor.run {
                // Get all labels and locations for the unified update
                let labels = (try? context.fetch(FetchDescriptor<InventoryLabel>())) ?? []
                let locations = (try? context.fetch(FetchDescriptor<InventoryLocation>())) ?? []

                item.updateFromImageDetails(imageDetails, labels: labels, locations: locations)
                try? context.save()

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
                    confidence: 0.95 // Single item AI analysis is highly confident
                )

                multiItemAnalysisResponse = MultiItemAnalysisResponse(
                    items: [detectedItem],
                    detectedCount: 1,
                    analysisType: "single_item_as_multi",
                    confidence: 0.95
                )

                analysisComplete = true
                processingImage = false
            }
            
        } catch {
            print("❌ ItemCreationFlowViewModel (Single): Analysis error: \(error)")
            if let openAIError = error as? OpenAIError {
                print("   OpenAI Error Details: \(openAIError)")
            }
            await MainActor.run {
                let detailedError = "Analysis failed: \(error.localizedDescription)\n\nError type: \(type(of: error))"
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

            let openAi = openAIService ?? createOpenAIService()
            print("🔍 ItemCreationFlowViewModel (Multi-Item): Using OpenAI service: \(type(of: openAi))")
            let response = try await openAi.getMultiItemDetails(
                from: capturedImages,
                settings: settings,
                modelContext: context
            )

            // Restore original setting
            await MainActor.run {
                settings.isHighDetail = originalHighDetail
            }
            
            await MainActor.run {
                multiItemAnalysisResponse = response
                analysisComplete = true
                processingImage = false
            }
            
        } catch {
            print("❌ ItemCreationFlowViewModel (Multi-Item): Analysis error: \(error)")
            if let openAIError = error as? OpenAIError {
                print("   OpenAI Error Details: \(openAIError)")
            }
            await MainActor.run {
                let detailedError = "Multi-item analysis failed: \(error.localizedDescription)\n\nError type: \(type(of: error))"
                errorMessage = detailedError
                processingImage = false
            }
        }
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
                label: nil,
                price: parsePrice(from: detectedItem.estimatedPrice),
                insured: false,
                assetId: "",
                notes: "AI-detected \(detectedItem.category) with \(Int(detectedItem.confidence * 100))% confidence",
                showInvalidQuantityAlert: false
            )
            
            // Generate unique ID for this item
            let itemId = UUID().uuidString
            
            do {
                // Save primary image
                if let primaryImage = capturedImages.first {
                    let primaryImageURL = try await OptimizedImageManager.shared.saveImage(primaryImage, id: itemId)
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
            let existingLabels = (try? context.fetch(FetchDescriptor<InventoryLabel>())) ?? []
            
            for (index, item) in items.enumerated() {
                let detectedCategory = selectedMultiItems[index].category
                
                // Find or create label for this category
                if let existingLabel = existingLabels.first(where: { $0.name.lowercased() == detectedCategory.lowercased() }) {
                    item.label = existingLabel
                } else if !detectedCategory.isEmpty && detectedCategory.lowercased() != "unknown" {
                    // Create new label for this category
                    let colorString = assignColorForCategory(detectedCategory)
                    // Convert hex string to UIColor via Color extension
                    let hexValue = UInt(colorString.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0x007AFF
                    let color = Color(hex: hexValue)
                    let uiColor = UIColor(color)
                    let newLabel = InventoryLabel(name: detectedCategory, color: uiColor)
                    context.insert(newLabel)
                    item.label = newLabel
                }
            }
        }
        
        // Insert all items in batch
        for item in items {
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
        processingImage = false
        analysisComplete = false
        errorMessage = nil
        multiItemAnalysisResponse = nil
        selectedMultiItems = []
        createdItems = []
        transitionId = UUID()
    }

    /// Reset only the analysis state (for re-analyzing)
    func resetAnalysisState() {
        analysisComplete = false
        errorMessage = nil
        multiItemAnalysisResponse = nil
        processingImage = false
        transitionId = UUID()
    }
    
    /// Handle multi-item selection completion
    func handleMultiItemSelection(_ items: [InventoryItem]) {
        createdItems = items
        goToNextStep() // Move to details step
    }
    
    // MARK: - Helper Methods
    
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
    
    /// Assign appropriate color for category labels
    private func assignColorForCategory(_ category: String) -> String {
        // Predefined color mapping for common categories
        let categoryColors: [String: String] = [
            "electronics": "#007AFF",    // Blue
            "furniture": "#8E4EC6",      // Purple
            "clothing": "#FF69B4",       // Pink
            "kitchen": "#FF9500",        // Orange  
            "books": "#34C759",          // Green
            "tools": "#FF3B30",          // Red
            "toys": "#FFCC02",           // Yellow
            "jewelry": "#AF52DE",        // Violet
            "sports": "#32D74B",         // Light Green
            "automotive": "#64D2FF",     // Light Blue
            "appliances": "#BF5AF2",     // Light Purple
            "art": "#FF6482"             // Light Red
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