//
//  InventoryDetailViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/9/25.
//

// NOTE: THIS IS NOT IN USE YET - ALL BUSINESS LOGIC IS IN InventoryDetailView.swift

import Foundation
import SwiftUI
import SwiftData
import UIKit
import PhotosUI
import StoreKit

@Observable
final class InventoryDetailViewModel {
    
    // MARK: - Dependencies
    
    private let openAIService: OpenAIServiceProtocol
    private let imageManager: ImageManagerProtocol
    private let settings: SettingsManager
    private let modelContext: ModelContext
    
    // MARK: - Published Properties
    
    var isLoadingOpenAiResults = false
    var errorMessage = ""
    var showingErrorAlert = false
    var showAIButton = false
    var loadedImages: [UIImage] = []
    var selectedImageIndex: Int = 0
    var isLoading = false
    var showPhotoSourceAlert = false
    var capturedImages: [UIImage] = []
    var capturedSingleImage: UIImage?
    var displayPriceString: String = ""
    var showingFileViewer = false
    var fileViewerURL: URL?
    var fileViewerName: String?
    var showingDeleteAttachmentAlert = false
    var attachmentToDelete: String?
    
    // MARK: - Initialization
    
    init(
        inventoryItem: InventoryItem,
        settings: SettingsManager,
        modelContext: ModelContext,
        openAIService: OpenAIServiceProtocol,
        imageManager: ImageManagerProtocol = OptimizedImageManagerWrapper()
    ) {
        self.settings = settings
        self.modelContext = modelContext
        self.openAIService = openAIService
        self.imageManager = imageManager
        
        Task { @MainActor in
            self.displayPriceString = formatInitialPrice(inventoryItem.price)
        }
    }
    
    // MARK: - AI Analysis
    
    func performAIAnalysis(for item: InventoryItem, allItems: [InventoryItem]) async {
        await MainActor.run {
            isLoadingOpenAiResults = true
        }

        do {
            let imageDetails = try await callOpenAI(for: item)
            await MainActor.run { @MainActor in
                updateUIWithImageDetails(imageDetails, for: item)
                isLoadingOpenAiResults = false

                // Increment successful AI analysis count and check for review request
                settings.incrementSuccessfulAIAnalysis()
                if settings.shouldRequestReview() {
                    requestAppReview()
                }
            }
        } catch {
            let capturedError = error
            await MainActor.run { @MainActor in
                handleAIError(capturedError)
                isLoadingOpenAiResults = false
            }
        }
    }
    
    private func callOpenAI(for item: InventoryItem) async throws -> ImageDetails {
        guard !loadedImages.isEmpty else {
            throw OpenAIError.invalidData
        }
        
        let imageDetails = try await openAIService.getImageDetails(
            from: loadedImages,
            settings: settings,
            modelContext: modelContext
        )
        
        TelemetryManager.shared.trackCameraAnalysisUsed()
        
        return imageDetails
    }
    
