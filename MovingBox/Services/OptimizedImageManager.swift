import Foundation
import UIKit
import SwiftUI
import PhotosUI

@MainActor
final class OptimizedImageManager {
    static let shared = OptimizedImageManager()
    private let fileManager = FileManager.default
    private let cache = NSCache<NSString, UIImage>()
    
    private var baseURL: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Images")
    }
    
    private init() {
        setupImageDirectory()
        cache.countLimit = 100 // Limit cache to 100 thumbnails
    }
    
    private func setupImageDirectory() {
        guard let baseURL else { return }
        if !fileManager.fileExists(atPath: baseURL.path) {
            try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Image Loading from PhotosPicker
    
    func loadPhoto(from item: PhotosPickerItem?, quality: CGFloat = 0.8) async throws -> Data? {
        guard let imageData = try await item?.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: imageData),
              let optimizedImage = optimizeImage(uiImage),
              let compressedData = optimizedImage.jpegData(compressionQuality: quality) else {
            return nil
        }
        return compressedData
    }
    
    // MARK: - Image Saving and Loading
    
    func saveImage(_ image: UIImage, id: String) async throws -> URL {
        guard let baseURL else { throw ImageError.invalidBaseURL }
        let imageURL = baseURL.appendingPathComponent("\(id).jpg")
        
        let optimizedImage = optimizeImage(image) ?? image
        guard let data = optimizedImage.jpegData(compressionQuality: 0.8) else {
            throw ImageError.compressionFailed
        }
        
        try data.write(to: imageURL)
        await saveThumbnail(optimizedImage, id: id)
        return imageURL
    }
    
    func loadImage(url: URL) async throws -> UIImage {
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw ImageError.invalidImageData
        }
        return image
    }
    
    // MARK: - Thumbnail Management
    
    private func saveThumbnail(_ image: UIImage, id: String) async {
        guard let baseURL else { return }
        let thumbnailURL = baseURL.appendingPathComponent("\(id)_thumb.jpg")
        
        let size = CGSize(width: 512, height: 512)
        guard let thumbnail = await image.byPreparingThumbnail(ofSize: size) else { return }
        guard let data = thumbnail.jpegData(compressionQuality: 0.7) else { return }
        
        try? data.write(to: thumbnailURL)
        cache.setObject(thumbnail, forKey: "\(id)_thumb" as NSString)
    }
    
    func loadThumbnail(id: String) async throws -> UIImage {
        if let cached = cache.object(forKey: "\(id)_thumb" as NSString) {
            return cached
        }
        
        guard let baseURL else { throw ImageError.invalidBaseURL }
        let thumbnailURL = baseURL.appendingPathComponent("\(id)_thumb.jpg")
        
        let data = try Data(contentsOf: thumbnailURL)
        guard let thumbnail = UIImage(data: data) else {
            throw ImageError.invalidImageData
        }
        
        cache.setObject(thumbnail, forKey: "\(id)_thumb" as NSString)
        return thumbnail
    }
    
    // MARK: - Image Optimization
    
    func optimizeImage(_ image: UIImage) -> UIImage? {
        let maxDimension: CGFloat = 2048 // Max dimension for full-size images
        let currentWidth = image.size.width
        let currentHeight = image.size.height
        
        // Check if resize is needed
        guard currentWidth > maxDimension || currentHeight > maxDimension else {
            return image
        }
        
        let aspectRatio = currentWidth / currentHeight
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        if currentWidth > currentHeight {
            newWidth = maxDimension
            newHeight = maxDimension / aspectRatio
        } else {
            newHeight = maxDimension
            newWidth = maxDimension * aspectRatio
        }
        
        let size = CGSize(width: newWidth, height: newHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    // MARK: - AI Processing
    
    func prepareImageForAI(from image: UIImage) -> String? {
        let optimizedImage = optimizeImage(image) ?? image
        guard let compressedData = optimizedImage.jpegData(compressionQuality: 0.3) else {
            return nil
        }
        return compressedData.base64EncodedString()
    }
    
    // MARK: - Cleanup
    
    func deleteImage(id: String) {
        guard let baseURL else { return }
        let imageURL = baseURL.appendingPathComponent("\(id).jpg")
        let thumbnailURL = baseURL.appendingPathComponent("\(id)_thumb.jpg")
        
        try? fileManager.removeItem(at: imageURL)
        try? fileManager.removeItem(at: thumbnailURL)
        cache.removeObject(forKey: "\(id)_thumb" as NSString)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    enum ImageError: Error {
        case invalidBaseURL
        case compressionFailed
        case invalidImageData
    }
}
