//
//  InventoryDetailViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/2/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import Foundation

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
        settingsManager: SettingsManager = SettingsManager.shared,
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

// MARK: - Supporting Types

enum UnsavedChangesAction {
    case save
    case discard
    case cancel
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