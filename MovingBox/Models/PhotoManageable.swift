import PhotosUI
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

@MainActor
protocol PhotoManageable: AnyObject {
    var imageURL: URL? { get set }
    var secondaryPhotoURLs: [String] { get set }
    var photo: UIImage? { get async throws }
    var thumbnail: UIImage? { get async throws }
    var secondaryPhotos: [UIImage] { get async throws }
    var secondaryThumbnails: [UIImage] { get async }
    var allPhotos: [UIImage] { get async throws }
}

// Default implementation for SwiftData models
extension PhotoManageable {
    var photo: UIImage? {
        get async throws {
            guard let imageURL else { return nil }

            // First try to load from the URL directly
            if let image = try? await OptimizedImageManager.shared.loadImage(url: imageURL) {
                return image
            }

            // If the file doesn't exist at the original path, try loading using the ID
            let id = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")

            // Reconstruct the URL using OptimizedImageManager
            let newURL = OptimizedImageManager.shared.getImageURL(for: id)
            if let image = try? await OptimizedImageManager.shared.loadImage(url: newURL) {
                // Update the stored URL to the correct path
                self.imageURL = newURL
                return image
            }

            return nil
        }
    }

    var thumbnail: UIImage? {
        get async throws {
            guard let imageURL else { return nil }
            return try await OptimizedImageManager.shared.loadThumbnail(for: imageURL)
        }
    }

    var secondaryPhotos: [UIImage] {
        get async throws {
            guard !secondaryPhotoURLs.isEmpty else { return [] }
            return try await OptimizedImageManager.shared.loadSecondaryImages(from: secondaryPhotoURLs)
        }
    }

    var secondaryThumbnails: [UIImage] {
        get async {
            guard !secondaryPhotoURLs.isEmpty else { return [] }
            return await OptimizedImageManager.shared.loadSecondaryThumbnails(from: secondaryPhotoURLs)
        }
    }

    var allPhotos: [UIImage] {
        get async throws {
            var photos: [UIImage] = []

            // Add primary photo if it exists
            if let primaryPhoto = try await photo {
                photos.append(primaryPhoto)
            }

            // Add secondary photos
            let secondaryImages = try await secondaryPhotos
            photos.append(contentsOf: secondaryImages)

            return photos
        }
    }
}
