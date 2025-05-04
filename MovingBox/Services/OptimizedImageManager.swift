import Foundation
import UIKit
import SwiftUI
import PhotosUI

final class OptimizedImageManager {
    static let shared = OptimizedImageManager()
    private let fileManager = FileManager.default
    private let cache = NSCache<NSString, UIImage>()
    private let fileCoordinator = NSFileCoordinator()
    
    // Make internal for testing
    internal var imagesDirectoryURL: URL {
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Images") else {
            // Fallback to documents directory if iCloud is not available
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return documentsURL.appendingPathComponent("Images", isDirectory: true)
        }
        return containerURL
    }
    
    private enum ImageConfig {
        static let maxDimension: CGFloat = 2500
        static let jpegQuality: CGFloat = 0.8
        static let thumbnailSize = CGSize(width: 512, height: 512)
        static let aiMaxDimension: CGFloat = 512
    }
    
    private init() {
        setupImageDirectory()
        cache.countLimit = 100
        setupUbiquityURLMonitoring()
    }
    
    private func setupImageDirectory() {
        if !fileManager.fileExists(atPath: imagesDirectoryURL.path) {
            try? fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
            print("📸 OptimizedImageManager - Created images directory at: \(imagesDirectoryURL)")
        }
    }
    
    // ADD: Monitor iCloud URL changes
    private func setupUbiquityURLMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquityIdentityDidChange),
            name: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil
        )
    }
    
    @objc private func ubiquityIdentityDidChange(_ notification: Notification) {
        Task {
            setupImageDirectory()
            clearCache()
        }
    }
    
    // MARK: - Image Loading from PhotosPicker
    
    func loadPhoto(from item: PhotosPickerItem?) async throws -> Data? {
        guard let imageData = try await item?.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: imageData) else {
            return nil
        }
        
        let optimizedImage = await optimizeImage(uiImage)
        guard let compressedData = optimizedImage.jpegData(compressionQuality: ImageConfig.jpegQuality) else {
            return nil
        }
        return compressedData
    }
    
    // MARK: - Image Saving and Loading
    
    func saveImage(_ image: UIImage, id: String) async throws -> URL {
        let imageURL = imagesDirectoryURL.appendingPathComponent("\(id).jpg")
        
        let optimizedImage = await optimizeImage(image)
        guard let data = optimizedImage.jpegData(compressionQuality: ImageConfig.jpegQuality) else {
            throw ImageError.compressionFailed
        }
        
        var error: NSError?
        fileCoordinator.coordinate(writingItemAt: imageURL, options: .forReplacing, error: &error) { url in
            do {
                try data.write(to: url)
                let megabytes = Double(data.count) / 1_000_000.0
                print("📸 OptimizedImageManager - Saving image (size: \(String(format: "%.2f", megabytes))MB) to: \(url)")
            } catch {
                print("📸 OptimizedImageManager - Error saving image: \(error.localizedDescription)")
            }
        }
        
        if let error {
            throw error
        }
        
        await saveThumbnail(optimizedImage, id: id)
        return imageURL
    }
    
    func loadImage(url: URL) async throws -> UIImage {
        var error: NSError?
        var loadedImage: UIImage?
        
        fileCoordinator.coordinate(readingItemAt: url, options: [], error: &error) { url in
            do {
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    loadedImage = image
                }
            } catch {
                print("📸 OptimizedImageManager - Error loading image: \(error.localizedDescription)")
            }
        }
        
        if let error {
            throw error
        }
        
        guard let image = loadedImage else {
            throw ImageError.invalidImageData
        }
        
        return image
    }
    
    // MARK: - Thumbnail Management
    
    private func saveThumbnail(_ image: UIImage, id: String) async {
        let thumbnailURL = imagesDirectoryURL.appendingPathComponent("Thumbnails/\(id)_thumb.jpg")
        
        // Create thumbnails directory if needed
        try? fileManager.createDirectory(at: thumbnailURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        guard let thumbnail = await image.byPreparingThumbnail(ofSize: ImageConfig.thumbnailSize) else { return }
        guard let data = thumbnail.jpegData(compressionQuality: 0.7) else { return }
        
        var error: NSError?
        fileCoordinator.coordinate(writingItemAt: thumbnailURL, options: .forReplacing, error: &error) { url in
            do {
                try data.write(to: url)
            } catch {
                print("📸 OptimizedImageManager - Error saving thumbnail: \(error.localizedDescription)")
            }
        }
        
        if let error {
            print("📸 OptimizedImageManager - Error saving thumbnail: \(error.localizedDescription)")
        }
        
        cache.setObject(thumbnail, forKey: "\(id)_thumb" as NSString)
    }
    
    func loadThumbnail(id: String) async throws -> UIImage {
        if let cached = cache.object(forKey: "\(id)_thumb" as NSString) {
            return cached
        }
        
        let thumbnailURL = imagesDirectoryURL.appendingPathComponent("Thumbnails/\(id)_thumb.jpg")
        
        var error: NSError?
        var loadedImage: UIImage?
        
        fileCoordinator.coordinate(readingItemAt: thumbnailURL, options: [], error: &error) { url in
            do {
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    loadedImage = image
                }
            } catch {
                print("📸 OptimizedImageManager - Error loading thumbnail: \(error.localizedDescription)")
            }
        }
        
        if let error {
            throw error
        }
        
        guard let thumbnail = loadedImage else {
            throw ImageError.invalidImageData
        }
        
        cache.setObject(thumbnail, forKey: "\(id)_thumb" as NSString)
        return thumbnail
    }
    
    // MARK: - Image Optimization
    
    func optimizeImage(_ image: UIImage, maxDimension: CGFloat? = nil) async -> UIImage {
        let originalSize = image.size
        let targetMaxDimension = maxDimension ?? ImageConfig.maxDimension
        
        let widthScale = targetMaxDimension / originalSize.width
        let heightScale = targetMaxDimension / originalSize.height
        let scale = min(1.0, min(widthScale, heightScale))
        
        if scale >= 1.0 {
            return image
        }
        
        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        // Capture value types only
        let imageScale = image.scale
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Create format inside async block to avoid Sendable issues
                let format = UIGraphicsImageRendererFormat()
                format.preferredRange = .standard
                format.scale = imageScale
                
                let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
                let resized = renderer.image { _ in
                    // Draw image in background thread
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                }
                
                continuation.resume(returning: resized)
            }
        }
    }
    
    func prepareImageForAI(from image: UIImage) async -> String? {
        let optimizedImage = await optimizeImage(image, maxDimension: ImageConfig.aiMaxDimension)
        guard let imageData = optimizedImage.jpegData(compressionQuality: ImageConfig.jpegQuality) else {
            return nil
        }
        return imageData.base64EncodedString()
    }
    
    // ADD: Public method to get image URL
    func getImageURL(for id: String) -> URL {
        return imagesDirectoryURL.appendingPathComponent("\(id).jpg")
    }
    
    func imageExists(for url: URL?) -> Bool {
        guard let url = url else { return false }
        return fileManager.fileExists(atPath: url.path)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    enum ImageError: Error {
        case invalidBaseURL
        case compressionFailed
        case invalidImageData
        case iCloudNotAvailable
    }
}
