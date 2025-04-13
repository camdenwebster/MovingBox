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
        Group {
            if isOnboarding {
                // Only wrap in NavigationStack during onboarding
                NavigationStack(path: $navigationPath) {
                    analysisContent
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
                // Direct analysis content without navigation
                analysisContent
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
    
    private var analysisContent: some View {
        ZStack {
            if showingImageAnalysis {
                ImageAnalysisView(image: image) {
                    Task {
                        await analyzeImage()
                        showingImageAnalysis = false
                        
                        if isOnboarding {
                            navigationPath.append("detail")
                        } else {
                            onSave()
                        }
                    }
                }
                .environment(\.isOnboarding, isOnboarding)
            } else {
                Color.clear
            }
        }
    }
    
    private func analyzeImage() async {
        guard let base64ForAI = OptimizedImageManager.shared.prepareImageForAI(from: image),
              let _ = item else {
            await MainActor.run {
                errorMessage = "Unable to process the image"
                showError = true
            }
            return
        }
        
        let openAi = OpenAIService(
            imageBase64: base64ForAI,
            settings: settings,
            modelContext: modelContext
        )
        
        do {
            let imageDetails = try await openAi.getImageDetails()
            await MainActor.run {
                updateUIWithImageDetails(imageDetails)
                TelemetryManager.shared.trackCameraAnalysisUsed()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error analyzing image: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func updateUIWithImageDetails(_ imageDetails: ImageDetails) {
        guard let item = item else { return }
        
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        guard let labels: [InventoryLabel] = try? modelContext.fetch(labelDescriptor) else { return }
        
        item.title = imageDetails.title
        item.quantityString = imageDetails.quantity
        item.label = labels.first { $0.name == imageDetails.category }
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        item.hasUsedAI = true
        
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        item.price = Decimal(string: priceString) ?? 0
        
        try? modelContext.save()
    }
}
