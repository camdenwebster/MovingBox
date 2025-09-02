//
//  InventoryDetailViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/2/25.
//

import Foundation
import SwiftUI
import SwiftData
import PhotosUI
import RevenueCatUI

@MainActor
@Observable
class InventoryDetailViewModel {
    // MARK: - Published Properties
    var isEditing: Bool
    var displayPriceString: String = ""
    var isLoadingOpenAiResults: Bool = false
    var showingErrorAlert: Bool = false
    var errorMessage: String = ""
    var showUnsavedChangesAlert: Bool = false
    var showAIConfirmationAlert: Bool = false
    var showingPaywall: Bool = false
    var tempUIImage: UIImage?
    var loadedImage: UIImage?
    var isLoading: Bool = false
    var loadingError: Error?
    var showingMultiPhotoCamera: Bool = false
    var showingSimpleCamera: Bool = false
    var capturedImages: [UIImage] = []
    var capturedSingleImage: UIImage?
    var loadedImages: [UIImage] = []
    var selectedImageIndex: Int = 0
    var showingFullScreenPhoto: Bool = false
    var showPhotoSourceAlert: Bool = false
    var showPhotoPicker: Bool = false
    var selectedPhotosPickerItems: [PhotosPickerItem] = []
    var showingLocationSelection: Bool = false
    var showingLabelSelection: Bool = false
    
    // MARK: - Dependencies
    private let inventoryItem: InventoryItem
    private let modelContext: ModelContext
    private let settings: SettingsManager
    private let revenueCatManager: RevenueCatManager
    let onSave: (() -> Void)?
    let onCancel: (() -> Void)?
    
    // MARK: - Internal State
    private var imageDetailsFromOpenAI: ImageDetails = ImageDetails(
        title: "", quantity: "", description: "", make: "", model: "", 
        category: "None", location: "None", price: "", serialNumber: ""
    )
    
    // MARK: - Initialization
    init(
        inventoryItem: InventoryItem,
        modelContext: ModelContext,
        settings: SettingsManager,
        revenueCatManager: RevenueCatManager = .shared,
        isEditing: Bool = false,
        onSave: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.inventoryItem = inventoryItem
        self.modelContext = modelContext
        self.settings = settings
        self.revenueCatManager = revenueCatManager
        self.isEditing = isEditing
        self.onSave = onSave
        self.onCancel = onCancel
        self.displayPriceString = formatInitialPrice(inventoryItem.price)
        
        // Load images on initialization
        Task {
            await loadAllImages()
        }
    }
    
    // MARK: - Computed Properties
    var showSparklesButton: Bool {
        return isEditing && inventoryItem.hasUsedAI
    }
    
    var currentPhotoCount: Int {
        let primaryCount = inventoryItem.imageURL != nil ? 1 : 0
        return primaryCount + inventoryItem.secondaryPhotoURLs.count
    }
    
    var canAddMorePhotos: Bool {
        return currentPhotoCount < 5
    }
    
    var maxPhotosToAdd: Int {
        return max(1, 5 - currentPhotoCount)
    }
    
    // MARK: - AI Analysis
    func analyzeWithAI() async {
        guard !isLoadingOpenAiResults else { return }
        
        // Check if user should see paywall
        let allItems = try? modelContext.fetch(FetchDescriptor<InventoryItem>())
        let aiUsedCount = allItems?.filter { $0.hasUsedAI }.count ?? 0
        
        if settings.shouldShowPaywallForAiScan(currentCount: aiUsedCount) {
            showingPaywall = true
            return
        }
        
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
    
    private func callOpenAI() async throws -> ImageDetails {
        isLoadingOpenAiResults = true
        defer { isLoadingOpenAiResults = false }
        
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
        if inventoryItem.modelContext == nil {
            modelContext.insert(inventoryItem)
        }
        
        inventoryItem.title = imageDetails.title
        inventoryItem.quantityString = imageDetails.quantity
        inventoryItem.desc = imageDetails.description
        inventoryItem.make = imageDetails.make
        inventoryItem.model = imageDetails.model
        inventoryItem.serial = imageDetails.serialNumber
        
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        if let price = Decimal(string: priceString) {
            inventoryItem.price = price
            displayPriceString = formatInitialPrice(price)
        }
        
        inventoryItem.hasUsedAI = true
        try? modelContext.save()
    }
    
    // MARK: - Photo Management
    func addPhotoAction() {
        if canAddMorePhotos {
            showPhotoSourceAlert = true
        }
    }
    
    func deletePhoto(at index: Int) async {
        let urlString: String
        if index == 0 {
            // Deleting primary image
            guard let imageURL = inventoryItem.imageURL else { return }
            urlString = imageURL.absoluteString
        } else {
            // Deleting secondary image
            let secondaryIndex = index - 1
            guard secondaryIndex < inventoryItem.secondaryPhotoURLs.count else { return }
            urlString = inventoryItem.secondaryPhotoURLs[secondaryIndex]
        }
        
        await deletePhoto(urlString: urlString)
    }
    
    private func deletePhoto(urlString: String) async {
        guard URL(string: urlString) != nil else { return }
        
        do {
            // Delete from storage
            try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: urlString)
            
            if inventoryItem.imageURL?.absoluteString == urlString {
                // Deleting primary image
                inventoryItem.imageURL = nil
                
                // If there are secondary photos, promote the first one to primary
                if !inventoryItem.secondaryPhotoURLs.isEmpty {
                    if let firstSecondaryURL = URL(string: inventoryItem.secondaryPhotoURLs.first!) {
                        inventoryItem.imageURL = firstSecondaryURL
                        inventoryItem.secondaryPhotoURLs.removeFirst()
                    }
                }
            } else {
                // Deleting secondary image
                inventoryItem.secondaryPhotoURLs.removeAll { $0 == urlString }
            }
            
            try? modelContext.save()
            
            // Reload images after deletion
            await loadAllImages()
        } catch {
            print("Error deleting photo: \(error)")
        }
    }
    
