import Foundation
import UIKit
import SwiftUI

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
    }
    
    private func setupImageDirectory() {
        guard let baseURL else { return }
        if !fileManager.fileExists(atPath: baseURL.path) {
            try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
    }
    
    func saveImage(_ image: UIImage, id: String) async throws -> URL {
        guard let baseURL else { throw ImageError.invalidBaseURL }
        let imageURL = baseURL.appendingPathComponent("\(id).jpg")
        
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw ImageError.compressionFailed
        }
        
        try data.write(to: imageURL)
        await saveThumbnail(image, id: id)
        return imageURL
    }
    
    private func saveThumbnail(_ image: UIImage, id: String) async {
        guard let baseURL else { return }
        let thumbnailURL = baseURL.appendingPathComponent("\(id)_thumb.jpg")
        
        let size = CGSize(width: 120, height: 120)
        guard let thumbnail = await image.byPreparingThumbnail(ofSize: size) else { return }
        guard let data = thumbnail.jpegData(compressionQuality: 0.7) else { return }
        
        try? data.write(to: thumbnailURL)
        cache.setObject(thumbnail, forKey: "\(id)_thumb" as NSString)
    }
    
    func loadImage(url: URL) async throws -> UIImage {
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw ImageError.invalidImageData
        }
        return image
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
    
    func deleteImage(id: String) {
        guard let baseURL else { return }
        let imageURL = baseURL.appendingPathComponent("\(id).jpg")
        let thumbnailURL = baseURL.appendingPathComponent("\(id)_thumb.jpg")
        
        try? fileManager.removeItem(at: imageURL)
        try? fileManager.removeItem(at: thumbnailURL)
        cache.removeObject(forKey: "\(id)_thumb" as NSString)
    }
    
    enum ImageError: Error {
        case invalidBaseURL
        case compressionFailed
        case invalidImageData
    }
}