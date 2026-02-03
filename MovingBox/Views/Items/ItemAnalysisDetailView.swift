import Dependencies
import SQLiteData
import SwiftUI

struct ItemAnalysisDetailView: View {
    @Dependency(\.defaultDatabase) var database
    @Environment(\.isOnboarding) private var isOnboarding
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var item: SQLiteInventoryItem?
    let image: UIImage
    let onSave: () -> Void

    @State private var showingImageAnalysis = true
    @State private var navigationPath = NavigationPath()
    @State private var showError = false
    @State private var errorMessage = ""

    init(item: SQLiteInventoryItem?, image: UIImage, onSave: @escaping () -> Void) {
        self._item = State(initialValue: item)
        self.image = image
        self.onSave = onSave
    }

    var body: some View {
        if isOnboarding {
            NavigationStack(path: $navigationPath) {
                mainContent
                    .navigationDestination(for: String.self) { route in
                        if route == "detail", let currentItem = item {
                            InventoryDetailView(
                                itemID: currentItem.id,
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
        guard
            await OptimizedImageManager.shared.prepareImageForAI(
                from: image, useHighQuality: useHighQuality) != nil
        else {
            throw AnalysisError.imagePreparationFailed
        }

        guard item != nil else {
            throw AnalysisError.itemNotFound
        }

        let openAi = OpenAIServiceFactory.create()

        let imageDetails = try await openAi.getImageDetails(
            from: [image],
            settings: settings,
            database: database
        )

        let labels =
            (try? await database.read { db in
                try SQLiteInventoryLabel.all.fetchAll(db)
            }) ?? []

        await MainActor.run {
            updateItemFromImageDetails(imageDetails, labels: labels)
            TelemetryManager.shared.trackCameraAnalysisUsed()
        }

        // Save updated item to SQLite
        if let currentItem = item {
            let itemToSave = currentItem
            try? await database.write { db in
                try SQLiteInventoryItem.find(itemToSave.id).update {
                    $0.title = itemToSave.title
                    $0.desc = itemToSave.desc
                    $0.model = itemToSave.model
                    $0.make = itemToSave.make
                    $0.price = itemToSave.price
                    $0.serial = itemToSave.serial
                    $0.condition = itemToSave.condition
                    $0.color = itemToSave.color
                    $0.dimensionLength = itemToSave.dimensionLength
                    $0.dimensionWidth = itemToSave.dimensionWidth
                    $0.dimensionHeight = itemToSave.dimensionHeight
                    $0.dimensionUnit = itemToSave.dimensionUnit
                    $0.weightValue = itemToSave.weightValue
                    $0.weightUnit = itemToSave.weightUnit
                    $0.purchaseLocation = itemToSave.purchaseLocation
                    $0.replacementCost = itemToSave.replacementCost
                    $0.storageRequirements = itemToSave.storageRequirements
                    $0.isFragile = itemToSave.isFragile
                    $0.hasUsedAI = itemToSave.hasUsedAI
                }.execute(db)
            }
        }
    }

    private func updateItemFromImageDetails(
        _ imageDetails: ImageDetails,
        labels: [SQLiteInventoryLabel]
    ) {
        guard var currentItem = item else { return }

        if !imageDetails.title.isEmpty { currentItem.title = imageDetails.title }
        if !imageDetails.make.isEmpty { currentItem.make = imageDetails.make }
        if !imageDetails.model.isEmpty { currentItem.model = imageDetails.model }
        if !imageDetails.description.isEmpty { currentItem.desc = imageDetails.description }
        if !imageDetails.serialNumber.isEmpty { currentItem.serial = imageDetails.serialNumber }

        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(
            in: .whitespaces)
        if let price = Decimal(string: priceString), price > 0 {
            currentItem.price = price
        }

        if let condition = imageDetails.condition, !condition.isEmpty {
            currentItem.condition = condition
        }

        if let color = imageDetails.color, !color.isEmpty {
            currentItem.color = color
        }

        if let dimensions = imageDetails.dimensions, !dimensions.isEmpty {
            let cleanedString = dimensions.replacingOccurrences(of: "\"", with: " inches")
            let components = cleanedString.components(separatedBy: " x ").compactMap {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if components.count >= 3 {
                currentItem.dimensionLength = components[0].replacingOccurrences(
                    of: "[^0-9.]", with: "", options: .regularExpression)
                currentItem.dimensionWidth = components[1].replacingOccurrences(
                    of: "[^0-9.]", with: "", options: .regularExpression)
                currentItem.dimensionHeight = components[2].replacingOccurrences(
                    of: "[^0-9.]", with: "", options: .regularExpression)
                if dimensions.contains("cm") || dimensions.contains("centimeter") {
                    currentItem.dimensionUnit = "cm"
                } else if dimensions.contains("mm") || dimensions.contains("millimeter") {
                    currentItem.dimensionUnit = "mm"
                } else {
                    currentItem.dimensionUnit = "inches"
                }
            }
        }

        if let purchaseLocation = imageDetails.purchaseLocation, !purchaseLocation.isEmpty {
            currentItem.purchaseLocation = purchaseLocation
        }

        if let replacementCostString = imageDetails.replacementCost, !replacementCostString.isEmpty {
            let cleanedString = replacementCostString.replacingOccurrences(of: "$", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let replacementCost = Decimal(string: cleanedString) {
                currentItem.replacementCost = replacementCost
            }
        }

        if let storageRequirements = imageDetails.storageRequirements, !storageRequirements.isEmpty {
            currentItem.storageRequirements = storageRequirements
        }

        if let isFragileString = imageDetails.isFragile, !isFragileString.isEmpty {
            currentItem.isFragile = isFragileString.lowercased() == "true"
        }

        currentItem.hasUsedAI = true
        item = currentItem
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