    @MainActor
    private func updateUIWithImageDetails(_ imageDetails: ImageDetails, for item: InventoryItem) {
        if item.modelContext == nil {
            modelContext.insert(item)
        }
        
        // Core properties
        item.title = imageDetails.title
        item.quantityString = imageDetails.quantity
        item.desc = imageDetails.description
        item.make = imageDetails.make
        item.model = imageDetails.model
        item.serial = imageDetails.serialNumber
        
        // Price handling
        let priceString = imageDetails.price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        if let price = Decimal(string: priceString) {
            item.price = price
            displayPriceString = formatInitialPrice(price)
        }
        
        // Extended properties (if provided by AI)
        if let condition = imageDetails.condition, !condition.isEmpty {
            item.condition = condition
        }
        
        if let color = imageDetails.color, !color.isEmpty {
            item.color = color
        }
        
        if let dimensions = imageDetails.dimensions, !dimensions.isEmpty {
            parseDimensions(dimensions, for: item)
        }
        
        
        if let weightValue = imageDetails.weightValue, !weightValue.isEmpty {
            item.weightValue = weightValue
            if let weightUnit = imageDetails.weightUnit, !weightUnit.isEmpty {
                item.weightUnit = weightUnit
            } else {
                item.weightUnit = "lbs" // default
            }
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
        
        item.hasUsedAI = true
        
        try? modelContext.save()
    }
    
    @MainActor
    private func handleAIError(_ error: Error) {
        if let openAIError = error as? OpenAIError {
            switch openAIError {
            case .invalidURL:
                errorMessage = "Invalid URL configuration"
            case .invalidResponse:
                errorMessage = "Error communicating with AI service"
            case .invalidData:
                errorMessage = "Unable to process AI response"
            default:
                errorMessage = openAIError.userFriendlyMessage
            }
        } else {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        showingErrorAlert = true
    }
    
    // MARK: - Photo Management
    
    @MainActor
    func loadAllImages(for item: InventoryItem) async {
        isLoading = true
        defer {
            isLoading = false
        }
        
        var images: [UIImage] = []
        
        // Load primary image
        if let imageURL = item.imageURL {
            do {
                let image = try await imageManager.loadImage(url: imageURL)
                images.append(image)
            } catch {
                print("Failed to load primary image: \(error)")
            }
        }
        
        // Load secondary images
        if !item.secondaryPhotoURLs.isEmpty {
            do {
                let secondaryImages = try await imageManager.loadSecondaryImages(from: item.secondaryPhotoURLs)
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
    
    @MainActor
    func handleNewPhotos(_ images: [UIImage], for item: InventoryItem) async {
        guard !images.isEmpty else { return }
        
        do {
            // Ensure we have a consistent itemId for all operations
            let itemId = item.assetId.isEmpty ? UUID().uuidString : item.assetId
            
            if item.imageURL == nil {
                // No primary image yet, save the first image as primary
                guard let firstImage = images.first else {
                    throw NSError(domain: "InventoryDetailViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No images provided"])
                }
                let primaryImageURL = try await imageManager.saveImage(firstImage, id: itemId)
                
                item.imageURL = primaryImageURL
                item.assetId = itemId
                
                // Save remaining images as secondary photos
                if images.count > 1 {
                    let secondaryImages = Array(images.dropFirst())
                    let secondaryURLs = try await imageManager.saveSecondaryImages(secondaryImages, itemId: itemId)
                    
                    item.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
                }
            } else {
                // Primary image exists, add all new images as secondary photos
                let secondaryURLs = try await imageManager.saveSecondaryImages(images, itemId: itemId)
                
                item.assetId = itemId
                item.secondaryPhotoURLs.append(contentsOf: secondaryURLs)
            }
            
            try? modelContext.save()
            TelemetryManager.shared.trackInventoryItemAdded(name: item.title)
            
            // Reload images after adding new photos
            await loadAllImages(for: item)
        } catch {
            print("Error saving new photos: \(error)")
        }
    }
    
    @MainActor
    func deletePhoto(urlString: String, for item: InventoryItem) async {
        guard URL(string: urlString) != nil else { return }
        
        do {
            // Delete from storage
            try await imageManager.deleteSecondaryImage(urlString: urlString)
            
            if item.imageURL?.absoluteString == urlString {
                // Deleting primary image
                item.imageURL = nil
                
                // If there are secondary photos, promote the first one to primary
                if !item.secondaryPhotoURLs.isEmpty {
                    if let firstSecondaryURLString = item.secondaryPhotoURLs.first,
                       let firstSecondaryURL = URL(string: firstSecondaryURLString) {
                        item.imageURL = firstSecondaryURL
                        item.secondaryPhotoURLs.removeFirst()
                    }
                }
            } else {
                // Deleting secondary image
                item.secondaryPhotoURLs.removeAll { $0 == urlString }
            }
            
            try? modelContext.save()
            
            // Reload images after deletion
            await loadAllImages(for: item)
        } catch {
            print("Error deleting photo: \(error)")
        }
    }
    
    // MARK: - Attachment Management
    
    @MainActor
    func handleAttachmentFileImport(_ result: Result<[URL], Error>, for item: InventoryItem) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                // Start accessing the security-scoped resource
                let startedAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if startedAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                // Copy the file to our app's storage
                let attachmentId = UUID().uuidString
                let data = try Data(contentsOf: url)
                let originalName = url.lastPathComponent
                
                // For images, use ImageManager; for other files, copy to Documents directory
                let destinationURL: URL
                if let image = UIImage(data: data) {
                    destinationURL = try await imageManager.saveImage(image, id: attachmentId)
                } else {
                    // Copy to Documents directory for non-image files
                    guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        throw NSError(domain: "InventoryDetailViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot access documents directory"])
                    }
                    destinationURL = documentsURL.appendingPathComponent(attachmentId + "." + url.pathExtension)
                    try data.write(to: destinationURL)
                }
                
                item.addAttachment(url: destinationURL.absoluteString, originalName: originalName)
                do {
                    try modelContext.save()
                    print("✅ Successfully saved attachment: \(originalName)")
                } catch {
                    print("❌ Failed to save attachment: \(error)")
                }
            } catch {
                print("Failed to save attachment file: \(error)")
            }
            
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }
    
