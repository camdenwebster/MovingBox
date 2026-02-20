import Foundation
import PhotosUI
import SwiftUI
import UIKit

final class OptimizedImageManager: @unchecked Sendable {
    static let shared = OptimizedImageManager()
    private let cache = NSCache<NSString, UIImage>()

    private enum ImageConfig {
        static let maxDimension: CGFloat = 2500
        static let jpegQuality: CGFloat = 0.8
        static let thumbnailSize = CGSize(width: 512, height: 512)
        static let thumbnailQuality: CGFloat = 0.7
        static let aiMaxDimension: CGFloat = 512
        static let aiHighQualityMaxDimension: CGFloat = 1250
    }

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
        setupMemoryWarningObserver()
    }

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func didReceiveMemoryWarning(_ notification: Notification) {
        clearCache()
    }

    // MARK: - Image Loading from PhotosPicker

    func loadPhoto(from item: PhotosPickerItem?) async throws -> Data? {
        guard let imageData = try await item?.loadTransferable(type: Data.self),
            let uiImage = UIImage(data: imageData)
        else {
            return nil
        }
        return await processImage(uiImage)
    }

    // MARK: - Image Processing (UIImage → JPEG Data for DB storage)

    func processImage(_ image: UIImage) async -> Data? {
        let optimizedImage = await optimizeImage(image)
        return optimizedImage.jpegData(compressionQuality: ImageConfig.jpegQuality)
    }

    // MARK: - Thumbnail Generation (from BLOB Data)

    func generateThumbnail(from imageData: Data) async -> UIImage? {
        guard let image = UIImage(data: imageData) else { return nil }
        return await image.byPreparingThumbnail(ofSize: ImageConfig.thumbnailSize)
    }

    func cachedThumbnail(for photoID: String) -> UIImage? {
        cache.object(forKey: photoID as NSString)
    }

    func cacheThumbnail(_ image: UIImage, for photoID: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: photoID as NSString, cost: cost)
    }

    func thumbnailImage(from imageData: Data, photoID: String) async -> UIImage? {
        if let cached = cachedThumbnail(for: photoID) {
            return cached
        }
        guard let thumbnail = await generateThumbnail(from: imageData) else { return nil }
        cacheThumbnail(thumbnail, for: photoID)
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

        let imageScale = image.scale

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let format = UIGraphicsImageRendererFormat()
                format.preferredRange = .standard
                format.scale = imageScale

                let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
                let resized = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                }

                continuation.resume(returning: resized)
            }
        }
    }

    // MARK: - AI Image Preparation

    func prepareImageForAI(from image: UIImage, useHighQuality: Bool = false) async -> String? {
        let maxDimension =
            useHighQuality ? ImageConfig.aiHighQualityMaxDimension : ImageConfig.aiMaxDimension
        let optimizedImage = await optimizeImage(image, maxDimension: maxDimension)
        guard let imageData = optimizedImage.jpegData(compressionQuality: ImageConfig.jpegQuality)
        else {
            return nil
        }
        return imageData.base64EncodedString()
    }

    func prepareMultipleImagesForAI(from images: [UIImage]) async -> [String] {
        var base64Images: [String] = []
        for image in images {
            if let base64String = await prepareImageForAI(from: image) {
                base64Images.append(base64String)
            }
        }
        return base64Images
    }

    // MARK: - Cache Management

    func clearCache() {
        cache.removeAllObjects()
    }

    // MARK: - Video Management

    func saveVideo(_ url: URL) async throws -> URL {
        let videosDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Videos", isDirectory: true)

        if !FileManager.default.fileExists(atPath: videosDirectory.path) {
            try FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        }

        let fileName = "\(UUID().uuidString).\(url.pathExtension)"
        let destinationURL = videosDirectory.appendingPathComponent(fileName)

        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            try FileManager.default.copyItem(at: url, to: destinationURL)
        } else {
            try FileManager.default.copyItem(at: url, to: destinationURL)
        }

        return destinationURL
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    enum ImageError: Error {
        case compressionFailed
        case invalidImageData
    }
}
