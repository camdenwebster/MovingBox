import SwiftUI
import PhotosUI
import SwiftData
import AVFoundation
import UIKit

@MainActor
struct ItemCreationFlowView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared

    let location: InventoryLocation?
    let onComplete: () -> Void
    var initialImages: [UIImage] = []

    @State private var currentStep: ItemCreationStep = .camera
    @State private var item: InventoryItem? 
    @State private var analysisComplete = false 
    @State private var analysisViewReadyToDismiss = false 
    @State private var isLoadingOpenAiResults = false
    @State private var showingPaywall = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var transitionId = UUID() 
    @State private var tempLoadedImages: [UIImage] = []
    @State private var tempImageURLs: [URL] = [] 
    @State private var tempPrimaryImageIndex: Int = 0

    private class TempPhotoManageable: PhotoManageable, ObservableObject {
        var imageURL: URL? { 
            get { primaryImageURL }
            set {
                if let newValue {
                    imageURLs = [newValue]
                    primaryImageIndex = 0
                } else {
                    imageURLs = []
                    primaryImageIndex = 0
                }
            }
        }
        var imageURLs: [URL]
        var primaryImageIndex: Int
        var photo: UIImage? { get async throws { nil } } 
        var thumbnail: UIImage? { get async throws { nil } } 

        init(imageURLs: [URL], primaryImageIndex: Int) {
            self.imageURLs = imageURLs
            self.primaryImageIndex = primaryImageIndex
        }
    }

    @State private var tempPhotoModel: TempPhotoManageable = TempPhotoManageable(imageURLs: [], primaryImageIndex: 0)


    private enum ItemCreationStep: Int, CaseIterable {
        case camera = 0
        case analyzing = 1
        case details = 2

        var title: String {
            switch self {
            case .camera: return "Add Photo(s)" 
            case .analyzing: return "Analyzing"
            case .details: return "Details"
            }
        }
    }

    private var transitionAnimation: Animation {
        .easeInOut(duration: 0.3)
    }

    var body: some View {
        NavigationView {
            VStack {
                ProgressView(value: Double(currentStep.rawValue), total: Double(ItemCreationStep.allCases.count - 1))
                    .padding(.horizontal)

                TabView(selection: $currentStep) {
                    Group {
                        if currentStep == .camera {
                            VStack { 
                                Text("Add photos for your new item")
                                    .font(.headline)
                                    .padding()

                                if tempLoadedImages.isEmpty {
                                    PhotoPickerView(
                                        model: $tempPhotoModel, 
                                        loadedImages: $tempLoadedImages,
                                        isLoading: $isLoadingOpenAiResults, 
                                        showRemoveButton: false 
                                    ) { showPicker in 
                                        AddPhotoButton {
                                            showPicker.wrappedValue = true 
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                        .background(Color.secondary.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .foregroundStyle(.secondary)
                                        .padding()
                                    }

                                } else {
                                    PhotoGridEditorView(
                                        model: $tempPhotoModel,
                                        loadedImages: $tempLoadedImages,
                                        isLoading: $isLoadingOpenAiResults 
                                    )
                                }

                                if !tempLoadedImages.isEmpty {
                                    Button("Analyze Photo\(tempLoadedImages.count > 1 ? "s" : "")") {
                                        if settings.shouldShowPaywallForAiScan(currentCount: 0) { 
                                            showingPaywall = true
                                        } else {
                                            Task {
                                                await startAnalysisFlow()
                                            }
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .padding()
                                }
                            } 
                        }
                    }
                    .tag(ItemCreationStep.camera)


                    Group {
                        if currentStep == .analyzing {
                            if !tempLoadedImages.isEmpty { 
                                ZStack {
                                    ImageAnalysisView(images: tempLoadedImages) { 
                                        analysisViewReadyToDismiss = true
                                        checkAndTransitionToDetails()
                                    }
                                }
                            } else {
                                Text("No images to analyze.")
                                    .onAppear {
                                        withAnimation(transitionAnimation) {
                                            transitionId = UUID()
                                            currentStep = .details
                                        }
                                    }
                            }
                        }
                    }
                    .tag(ItemCreationStep.analyzing)

                    Group {
                        if currentStep == .details {
                            if let item = item {
                                InventoryDetailView(
                                    inventoryItemToDisplay: item,
                                    navigationPath: .constant(NavigationPath()), 
                                    showSparklesButton: false, 
                                    isEditing: true
                                ) {
                                    onComplete() 
                                    dismiss() 
                                }
                            } else {
                                Text("Error: Item not created.")
                                    .onAppear {
                                        dismiss()
                                    }
                            }
                        }
                    }
                    .tag(ItemCreationStep.details)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(nil, value: currentStep) 
                .disabled(true) 

                .alert("Analysis Error", isPresented: $showError) {
                    Button("OK") {
                        withAnimation(transitionAnimation) {
                            transitionId = UUID()
                            currentStep = .details
                        }
                    }
                } message: {
                    Text(errorMessage ?? "An unknown error occurred during analysis.")
                }
            }
            .navigationTitle(currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                revenueCatManager.presentPaywall(
                    isPresented: $showingPaywall,
                    onCompletion: {
                        settings.isPro = true
                        Task {
                            await startAnalysisFlow()
                        }
                    },
                    onDismiss: {
                        withAnimation(transitionAnimation) {
                            transitionId = UUID()
                            currentStep = .details
                        }
                    }
                )
            }
            .task(id: initialImages.count) {
                if !initialImages.isEmpty && tempLoadedImages.isEmpty {
                    isLoadingOpenAiResults = true 
                    defer { isLoadingOpenAiResults = false }

                    tempLoadedImages = initialImages

                    tempPhotoModel.imageURLs = initialImages.compactMap { _ in URL(string: "temp://dummy")! } 
                    tempPhotoModel.primaryImageIndex = 0 

                    currentStep = .analyzing 

                    await startAnalysisFlow()
                }
            }
            .onChange(of: analysisComplete) { _, _ in checkAndTransitionToDetails() }
            .onChange(of: analysisViewReadyToDismiss) { _, _ in checkAndTransitionToDetails() }
        }
    }

    private func checkAndTransitionToDetails() {
        print("Checking transition conditions: analysisComplete = \(analysisComplete), analysisViewReadyToDismiss = \(analysisViewReadyToDismiss)")
        if analysisComplete && analysisViewReadyToDismiss {
            print("Both conditions met, transitioning to details.")
            withAnimation(transitionAnimation) {
                transitionId = UUID()
                currentStep = .details
            }
        } else {
            print("Conditions not met yet.")
        }
    }

    private func startAnalysisFlow() async {
        guard !tempLoadedImages.isEmpty else {
            errorMessage = "No images to analyze."
            showError = true
            return
        }

        isLoadingOpenAiResults = true 
        defer { isLoadingOpenAiResults = false }

        analysisComplete = false
        analysisViewReadyToDismiss = false

        let newItem = InventoryItem() 
        newItem.location = location 

        let savedImageURLs = await saveLoadedImages()
        newItem.imageURLs = savedImageURLs 
        newItem.primaryImageIndex = tempPhotoModel.primaryImageIndex 

        modelContext.insert(newItem)
        item = newItem 
        try? modelContext.save() 

        guard let itemForAnalysis = item,
              let primaryImageURL = itemForAnalysis.primaryImageURL,
              let photo = await OptimizedImageManager.shared.loadImage(url: primaryImageURL)
        else {
            errorMessage = "Unable to load primary image for analysis."
            showError = true
            analysisComplete = true 
            checkAndTransitionToDetails()
            return
        }

        guard let imageBase64 = await OptimizedImageManager.shared.prepareImageForAI(from: photo) else {
            errorMessage = "Failed to prepare image for AI."
            showError = true
            analysisComplete = true 
            checkAndTransitionToDetails()
            return
        }

        let openAi = OpenAIService(imageBase64: imageBase64, settings: settings, modelContext: modelContext)

        TelemetryManager.shared.trackCameraAnalysisUsed()

        do {
            let imageDetails = try await openAi.getImageDetails()
            updateUIWithImageDetails(imageDetails)
            analysisComplete = true 
            print("Analysis complete, moving to details.")
            checkAndTransitionToDetails()

        } catch OpenAIError.invalidURL {
            errorMessage = "Invalid URL configuration."
            showError = true
            analysisComplete = true 
            checkAndTransitionToDetails()
        } catch OpenAIError.invalidResponse {
            errorMessage = "Error communicating with AI service."
            showError = true
            analysisComplete = true 
            checkAndTransitionToDetails()
        } catch OpenAIError.invalidData {
            errorMessage = "Unable to process AI response."
            showError = true
            analysisComplete = true 
            checkAndTransitionToDetails()
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            showError = true
            analysisComplete = true 
            checkAndTransitionToDetails()
        }
    }

    private func saveLoadedImages() async -> [URL] {
        var urls: [URL] = []
        for image in tempLoadedImages { 
            do {
                let id = UUID().uuidString
                if let imageURL = try await OptimizedImageManager.shared.saveImage(image, id: id) {
                    urls.append(imageURL)
                }
            } catch {
                print("Error saving loaded image: \(error)")
            }
        }
        return urls
    }

    private func updateUIWithImageDetails(_ imageDetails: ImageDetails) {
        guard let item = item else { return }
        item.title = imageDetails.title
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model 
        item.price = Decimal(string: imageDetails.price) ?? 0.0
        item.hasUsedAI = true
        try? modelContext.save()
    }
}

#Preview {
    ItemCreationFlowView(location: nil) {
        print("Item creation flow completed")
    }
        .modelContainer(try! ModelContainer(for: InventoryLocation.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        .environmentObject(Router())
        .environmentObject(SettingsManager())
        .environmentObject(RevenueCatManager.shared)
}
