import SwiftUI
import UIKit
import PhotosUI

@MainActor
protocol PhotoManageable: AnyObject {
    var imageURL: URL? { get set }  // Keep for backward compatibility
    var imageURLs: [URL] { get set }
    var primaryImageIndex: Int { get set }
    var photo: UIImage? { get async throws }
    var thumbnail: UIImage? { get async throws }
    var primaryImageURL: URL? { get }
}

// Default implementation for SwiftData models
extension PhotoManageable {
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
    
    var primaryImageURL: URL? {
        guard !imageURLs.isEmpty, primaryImageIndex < imageURLs.count else { return nil }
        return imageURLs[primaryImageIndex]
    }
    
    var photo: UIImage? {
        get async throws {
            guard let imageURL = primaryImageURL else { return nil }
            
            // First try to load from the URL directly
            if FileManager.default.fileExists(atPath: imageURL.path),
               let image = try await OptimizedImageManager.shared.loadImage(url: imageURL) {
                return image
            }
            
            // If the file doesn't exist at the original path, try loading using the ID
            let id = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")
            
            // Reconstruct the URL using OptimizedImageManager
            let newURL = OptimizedImageManager.shared.getImageURL(for: id)
            if FileManager.default.fileExists(atPath: newURL.path),
               let image = try await OptimizedImageManager.shared.loadImage(url: newURL) {
                // Update the stored URL to the correct path
                if let index = imageURLs.firstIndex(of: imageURL) {
                    imageURLs[index] = newURL
                }
                return image
            }
            
            return nil
        }
    }
    
    var thumbnail: UIImage? {
        get async throws {
            guard let imageURL = primaryImageURL else { return nil }
            let id = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")
            return try await OptimizedImageManager.shared.loadThumbnail(id: id)
        }
    }
}
