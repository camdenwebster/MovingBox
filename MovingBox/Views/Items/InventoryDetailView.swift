//
//  InventoryDetail.swift
//  MovingBox
//
//  Created by Camden Webster on 5/16/24.
//

import RevenueCatUI
import PhotosUI
import SwiftData
import SwiftUI
import Foundation

// MARK: - Supporting Types

enum UnsavedChangesAction {
    case save
    case discard
    case cancel
}

// MARK: - ViewModel

@MainActor
@Observable
final class InventoryDetailViewModel {
    
    // MARK: - Dependencies
    
    private let item: InventoryItem
    private let modelContext: ModelContext
    private let openAIService: OpenAIServiceProtocol
    private let settingsManager: SettingsManager
    private let optimizedImageManager: OptimizedImageManager
    private let telemetryManager: TelemetryManager
    
    // MARK: - UI State
    
    var isEditing: Bool = false
    var isLoadingAI: Bool = false
    var isLoadingImages: Bool = false
    var showingErrorAlert: Bool = false
    var showingPaywall: Bool = false
    var showingAIConfirmationAlert: Bool = false
    var showingUnsavedChangesAlert: Bool = false
    var showingLocationSelection: Bool = false
    var showingLabelSelection: Bool = false
    var showingMultiPhotoCamera: Bool = false
    var showingSimpleCamera: Bool = false
    var showingFullScreenPhoto: Bool = false
    var showPhotoPicker: Bool = false
    var showPhotoSourceAlert: Bool = false
    
    var errorMessage: String = ""
    var selectedImageIndex: Int = 0
    var capturedImages: [UIImage] = []
    var capturedSingleImage: UIImage?
    var loadedImages: [UIImage] = []
    var selectedPhotosPickerItems: [PhotosPickerItem] = []
    
    // MARK: - Item Properties (Bindable)
    
    var title: String {
        get { item.title }
        set { item.title = newValue }
    }
    
    var quantity: Int {
        get { item.quantityInt }
        set { 
            item.quantityInt = newValue
            item.quantityString = String(newValue)
        }
    }
    
    var itemDescription: String {
        get { item.desc }
        set { item.desc = newValue }
    }
    
    var serial: String {
        get { item.serial }
        set { item.serial = newValue }
    }
    
    var make: String {
        get { item.make }
        set { item.make = newValue }
    }
    
    var model: String {
        get { item.model }
        set { item.model = newValue }
    }
    
    var notes: String {
        get { item.notes }
        set { item.notes = newValue }
    }
    
    var price: Decimal {
        get { item.price }
        set { item.price = newValue }
    }
    
    var isInsured: Bool {
        get { item.insured }
        set { item.insured = newValue }
    }
    
    var location: InventoryLocation? {
        get { item.location }
        set { item.location = newValue }
    }
    
    var label: InventoryLabel? {
        get { item.label }
        set { item.label = newValue }
    }
    
    var displayPriceString: String = ""
    
    // MARK: - Computed Properties
    
    var currentPhotoCount: Int {
        let primaryCount = item.imageURL != nil ? 1 : 0
        return primaryCount + item.secondaryPhotoURLs.count
    }
    
    var canAddMorePhotos: Bool {
        currentPhotoCount < 5
    }
    
    var shouldShowAIButton: Bool {
        return isEditing && !item.hasUsedAI && item.imageURL != nil
    }
    
    var canSave: Bool {
        !title.isEmpty && !isLoadingAI
    }
    
    var hasUnsavedChanges: Bool {
        modelContext.hasChanges
    }
    
    // MARK: - Initialization
    
    init(
        item: InventoryItem,
        modelContext: ModelContext,
        openAIService: OpenAIServiceProtocol? = nil,
        settingsManager: SettingsManager,
        optimizedImageManager: OptimizedImageManager = OptimizedImageManager.shared,
        telemetryManager: TelemetryManager = TelemetryManager.shared
    ) {
        self.item = item
        self.modelContext = modelContext
        self.settingsManager = settingsManager
        self.optimizedImageManager = optimizedImageManager
        self.telemetryManager = telemetryManager
        self.displayPriceString = formatPrice(item.price)
        
        // Create openAIService after other properties are set
        self.openAIService = openAIService ?? DefaultOpenAIService(modelContext: modelContext, settings: settingsManager)
    }
    
    // MARK: - Edit Mode Management
    
    func toggleEditMode() {
        isEditing.toggle()
    }
    
    func startEditing() {
        isEditing = true
    }
    
    func cancelEditing() {
        if hasUnsavedChanges {
            showingUnsavedChangesAlert = true
        } else {
            isEditing = false
        }
    }
    
    func handleUnsavedChanges(action: UnsavedChangesAction) {
        switch action {
        case .save:
            save()
            isEditing = false
        case .discard:
            modelContext.rollback()
            displayPriceString = formatPrice(item.price)
            isEditing = false
        case .cancel:
            break
        }
        showingUnsavedChangesAlert = false
    }
    
    // MARK: - Data Persistence
    
