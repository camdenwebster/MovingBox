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
        guard let base64ForAI = await OptimizedImageManager.shared.prepareImageForAI(from: image) else {
            throw AnalysisError.imagePreparationFailed
        }
        
        guard let itemToUpdate = item else {
            throw AnalysisError.itemNotFound
        }
        
        let openAi = OpenAIService(
            imageBase64: base64ForAI,
            settings: settings,
            modelContext: modelContext
        )
        
        let imageDetails = try await openAi.getImageDetails()
        
        await MainActor.run {
            updateUIWithImageDetails(imageDetails, for: itemToUpdate)
            TelemetryManager.shared.trackCameraAnalysisUsed()
        }
    }
    
    private func updateUIWithImageDetails(_ imageDetails: ImageDetails, for item: InventoryItem) {
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        guard let labels: [InventoryLabel] = try? modelContext.fetch(labelDescriptor) else { return }
        
        item.title = imageDetails.title
        item.quantityString = imageDetails.quantity
        item.label = labels.first { $0.name == imageDetails.category }
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        item.serial = imageDetails.serialNumber
        item.hasUsedAI = true
        
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        item.price = Decimal(string: priceString) ?? 0
        
        try? modelContext.save()
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
