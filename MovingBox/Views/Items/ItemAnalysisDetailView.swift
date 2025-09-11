import SwiftUI
import SwiftData

struct ItemAnalysisDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isOnboarding) private var isOnboarding
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    let item: InventoryItem?
    let image: UIImage
    let onSave: () -> Void
    
    @State private var showingImageAnalysis = true
    @State private var navigationPath = NavigationPath()
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        if isOnboarding {
            NavigationStack(path: $navigationPath) {
                mainContent
                    .navigationDestination(for: String.self) { route in
                        if route == "detail", let currentItem = item {
                            InventoryDetailView(
                                inventoryItemToDisplay: currentItem,
                                navigationPath: $navigationPath,
                                isEditing: true,
                                onSave: onSave
                            )
                        }
                    }
            }
        } else {
            mainContent
        }
    }
    
    private var mainContent: some View {
        ZStack {
            if showingImageAnalysis {
                ImageAnalysisView(image: image) {
                    Task {
                        do {
                            try await performAnalysis()
                            showingImageAnalysis = false
                            
                            if isOnboarding {
                                navigationPath.append("detail")
                            } else {
                                onSave()
                            }
                        } catch {
                            await MainActor.run {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }
                }
                .environment(\.isOnboarding, isOnboarding)
            } else if !isOnboarding {
                // Show empty view when analysis is complete in non-onboarding flow
                Color.clear
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func performAnalysis() async throws {
        let useHighQuality = settings.isPro && settings.highQualityAnalysisEnabled
        guard let base64ForAI = await OptimizedImageManager.shared.prepareImageForAI(from: image, useHighQuality: useHighQuality) else {
            throw AnalysisError.imagePreparationFailed
        }
        
        guard let itemToUpdate = item else {
            throw AnalysisError.itemNotFound
        }
        
        let openAi = OpenAIService()
        
        let imageDetails = try await openAi.getImageDetails(
            from: [image],
            settings: settings,
            modelContext: modelContext
        )
        
        await MainActor.run {
            updateUIWithImageDetails(imageDetails, for: itemToUpdate)
            TelemetryManager.shared.trackCameraAnalysisUsed()
        }
    }
    
    private func updateUIWithImageDetails(_ imageDetails: ImageDetails, for item: InventoryItem) {
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        guard let labels: [InventoryLabel] = try? modelContext.fetch(labelDescriptor) else { return }
        
        // Core properties
        item.title = imageDetails.title
        item.quantityString = imageDetails.quantity
        item.label = labels.first { $0.name == imageDetails.category }
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        item.serial = imageDetails.serialNumber
        item.hasUsedAI = true
        
        // Price handling
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        item.price = Decimal(string: priceString) ?? 0
        
        // Extended properties (if provided by AI)
        if let condition = imageDetails.condition, !condition.isEmpty {
            item.condition = condition
        }
        
        if let color = imageDetails.color, !color.isEmpty {
            item.color = color
        }
        
        if let dimensions = imageDetails.dimensions, !dimensions.isEmpty {
            // Parse consolidated dimensions like "9.4" x 6.6" x 0.29"" into separate fields
            parseDimensions(dimensions, for: item)
        }
        
        if let purchaseLocation = imageDetails.purchaseLocation, !purchaseLocation.isEmpty {
            item.purchaseLocation = purchaseLocation
        }
        
        if let replacementCostString = imageDetails.replacementCost, !replacementCostString.isEmpty {
            let cleanedString = replacementCostString.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
            if let replacementCost = Decimal(string: cleanedString) {
                item.replacementCost = replacementCost
            }
        }
        
        if let storageRequirements = imageDetails.storageRequirements, !storageRequirements.isEmpty {
            item.storageRequirements = storageRequirements
        }
        
        if let isFragileString = imageDetails.isFragile, !isFragileString.isEmpty {
            item.isFragile = isFragileString.lowercased() == "true"
        }
        
        try? modelContext.save()
    }
    
    private func parseDimensions(_ dimensionsString: String, for item: InventoryItem) {
        // Parse formats like "9.4\" x 6.6\" x 0.29\"" or "12 x 8 x 4 inches"
        let cleanedString = dimensionsString.replacingOccurrences(of: "\"", with: " inches")
        let components = cleanedString.components(separatedBy: " x ").compactMap { $0.trimmingCharacters(in: .whitespaces) }
        
        if components.count >= 3 {
            // Extract numeric values
            let lengthStr = components[0].replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            let widthStr = components[1].replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            let heightStr = components[2].replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            
            item.dimensionLength = lengthStr
            item.dimensionWidth = widthStr
            item.dimensionHeight = heightStr
            
            // Determine unit from the original string
            if dimensionsString.contains("cm") || dimensionsString.contains("centimeter") {
                item.dimensionUnit = "cm"
            } else if dimensionsString.contains("mm") || dimensionsString.contains("millimeter") {
                item.dimensionUnit = "mm"
            } else if dimensionsString.contains("m") && !dimensionsString.contains("mm") && !dimensionsString.contains("cm") {
                item.dimensionUnit = "m"
            } else {
                item.dimensionUnit = "inches" // Default to inches
            }
        }
    }
    
    private func parseWeight(_ weightString: String, for item: InventoryItem) {
        // Parse formats like "1.03 lbs" or "2.5 kg"
        let components = weightString.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
        
        if components.count >= 2 {
            let valueStr = components[0].replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            let unitStr = components[1].lowercased()
            
            item.weightValue = valueStr
            
            if unitStr.contains("kg") || unitStr.contains("kilogram") {
                item.weightUnit = "kg"
            } else if unitStr.contains("g") && !unitStr.contains("kg") {
                item.weightUnit = "g"
            } else if unitStr.contains("oz") || unitStr.contains("ounce") {
                item.weightUnit = "oz"
            } else {
                item.weightUnit = "lbs" // Default to lbs
            }
        } else if components.count == 1 {
            // Only a value, no unit specified - use the numeric part
            let valueStr = components[0].replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            if !valueStr.isEmpty {
                item.weightValue = valueStr
                item.weightUnit = "lbs" // Default unit
            }
        }
    }
    
    private enum AnalysisError: LocalizedError {
        case imagePreparationFailed
        case itemNotFound
        
        var errorDescription: String? {
            switch self {
            case .imagePreparationFailed:
                return "Failed to prepare image for analysis"
            case .itemNotFound:
                return "Item not found"
            }
        }
    }
}