    func save() {
        if item.modelContext == nil {
            modelContext.insert(item)
        }
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    func deleteItem() {
        Task {
            await deleteAllPhotos()
            modelContext.delete(item)
            try? modelContext.save()
        }
    }
    
    // MARK: - AI Analysis
    
    func performAIAnalysis() async {
        guard !isLoadingAI else { return }
        guard !loadedImages.isEmpty else { 
            errorMessage = "No images available for analysis"
            showingErrorAlert = true
            return
        }
        
        // Check paywall
        let allItems = try? modelContext.fetch(FetchDescriptor<InventoryItem>())
        let aiUsedCount = allItems?.filter { $0.hasUsedAI }.count ?? 0
        
        if settingsManager.shouldShowPaywallForAiScan(currentCount: aiUsedCount) {
            showingPaywall = true
            return
        }
        
        isLoadingAI = true
        defer { isLoadingAI = false }
        
        do {
            // Create a new service instance with current images
            let aiService = DefaultOpenAIService(modelContext: modelContext, settings: settingsManager, loadedImages: loadedImages)
            let imageDetails = try await aiService.getImageDetails()
            updateItemWithAIResults(imageDetails)
            telemetryManager.trackCameraAnalysisUsed()
        } catch let error as OpenAIError {
            errorMessage = error.userFriendlyMessage
            showingErrorAlert = true
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    func showAIConfirmationAlert() {
        showingAIConfirmationAlert = true
    }
    
    func confirmAIAnalysis() {
        showingAIConfirmationAlert = false
        Task {
            await performAIAnalysis()
        }
    }
    
    private func updateItemWithAIResults(_ imageDetails: ImageDetails) {
        title = imageDetails.title
        quantity = Int(imageDetails.quantity) ?? 1
        itemDescription = imageDetails.description
        make = imageDetails.make
        model = imageDetails.model
        serial = imageDetails.serialNumber
        
        // Parse and set price
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        if let parsedPrice = Decimal(string: priceString) {
            price = parsedPrice
            displayPriceString = formatPrice(parsedPrice)
        }
        
        item.hasUsedAI = true
        save()
    }
    
    // MARK: - Photo Management
    
    func loadAllImages() async {
        isLoadingImages = true
        defer { isLoadingImages = false }
        
        var images: [UIImage] = []
        
        // Load primary image
        if let imageURL = item.imageURL {
            do {
                let image = try await optimizedImageManager.loadImage(url: imageURL)
                images.append(image)
            } catch {
                print("Failed to load primary image: \(error)")
            }
        }
        
        // Load secondary images
        if !item.secondaryPhotoURLs.isEmpty {
            do {
                let secondaryImages = try await optimizedImageManager.loadSecondaryImages(from: item.secondaryPhotoURLs)
                images.append(contentsOf: secondaryImages)
            } catch {
                print("Failed to load secondary images: \(error)")
            }
        }
        
        loadedImages = images
        if selectedImageIndex >= images.count {
            selectedImageIndex = max(0, images.count - 1)
        }
    }
    
    func addPhotos(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        
        do {
            let itemId = item.assetId.isEmpty ? UUID().uuidString : item.assetId
            
            if item.imageURL == nil {
                // Set first image as primary
                let primaryImageURL = try await optimizedImageManager.saveImage(images.first!, id: itemId)
                item.imageURL = primaryImageURL
                item.assetId = itemId
                
                // Save remaining as secondary
                if images.count > 1 {
                    let secondaryImages = Array(images.dropFirst())
                    let secondaryURLs = try await optimizedImageManager.saveSecondaryImages(secondaryImages, itemId: itemId)
                    item.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                }
            } else {
                // Add all as secondary photos
                let secondaryURLs = try await optimizedImageManager.saveSecondaryImages(images, itemId: itemId)
                item.assetId = itemId
                item.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
            }
            
            save()
            telemetryManager.trackInventoryItemAdded(name: title)
            await loadAllImages()
        } catch {
            errorMessage = "Error saving photos: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    func deletePhoto(at index: Int) async {
        guard index < loadedImages.count else { return }
        
        let urlString: String
        if index == 0 {
            // Deleting primary image
            guard let imageURL = item.imageURL else { return }
            urlString = imageURL.absoluteString
        } else {
            // Deleting secondary image
            let secondaryIndex = index - 1
            guard secondaryIndex < item.secondaryPhotoURLs.count else { return }
            urlString = item.secondaryPhotoURLs[secondaryIndex]
        }
        
        await deletePhoto(urlString: urlString)
    }
    
    private func deletePhoto(urlString: String) async {
        do {
            try await optimizedImageManager.deleteSecondaryImage(urlString: urlString)
            
            if item.imageURL?.absoluteString == urlString {
                // Deleting primary image
                item.imageURL = nil
                
                // Promote first secondary to primary if available
                if !item.secondaryPhotoURLs.isEmpty {
                    if let firstSecondaryURL = URL(string: item.secondaryPhotoURLs.first!) {
                        item.imageURL = firstSecondaryURL
                        item.secondaryPhotoURLs.removeFirst()
                    }
                }
            } else {
                // Deleting secondary image
                item.secondaryPhotoURLs.removeAll { $0 == urlString }
            }
            
            save()
            await loadAllImages()
        } catch {
            errorMessage = "Error deleting photo: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    private func deleteAllPhotos() async {
        do {
            if let imageURL = item.imageURL {
                try await optimizedImageManager.deleteSecondaryImage(urlString: imageURL.absoluteString)
            }
            
            for photoURL in item.secondaryPhotoURLs {
                try await optimizedImageManager.deleteSecondaryImage(urlString: photoURL)
            }
        } catch {
            print("Error deleting images: \(error)")
        }
    }
    
    // MARK: - Camera Actions
    
    func showPhotoSourceOptions() {
        guard canAddMorePhotos else { return }
        showPhotoSourceAlert = true
    }
    
    func openCamera() {
        showingSimpleCamera = true
    }
    
    func openMultiPhotoCamera() {
        showingMultiPhotoCamera = true
    }
    
    func openPhotoLibrary() {
        showPhotoPicker = true
    }
    
    func handleCapturedSingleImage() {
        if let image = capturedSingleImage {
            Task {
                await addPhotos([image])
                capturedSingleImage = nil
            }
        }
    }
    
    func handleCapturedMultipleImages() {
        Task {
            await addPhotos(capturedImages)
            capturedImages.removeAll()
        }
    }
    
    func processSelectedPhotosPickerItems() async {
        guard !selectedPhotosPickerItems.isEmpty else { return }
        
        var images: [UIImage] = []
        
        for item in selectedPhotosPickerItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        
        if !images.isEmpty {
            await addPhotos(images)
        }
        
        selectedPhotosPickerItems.removeAll()
    }
    
    // MARK: - Navigation Actions
    
    func showFullScreenPhoto(at index: Int) {
        selectedImageIndex = index
        showingFullScreenPhoto = true
    }
    
    func showLocationSelection() {
        showingLocationSelection = true
    }
    
    func showLabelSelection() {
        showingLabelSelection = true
    }
    
    // MARK: - Utility Methods
    
    func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "0.00"
    }
    
    func maxPhotosToAdd() -> Int {
        max(1, 5 - currentPhotoCount)
    }
}

// MARK: - Default OpenAI Service Implementation

private class DefaultOpenAIService: OpenAIServiceProtocol {
    private let modelContext: ModelContext
    private let settings: SettingsManager
    private let optimizedImageManager: OptimizedImageManager
    private let loadedImages: [UIImage]
    
    init(modelContext: ModelContext, settings: SettingsManager, loadedImages: [UIImage] = []) {
        self.modelContext = modelContext
        self.settings = settings
        self.optimizedImageManager = OptimizedImageManager.shared
        self.loadedImages = loadedImages
    }
    
    func getImageDetails() async throws -> ImageDetails {
        guard !loadedImages.isEmpty else {
            throw OpenAIError.invalidData
        }
        
        // Prepare all images for AI analysis
        var imageBase64Array: [String] = []
        for image in loadedImages {
            if let base64 = await optimizedImageManager.prepareImageForAI(from: image) {
                imageBase64Array.append(base64)
            }
        }
        
        guard !imageBase64Array.isEmpty else {
            throw OpenAIError.invalidData
        }
        
        let openAIService = OpenAIService(imageBase64Array: imageBase64Array, settings: settings, modelContext: modelContext)
        return try await openAIService.getImageDetails()
    }
}

@MainActor
struct InventoryDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @Query private var allItems: [InventoryItem]
    @Bindable var inventoryItemToDisplay: InventoryItem
    @Binding var navigationPath: NavigationPath
    
    @State private var viewModel: InventoryDetailViewModel
    
    var showSparklesButton = false

    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared

    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    

    init(inventoryItemToDisplay: InventoryItem,
         navigationPath: Binding<NavigationPath>,
         showSparklesButton: Bool = false,
         isEditing: Bool = false,
         onSave: (() -> Void)? = nil,
         onCancel: (() -> Void)? = nil) {
        self.inventoryItemToDisplay = inventoryItemToDisplay
        self._navigationPath = navigationPath
        self.showSparklesButton = showSparklesButton
        self.onSave = onSave
        self.onCancel = onCancel
        
        // ViewModel will be initialized in onAppear when we have access to environment objects
        let schema = Schema([InventoryItem.self, InventoryLocation.self, InventoryLabel.self, Home.self, InsurancePolicy.self])
        let tempContext = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]).mainContext
        let tempSettings = SettingsManager()
        self._viewModel = State(initialValue: InventoryDetailViewModel(item: inventoryItemToDisplay, modelContext: tempContext, settingsManager: tempSettings))
        
        // Set initial editing state
        self._viewModel.wrappedValue.isEditing = isEditing
    }

    @FocusState private var focusedField: Field?
    
    private enum Field {
        case title
        case serial
        case make
        case model
        case description
        case notes
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var photoSection: some View {
        // Photo banner section
        if !viewModel.loadedImages.isEmpty {
            ZStack {
                GeometryReader { proxy in
                    let scrollY = proxy.frame(in: .global).minY
                    
                    FullScreenPhotoCarouselView(
                        images: viewModel.loadedImages,
                        selectedIndex: $viewModel.selectedImageIndex,
                        screenWidth: UIScreen.main.bounds.width,
                        isEditing: viewModel.isEditing,
                        onAddPhoto: {
                            viewModel.showPhotoSourceOptions()
                        },
                        onDeletePhoto: { index in
                            Task {
                                await viewModel.deletePhoto(at: index)
                            }
                        },
                        onImageTap: { tappedIndex in
                            if !viewModel.isEditing {
                                viewModel.showFullScreenPhoto(at: tappedIndex)
                            }
                        }
                    )
                    .frame(width: proxy.size.width, height: 350 + (scrollY > 0 ? scrollY : 0))
                    .clipped()
                    .offset(y: scrollY > 0 ? -scrollY : 0)
                }
                .frame(height: 350)
                .clipped()
                
                // Edit mode controls overlay - positioned at container bottom
                if isEditing {
                    VStack {
                        Spacer()
                        HStack(spacing: 16) {
                            // Delete photo button
                            if !loadedImages.isEmpty {
                                Button(action: {
                                    Task {
                                        let urlString: String
                                        if selectedImageIndex == 0 {
                                            // Deleting primary image
                                            if let imageURL = inventoryItemToDisplay.imageURL {
                                                urlString = imageURL.absoluteString
                                            } else {
                                                return
                                            }
                                        } else {
                                            // Deleting secondary image
                                            let secondaryIndex = selectedImageIndex - 1
                                            if secondaryIndex < inventoryItemToDisplay.secondaryPhotoURLs.count {
                                                urlString = inventoryItemToDisplay.secondaryPhotoURLs[secondaryIndex]
                                            } else {
                                                return
                                            }
                                        }
                                        await deletePhoto(urlString: urlString)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.red.opacity(0.8))
                                        .clipShape(Circle())
                                }
                            }
                            
                            Spacer()
                            
                            // Add photo button
                            let currentPhotoCount = (inventoryItemToDisplay.imageURL != nil ? 1 : 0) + inventoryItemToDisplay.secondaryPhotoURLs.count
                            if currentPhotoCount < 5 {
                                Button(action: {
                                    showPhotoSourceAlert = true
                                }) {
                                    Image(systemName: "plus")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.blue.opacity(0.8))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 60)
                    }
                }
            }
        } else {
            // Show placeholder when no photos exist (both editing and viewing)
            PhotoPlaceholderView(
                isEditing: isEditing,
                onAddPhoto: {
                    showPhotoSourceAlert = true
                }
            )
            .frame(height: 250)
        }
    }
    
    @ViewBuilder
    private var formContent: some View {
        VStack(spacing: 0) {
            // AI Button Section
            if isEditing && !inventoryItemToDisplay.hasUsedAI && inventoryItemToDisplay.imageURL != nil {
                VStack(spacing: 0) {
                    aiButtonView
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
            }
            
            // Form sections
            VStack(spacing: 24) {
                detailsSection
                
                if isEditing || inventoryItemToDisplay.quantityInt > 1 {
                    quantitySection
                }
                
                if isEditing || !inventoryItemToDisplay.desc.isEmpty {
                    descriptionSection
                }
                
                priceSection
                locationsAndLabelsSection
                
                if isEditing || !inventoryItemToDisplay.notes.isEmpty {
                    notesSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
    
    @ViewBuilder
    private var aiButtonView: some View {
        Button {
            guard !isLoadingOpenAiResults else { return }
            if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
                showingPaywall = true
            } else {
                Task {
                    do {
                        let imageDetails = try await callOpenAI()
                        updateUIWithImageDetails(imageDetails)
                    } catch OpenAIError.invalidURL {
                        errorMessage = "Invalid URL configuration"
                        showingErrorAlert = true
                    } catch OpenAIError.invalidResponse {
                        errorMessage = "Error communicating with AI service"
                        showingErrorAlert = true
                    } catch OpenAIError.invalidData {
                        errorMessage = "Unable to process AI response"
                        showingErrorAlert = true
                    } catch {
                        errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                        showingErrorAlert = true
                    }
                }
            }
        } label: {
            HStack {
                if isLoadingOpenAiResults {
                    ProgressView()
                } else {
                    Image(systemName: "wand.and.sparkles")
                    Text("Analyze with AI")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundColor(.white)
            .background(Color.accentColor)
            .cornerRadius(8)
        }
        .buttonStyle(.automatic)
        .disabled(isLoadingOpenAiResults)
        .accessibilityIdentifier("analyzeWithAi")
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                if isEditing || !inventoryItemToDisplay.title.isEmpty {
                    FormTextFieldRow(label: "Title", text: $inventoryItemToDisplay.title, isEditing: $isEditing, placeholder: "Desktop Computer")
                        .focused($focusedField, equals: .title)
                        .accessibilityIdentifier("titleField")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    if (isEditing || !inventoryItemToDisplay.serial.isEmpty) || 
                       (isEditing || !inventoryItemToDisplay.make.isEmpty) || 
                       (isEditing || !inventoryItemToDisplay.model.isEmpty) {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                if isEditing || !inventoryItemToDisplay.serial.isEmpty {
                    FormTextFieldRow(label: "Serial Number", text: $inventoryItemToDisplay.serial, isEditing: $isEditing, placeholder: "SN-12345")
                        .focused($focusedField, equals: .serial)
                        .accessibilityIdentifier("serialField")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    if (isEditing || !inventoryItemToDisplay.make.isEmpty) || 
                       (isEditing || !inventoryItemToDisplay.model.isEmpty) {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                if isEditing || !inventoryItemToDisplay.make.isEmpty {
                    FormTextFieldRow(label: "Make", text: $inventoryItemToDisplay.make, isEditing: $isEditing, placeholder: "Apple")
                        .focused($focusedField, equals: .make)
                        .accessibilityIdentifier("makeField")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    
                    if isEditing || !inventoryItemToDisplay.model.isEmpty {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                if isEditing || !inventoryItemToDisplay.model.isEmpty {
                    FormTextFieldRow(label: "Model", text: $inventoryItemToDisplay.model, isEditing: $isEditing, placeholder: "Mac Mini")
                        .focused($focusedField, equals: .model)
                        .accessibilityIdentifier("modelField")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(UIConstants.cornerRadius)
        }
    }
    
    @ViewBuilder
    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantity")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                Stepper("\(inventoryItemToDisplay.quantityInt)", value: $inventoryItemToDisplay.quantityInt, in: 1...1000, step: 1)
                    .disabled(!isEditing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(UIConstants.cornerRadius)
        }
    }
    
    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                TextEditor(text: $inventoryItemToDisplay.desc)
                    .focused($focusedField, equals: .description)
                    .frame(height: 60)
                    .disabled(!isEditing)
                    .accessibilityIdentifier("descriptionField")
                    .foregroundColor(isEditing ? .primary : .secondary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(UIConstants.cornerRadius)
        }
    }
    
    @ViewBuilder
    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Purchase Price")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                PriceFieldRow(
                    priceString: $displayPriceString,
                    priceDecimal: $inventoryItemToDisplay.price,
                    isEditing: $isEditing
                )
                .disabled(!isEditing)
                .accessibilityIdentifier("priceField")
                .foregroundColor(isEditing ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.leading, 16)
                
                Toggle(isOn: $inventoryItemToDisplay.insured, label: {
                    Text("Insured")
                })
                .disabled(!isEditing)
                .accessibilityIdentifier("insuredToggle")
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(UIConstants.cornerRadius)
        }
    }
    
    @ViewBuilder
    private var locationsAndLabelsSection: some View {
        if isEditing || inventoryItemToDisplay.location != nil || inventoryItemToDisplay.label != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Locations & Labels")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    if isEditing || inventoryItemToDisplay.location != nil {
                        Button(action: {
                            if isEditing {
                                showingLocationSelection = true
                            }
                        }) {
                            HStack {
                                Text("Location")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(inventoryItemToDisplay.location?.name ?? "None")
                                    .foregroundColor(.secondary)
                                if isEditing {
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(!isEditing)
                        .accessibilityIdentifier("locationPicker")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if isEditing || inventoryItemToDisplay.label != nil {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                    
                    if isEditing || inventoryItemToDisplay.label != nil {
                        Button(action: {
                            if isEditing {
                                showingLabelSelection = true
                            }
                        }) {
                            HStack {
                                Text("Label")
                                    .foregroundColor(.primary)
                                Spacer()
                                if let label = inventoryItemToDisplay.label {
                                    Text("\(label.emoji) \(label.name)")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("None")
                                        .foregroundColor(.secondary)
                                }
                                if isEditing {
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(!isEditing)
                        .accessibilityIdentifier("labelPicker")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(UIConstants.cornerRadius)
            }
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.footnote)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                TextEditor(text: $inventoryItemToDisplay.notes)
                    .foregroundColor(isEditing ? .primary : .secondary)
                    .focused($focusedField, equals: .notes)
                    .frame(height: 100)
                    .disabled(!isEditing)
                    .accessibilityIdentifier("notesField")
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(UIConstants.cornerRadius)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    photoSection
                    
                    formContent
                        .background(Color(.systemGroupedBackground))
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    var body: some View {
        mainContent
            .applyNavigationSettings(
                title: inventoryItemToDisplay.title,
                isEditing: viewModel.isEditing,
                colorScheme: colorScheme
            )
            .onAppear {
                // Reinitialize ViewModel with proper environment objects
                viewModel = InventoryDetailViewModel(
                    item: inventoryItemToDisplay,
                    modelContext: modelContext,
                    settingsManager: settings
                )
                
                // Load images on appear
                Task {
                    await viewModel.loadAllImages()
                }
            }
            .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if viewModel.isEditing {
                    Button("Cancel") {
                        if onCancel != nil {
                            // During onboarding - delete the item and close the sheet
                            deleteItemAndCloseSheet()
                        } else if OnboardingManager.hasCompletedOnboarding() {
                            // Normal editing mode - handle unsaved changes
                            viewModel.cancelEditing()
                        }
                    }
                    .accessibilityIdentifier("cancelButton")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if inventoryItemToDisplay.hasUsedAI {
                    if showSparklesButton && viewModel.isEditing {
                        Button(action: {
                            if settings.shouldShowPaywallForAiScan(currentCount: allItems.filter({ $0.hasUsedAI}).count) {
                                viewModel.showingPaywall = true
                            } else {
                                viewModel.showAIConfirmationAlert = true
                            }
                        }) {
                            Image(systemName: "wand.and.sparkles")
                                    }
                        .disabled(viewModel.isLoadingAI)
                        .accessibilityIdentifier("sparkles")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isLoadingAI {
                    ProgressView()
                } else {
                    if viewModel.isEditing {
                        Button("Save") {
                            viewModel.save()
                            viewModel.isEditing = false
                            onSave?()
                        }
                        .fontWeight(.bold)
                            .disabled(!viewModel.canSave)
                        .accessibilityIdentifier("save")
                    } else {
                        Button("Edit") {
                            viewModel.startEditing()
                        }
                            .accessibilityIdentifier("edit")
                    }
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            revenueCatManager.presentPaywall(
                isPresented: $showingPaywall,
                onCompletion: {
                    settings.isPro = true
                    // Add any specific post-purchase actions here
                },
                onDismiss: nil
            )
        }
        .sheet(isPresented: $showingMultiPhotoCamera) {
            let currentPhotoCount = (inventoryItemToDisplay.imageURL != nil ? 1 : 0) + inventoryItemToDisplay.secondaryPhotoURLs.count
            let maxPhotosToAdd = max(1, 5 - currentPhotoCount)
            CustomCameraView(
                capturedImages: $capturedImages,
                mode: .multiPhoto(maxPhotos: maxPhotosToAdd),
                onPermissionCheck: { granted in
                    if !granted {
                        // Handle permission denied
                        print("Camera permission denied")
                    }
                },
                onComplete: { images in
                    Task {
                        await handleNewPhotos(images)
                        showingMultiPhotoCamera = false
                    }
                },
                onCancel: {
                    showingMultiPhotoCamera = false
                }
            )
        }
        .alert("AI Image Analysis", isPresented: $showAIConfirmationAlert) {
            Button("Analyze Image", role: .none) {
                Task {
                    do {
                        let imageDetails = try await callOpenAI()
                        updateUIWithImageDetails(imageDetails)
                    } catch let error as OpenAIError {
                        errorMessage = error.userFriendlyMessage
                        showingErrorAlert = true
                    } catch {
                        errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                        showingErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will analyze the image using AI and update the following item details:\n\n• Title\n• Quantity\n• Description\n• Make\n• Model\n• Label\n• Location\n• Price\n\nExisting values will be overwritten. Do you want to proceed?")
        }
        .alert("AI Analysis Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showingSimpleCamera = true
            }
            Button("Choose from Library") {
                showPhotoPicker = true
            }
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Save & Stay", role: .none) {
                try? modelContext.save()
                isEditing = false
            }
            
            Button("Discard Changes", role: .destructive) {
                modelContext.rollback()
                isEditing = false
            }
            
            Button("Cancel", role: .cancel) {
                showUnsavedChangesAlert = false
            }
        } message: {
            Text("Do you want to save your changes before exiting edit mode?")
        }
        .task(id: inventoryItemToDisplay.imageURL) {
            await loadAllImages()
        }
        .onChange(of: inventoryItemToDisplay.secondaryPhotoURLs) { _, _ in
            Task {
                await loadAllImages()
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPhoto) {
            FullScreenPhotoView(
                images: loadedImages,
                initialIndex: selectedImageIndex,
                isPresented: $showingFullScreenPhoto
            )
        }
        .fullScreenCover(isPresented: $showingSimpleCamera) {
            SimpleCameraView(capturedImage: $capturedSingleImage)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotosPickerItems,
            maxSelectionCount: max(1, 5 - ((inventoryItemToDisplay.imageURL != nil ? 1 : 0) + inventoryItemToDisplay.secondaryPhotoURLs.count)),
            matching: .images
        )
        .onChange(of: capturedSingleImage) { _, newImage in
            if let image = newImage {
                Task {
                    await handleNewPhotos([image])
                    capturedSingleImage = nil
                }
            }
        }
        .onChange(of: selectedPhotosPickerItems) { _, newItems in
            Task {
                await processSelectedPhotos(newItems)
            }
        }
        .sheet(isPresented: $showingLocationSelection) {
            LocationSelectionView(selectedLocation: $inventoryItemToDisplay.location)
        }
        .sheet(isPresented: $showingLabelSelection) {
            LabelSelectionView(selectedLabel: $inventoryItemToDisplay.label)
        }
    }

    private func callOpenAI() async throws -> ImageDetails {
        isLoadingOpenAiResults = true
        defer { isLoadingOpenAiResults = false }
        
        // Use all loaded images for AI analysis
        guard !loadedImages.isEmpty else {
            throw OpenAIError.invalidData
        }
        
        // Prepare all images for AI analysis
        var imageBase64Array: [String] = []
        for image in loadedImages {
            if let base64 = await OptimizedImageManager.shared.prepareImageForAI(from: image) {
                imageBase64Array.append(base64)
            }
        }
        
        guard !imageBase64Array.isEmpty else {
            throw OpenAIError.invalidData
        }
        
        let openAi = OpenAIService(imageBase64Array: imageBase64Array, settings: settings, modelContext: modelContext)
        
        TelemetryManager.shared.trackCameraAnalysisUsed()
        
        return try await openAi.getImageDetails()
    }
    
    private func updateUIWithImageDetails(_ imageDetails: ImageDetails) {
        if inventoryItemToDisplay.modelContext == nil {
            modelContext.insert(inventoryItemToDisplay)
        }
        
        inventoryItemToDisplay.title = imageDetails.title
        inventoryItemToDisplay.quantityString = imageDetails.quantity
        // Note: We'll need to handle label assignment differently since we don't have all labels loaded
        // For now, we'll skip automatic label assignment from AI
        inventoryItemToDisplay.desc = imageDetails.description
        inventoryItemToDisplay.make = imageDetails.make
        inventoryItemToDisplay.model = imageDetails.model
        inventoryItemToDisplay.serial = imageDetails.serialNumber
        
        // Note: We'll need to handle location assignment differently since we don't have all locations loaded
        // For now, we'll skip automatic location assignment from AI
        
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        if let price = Decimal(string: priceString) {
            inventoryItemToDisplay.price = price
            displayPriceString = formatInitialPrice(price)
        }
        
        inventoryItemToDisplay.hasUsedAI = true
        
        try? modelContext.save()
    }
    
//    private func clearFields() {
//        print("Clear fields button tapped")
//        inventoryItemToDisplay.title = ""
//        inventoryItemToDisplay.label = nil
//        inventoryItemToDisplay.desc = ""
//        inventoryItemToDisplay.make = ""
//        inventoryItemToDisplay.model = ""
//        inventoryItemToDisplay.location = nil
//        inventoryItemToDisplay.price = 0
//        inventoryItemToDisplay.notes = ""
//    }
    
    private func addLocation() {
        let location = InventoryLocation()
        modelContext.insert(location)
        TelemetryManager.shared.trackLocationCreated(name: location.name)
        inventoryItemToDisplay.location = location
        router.navigate(to: .editLocationView(location: location, isEditing: true))
    }
    
    private func addLabel() {
        let label = InventoryLabel()
        modelContext.insert(label)
        inventoryItemToDisplay.label = label
        router.navigate(to: .editLabelView(label: label, isEditing: true))
    }
    
    private func handleNewPhotos(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        
        do {
            // Ensure we have a consistent itemId for all operations
            let itemId = inventoryItemToDisplay.assetId.isEmpty ? UUID().uuidString : inventoryItemToDisplay.assetId
            
            if inventoryItemToDisplay.imageURL == nil {
                // No primary image yet, save the first image as primary
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(images.first!, id: itemId)
                
                await MainActor.run {
                    inventoryItemToDisplay.imageURL = primaryImageURL
                    inventoryItemToDisplay.assetId = itemId
                }
                
                // Save remaining images as secondary photos
                if images.count > 1 {
                    let secondaryImages = Array(images.dropFirst())
                    let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(secondaryImages, itemId: itemId)
                    
                    await MainActor.run {
                        inventoryItemToDisplay.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                    }
                }
            } else {
                // Primary image exists, add all new images as secondary photos
                let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(images, itemId: itemId)
                
                await MainActor.run {
                    inventoryItemToDisplay.assetId = itemId
                    inventoryItemToDisplay.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                }
            }
            
            await MainActor.run {
                try? modelContext.save()
                TelemetryManager.shared.trackInventoryItemAdded(name: inventoryItemToDisplay.title)
            }
            
            // Reload images after adding new photos
            await loadAllImages()
        } catch {
            print("Error saving new photos: \(error)")
        }
    }
    
    private func deletePhoto(urlString: String) async {
        guard URL(string: urlString) != nil else { return }
        
        do {
            // Delete from storage
            try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: urlString)
            
            await MainActor.run {
                if inventoryItemToDisplay.imageURL?.absoluteString == urlString {
                    // Deleting primary image
                    inventoryItemToDisplay.imageURL = nil
                    
                    // If there are secondary photos, promote the first one to primary
                    if !inventoryItemToDisplay.secondaryPhotoURLs.isEmpty {
                        if let firstSecondaryURL = URL(string: inventoryItemToDisplay.secondaryPhotoURLs.first!) {
                            inventoryItemToDisplay.imageURL = firstSecondaryURL
                            inventoryItemToDisplay.secondaryPhotoURLs.removeFirst()
                        }
                    }
                } else {
                    // Deleting secondary image
                    inventoryItemToDisplay.secondaryPhotoURLs.removeAll { $0 == urlString }
                }
                
                try? modelContext.save()
                
                // Reload images after deletion
                Task {
                    await loadAllImages()
                }
            }
        } catch {
            print("Error deleting photo: \(error)")
        }
    }
    
    private func loadAllImages() async {
        // Use the view's modelContext instead of the item's modelContext
        // The item's modelContext can become nil after saving
        
        await MainActor.run {
            isLoading = true
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        var images: [UIImage] = []
        
        // Load primary image
        if let imageURL = inventoryItemToDisplay.imageURL {
            do {
                let image = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                images.append(image)
            } catch {
                print("Failed to load primary image: \(error)")
            }
        }
        
        // Load secondary images
        if !inventoryItemToDisplay.secondaryPhotoURLs.isEmpty {
            do {
                let secondaryImages = try await OptimizedImageManager.shared.loadSecondaryImages(from: inventoryItemToDisplay.secondaryPhotoURLs)
                images.append(contentsOf: secondaryImages)
            } catch {
                print("Failed to load secondary images: \(error)")
            }
        }
        
        await MainActor.run {
            loadedImages = images
            if selectedImageIndex >= images.count {
                selectedImageIndex = max(0, images.count - 1)
            }
        }
    }
    
    private func formatInitialPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "0.00"
    }
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        
        var images: [UIImage] = []
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        
        if !images.isEmpty {
            await handleNewPhotos(images)
        }
        
        // Clear selected items after processing
        await MainActor.run {
            selectedPhotosPickerItems = []
        }
    }
    
    private func deleteItemAndCloseSheet() {
        // Delete any saved images for this item
        Task {
            do {
                if let imageURL = inventoryItemToDisplay.imageURL {
                    try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: imageURL.absoluteString)
                }
                
                for photoURL in inventoryItemToDisplay.secondaryPhotoURLs {
                    try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: photoURL)
                }
            } catch {
                print("Error deleting images during cancellation: \(error)")
            }
            
            await MainActor.run {
                // Remove the item from the model context
                modelContext.delete(inventoryItemToDisplay)
                try? modelContext.save()
                
                // Call the onCancel callback to close the sheet
                onCancel?()
            }
        }
    }
}

// MARK: - Full Screen Photo Carousel View

struct FullScreenPhotoCarouselView: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int
    let screenWidth: CGFloat
    let isEditing: Bool
    let onAddPhoto: () -> Void
    let onDeletePhoto: (Int) -> Void
    let onImageTap: (Int) -> Void
    
    var body: some View {
        ZStack {
            // Photo carousel with swipe navigation
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: screenWidth)
                        .clipped()
                        .tag(index)
                        .onTapGesture {
                            onImageTap(index)
                        }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Overlay container for indicators - aligned to frame bottom
            VStack {
                Spacer()
                
                // Bottom overlay area
                ZStack {
                    // Dot indicators (only show if multiple photos)
                    if images.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<images.count, id: \.self) { index in
                                Circle()
                                    .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.5))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
                    // Photo count badge (like Vrbo) - positioned at frame bottom
                    if images.count > 1 {
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.caption)
                                Text("\(selectedIndex + 1) / \(images.count)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.6))
                            .clipShape(Capsule())
                        }
                        .padding(.trailing, 20)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Photo Placeholder View

struct PhotoPlaceholderView: View {
    let isEditing: Bool
    let onAddPhoto: () -> Void
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.1)
            
            VStack(spacing: 20) {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No photos yet")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                if isEditing {
                    Button(action: onAddPhoto) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Add Photo")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .clipShape(Capsule())
                        .accessibilityIdentifier("detailview-add-first-photo-button")
                    }
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var previewItem: InventoryItem
        
        init() {
            let location = InventoryLocation(name: "Office", desc: "My office")
            let item = InventoryItem(
                title: "MacBook Pro",
                quantityString: "1",
                quantityInt: 1,
                desc: "16-inch 2023 Model",
                serial: "SN12345ABC",
                model: "MacBook Pro M2",
                make: "Apple",
                location: location,
                label: nil,
                price: Decimal(2499.99),
                insured: false,
                assetId: "macbook-preview",
                notes: "Purchased for work and personal projects. Excellent condition with original box and charger.",
                showInvalidQuantityAlert: false,
                hasUsedAI: true
            )
            self._previewItem = State(initialValue: item)
        }
        
        var body: some View {
            InventoryDetailView(
                inventoryItemToDisplay: previewItem,
                navigationPath: .constant(NavigationPath()),
                isEditing: false
            )
            .environmentObject(Router())
            .environmentObject(SettingsManager())
            .environmentObject(OnboardingManager())
            .task {
                // Use the same approach as TestData.swift
                guard let image = UIImage(named: "macbook") else {
                    print("❌ Could not load image: macbook")
                    return
                }
                
                do {
                    let imageURL = try await OptimizedImageManager.shared.saveImage(image, id: "macbook-preview")
                    previewItem.imageURL = imageURL
                    print("✅ Successfully loaded preview image: macbook")
                } catch {
                    print("❌ Failed to setup preview image: \(error)")
                }
            }
        }
    }
    
    return PreviewWrapper()
}

// MARK: - View Extensions

extension View {
    func applyNavigationSettings(title: String, isEditing: Bool, colorScheme: ColorScheme) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isEditing)
            .toolbarBackground(colorScheme == .dark ? .black : .white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
    }
}