    @MainActor
    func deleteAttachment(_ urlString: String, for item: InventoryItem) async {
        guard URL(string: urlString) != nil else { return }
        
        do {
            // Delete from storage
            try await imageManager.deleteSecondaryImage(urlString: urlString)
            
            item.removeAttachment(url: urlString)
            try? modelContext.save()
        } catch {
            print("Error deleting attachment: \(error)")
        }
    }
    
    func confirmDeleteAttachment(url: String) {
        attachmentToDelete = url
        showingDeleteAttachmentAlert = true
    }
    
    @MainActor
    func executeDeleteAttachment(for item: InventoryItem) {
        guard let urlToDelete = attachmentToDelete else { return }
        Task {
            await deleteAttachment(urlToDelete, for: item)
        }
        attachmentToDelete = nil
    }
    
    func openFileViewer(url: String, fileName: String? = nil) {
        guard let fileURL = URL(string: url) else { return }
        fileViewerURL = fileURL
        fileViewerName = fileName
        showingFileViewer = true
    }
    
    // MARK: - Data Parsing Helpers
    
    @MainActor
    private func parseDimensions(_ dimensionsString: String, for item: InventoryItem) {
        // Parse formats like "9.4" x 6.6" x 0.29"" or "12 x 8 x 4 inches"
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
            if dimensionsString.contains("\"") || dimensionsString.lowercased().contains("inch") {
                item.dimensionUnit = "inches"
            } else if dimensionsString.lowercased().contains("cm") {
                item.dimensionUnit = "cm"
            } else if dimensionsString.lowercased().contains("feet") || dimensionsString.lowercased().contains("ft") {
                item.dimensionUnit = "feet"
            } else if dimensionsString.lowercased().contains("m") && !dimensionsString.lowercased().contains("cm") {
                item.dimensionUnit = "m"
            } else {
                item.dimensionUnit = "inches" // default
            }
        }
    }
    
    @MainActor
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
                item.weightUnit = "lbs" // default for "lbs", "lb", "pounds", etc.
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
    
    // MARK: - Photo Picker Helpers
    
    @MainActor
    func processSelectedPhotos(_ items: [PhotosPickerItem], for inventoryItem: InventoryItem) async {
        guard !items.isEmpty else { return }

        await withTaskGroup(of: UIImage?.self) { group in
            for item in items {
                group.addTask {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        return image
                    }
                    return nil
                }
            }

            var images: [UIImage] = []
            for await image in group {
                if let image = image {
                    images.append(image)
                }
            }

            if !images.isEmpty {
                await handleNewPhotos(images, for: inventoryItem)
            }
        }
    }

    // MARK: - App Store Review

    @MainActor
    private func requestAppReview() {
        // Delay review request by 2 seconds to let user glance at results
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            TelemetryManager.shared.trackAppReviewRequested()
            if #available(iOS 18.0, *) {
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    AppStore.requestReview(in: scene)
                    print("📱 Requested app review using AppStore API")
                }
            } else {
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                    print("📱 Requested app review using legacy API")
                }
            }
        }
    }
}

// MARK: - Image Manager Wrapper

// Wrapper to make OptimizedImageManager conform to our protocol
struct OptimizedImageManagerWrapper: ImageManagerProtocol {
    private let manager = OptimizedImageManager.shared
    
    func saveImage(_ image: UIImage, id: String) async throws -> URL {
        return try await manager.saveImage(image, id: id)
    }
    
    func saveSecondaryImages(_ images: [UIImage], itemId: String) async throws -> [String] {
        return try await manager.saveSecondaryImages(images, itemId: itemId)
    }
    
    func loadImage(url: URL) async throws -> UIImage {
        return try await manager.loadImage(url: url)
    }
    
    func loadSecondaryImages(from urls: [String]) async throws -> [UIImage] {
        return try await manager.loadSecondaryImages(from: urls)
    }
    
    func deleteSecondaryImage(urlString: String) async throws {
        try await manager.deleteSecondaryImage(urlString: urlString)
    }
    
    func prepareImageForAI(from image: UIImage) async -> String? {
        return await manager.prepareImageForAI(from: image)
    }
    
    func getThumbnailURL(for id: String) -> URL? {
        return manager.getThumbnailURL(for: id)
    }
}