    func handleNewPhotos(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        
        do {
            let itemId = inventoryItem.assetId.isEmpty ? UUID().uuidString : inventoryItem.assetId
            
            if inventoryItem.imageURL == nil {
                // No primary image yet, save the first image as primary
                let primaryImageURL = try await OptimizedImageManager.shared.saveImage(images.first!, id: itemId)
                
                inventoryItem.imageURL = primaryImageURL
                inventoryItem.assetId = itemId
                
                // Save remaining images as secondary photos
                if images.count > 1 {
                    let secondaryImages = Array(images.dropFirst())
                    let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(secondaryImages, itemId: itemId)
                    inventoryItem.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                }
            } else {
                // Primary image exists, add all new images as secondary photos
                let secondaryURLs = try await OptimizedImageManager.shared.saveSecondaryImages(images, itemId: itemId)
                
                inventoryItem.assetId = itemId
                inventoryItem.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
            }
            
            try? modelContext.save()
            TelemetryManager.shared.trackInventoryItemAdded(name: inventoryItem.title)
            
            // Reload images after adding new photos
            await loadAllImages()
        } catch {
            print("Error saving new photos: \(error)")
        }
    }
    
    private func loadAllImages() async {
        isLoading = true
        defer { isLoading = false }
        
        var images: [UIImage] = []
        
        // Load primary image
        if let imageURL = inventoryItem.imageURL {
            do {
                let image = try await OptimizedImageManager.shared.loadImage(url: imageURL)
                images.append(image)
            } catch {
                print("Failed to load primary image: \(error)")
            }
        }
        
        // Load secondary images
        if !inventoryItem.secondaryPhotoURLs.isEmpty {
            do {
                let secondaryImages = try await OptimizedImageManager.shared.loadSecondaryImages(from: inventoryItem.secondaryPhotoURLs)
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
    
    func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
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
        
        selectedPhotosPickerItems = []
    }
    
    // MARK: - Edit Mode Management
    func startEditing() {
        isEditing = true
    }
    
    func cancelEditing() {
        if onCancel != nil {
            // During onboarding - delete the item and close the sheet
            deleteItemAndCloseSheet()
        } else if OnboardingManager.hasCompletedOnboarding() {
            // Normal editing mode - handle unsaved changes
            if modelContext.hasChanges {
                showUnsavedChangesAlert = true
            } else {
                isEditing = false
            }
        }
    }
    
    func saveChanges() {
        if inventoryItem.modelContext == nil {
            modelContext.insert(inventoryItem)
        }
        try? modelContext.save()
        isEditing = false
        onSave?()
    }
    
    func discardChanges() {
        modelContext.rollback()
        isEditing = false
    }
    
    func saveAndStay() {
        try? modelContext.save()
        isEditing = false
    }
    
    private func deleteItemAndCloseSheet() {
        Task {
            do {
                if let imageURL = inventoryItem.imageURL {
                    try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: imageURL.absoluteString)
                }
                
                for photoURL in inventoryItem.secondaryPhotoURLs {
                    try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: photoURL)
                }
            } catch {
                print("Error deleting images during cancellation: \(error)")
            }
            
            // Remove the item from the model context
            modelContext.delete(inventoryItem)
            try? modelContext.save()
            
            // Call the onCancel callback to close the sheet
            onCancel?()
        }
    }
    
    // MARK: - Validation & Formatting
    private func formatInitialPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "0.00"
    }
    
    // MARK: - Camera Actions
    func onCapturedSingleImageChanged(_ image: UIImage?) {
        if let image = image {
            Task {
                await handleNewPhotos([image])
                capturedSingleImage = nil
            }
        }
    }
    
    func onMultiPhotoCameraComplete(_ images: [UIImage]) {
        Task {
            await handleNewPhotos(images)
            showingMultiPhotoCamera = false
        }
    }
    
    func onMultiPhotoCameraCancel() {
        showingMultiPhotoCamera = false
    }
    
    // MARK: - UI Actions
    func showTakePhoto() {
        showingSimpleCamera = true
    }
    
    func showChooseFromLibrary() {
        showPhotoPicker = true
    }
    
    func showMultiPhotoCamera() {
        showingMultiPhotoCamera = true
    }
    
    func onImageTap(_ index: Int) {
        if !isEditing {
            selectedImageIndex = index
            showingFullScreenPhoto = true
        }
    }
}