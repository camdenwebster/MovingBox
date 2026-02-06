import Foundation
import PhotosUI
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

final class OptimizedImageManager {
    static let shared = OptimizedImageManager()
    private let fileManager = FileManager.default
    private let cache = NSCache<NSString, UIImage>()
    private let fileCoordinator = NSFileCoordinator()

    // Allow customizable directory for testing
    private let customImagesDirectory: URL?

    // Make internal for testing
    internal var imagesDirectoryURL: URL {
        if let customDirectory = customImagesDirectory {
            return customDirectory
        }

        guard
            let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Images")
        else {
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
        static let aiHighQualityMaxDimension: CGFloat = 1250
    }

    private init() {
        self.customImagesDirectory = nil
        setupImageDirectory()
        cache.countLimit = 100
        // Limit cache to ~50MB to prevent excessive memory usage
        cache.totalCostLimit = 50 * 1024 * 1024
        setupUbiquityURLMonitoring()
        setupMemoryWarningObserver()
    }

    // Internal initializer for testing with custom directory
    internal init(testDirectory: URL) {
        self.customImagesDirectory = testDirectory
        setupImageDirectory()
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
        // Skip ubiquity and memory monitoring for test instances
    }

    private func setupImageDirectory() {
        if !fileManager.fileExists(atPath: imagesDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
                print("📸 OptimizedImageManager - Created images directory at: \(imagesDirectoryURL)")
            } catch {
                print(
                    "📸 OptimizedImageManager - ERROR creating images directory: \(error.localizedDescription)"
                )
                print("📸 OptimizedImageManager - Attempted path: \(imagesDirectoryURL.path)")
            }
        }
    }

    private func setupMemoryWarningObserver() {
        #if canImport(UIKit)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didReceiveMemoryWarning),
                name: UIApplication.didReceiveMemoryWarningNotification,
                object: nil
            )
        #endif
    }

    @objc private func didReceiveMemoryWarning(_ notification: Notification) {
        clearCache()
        print("📸 OptimizedImageManager - Cleared image cache due to memory warning")
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
            let uiImage = UIImage(data: imageData)
        else {
            return nil
        }

        let optimizedImage = await optimizeImage(uiImage)
        guard let compressedData = optimizedImage.jpegData(compressionQuality: ImageConfig.jpegQuality)
        else {
            return nil
        }
        return compressedData
    }

    // MARK: - Image Saving and Loading

    func saveImage(_ image: UIImage, id: String) async throws -> URL {
        // Ensure directory exists before attempting to save
        if !fileManager.fileExists(atPath: imagesDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
                print("📸 OptimizedImageManager - Created images directory at: \(imagesDirectoryURL)")
            } catch {
                print(
                    "📸 OptimizedImageManager - CRITICAL: Failed to create images directory: \(error.localizedDescription)"
                )
                throw error
            }
        }

        let imageURL = imagesDirectoryURL.appendingPathComponent("\(id).jpg")

        let optimizedImage = await optimizeImage(image)
        guard let data = optimizedImage.jpegData(compressionQuality: ImageConfig.jpegQuality) else {
            throw ImageError.compressionFailed
        }

        var error: NSError?
        fileCoordinator.coordinate(writingItemAt: imageURL, options: .forReplacing, error: &error) {
            url in
            do {
                try data.write(to: url)
                let megabytes = Double(data.count) / 1_000_000.0
                print(
                    "📸 OptimizedImageManager - Saving image (size: \(String(format: "%.2f", megabytes))MB) to: \(url)"
                )
            } catch {
                print("📸 OptimizedImageManager - Error saving image: \(error.localizedDescription)")
            }
        }

        if let error {
            throw error
        }

        // Ensure thumbnail is saved before returning to prevent race conditions
        await saveThumbnail(optimizedImage, id: id)
        return imageURL
    }

    func loadImage(url: URL) async throws -> UIImage {
        guard await ensureUbiquitousItemAvailable(at: url) else {
            throw ImageError.iCloudNotAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var coordinationError: NSError?
                var readError: NSError?
                var loadedImage: UIImage?

                self.fileCoordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
                    do {
                        let data = try Data(contentsOf: url)
                        loadedImage = UIImage(data: data)
                    } catch let error {
                        print("📸 OptimizedImageManager - Error loading image: \(error.localizedDescription)")
                        readError = error as NSError
                    }
                }

                if let coordinationError {
                    continuation.resume(throwing: coordinationError)
                    return
                }

                if let readError {
                    continuation.resume(throwing: readError)
                    return
                }

                guard let image = loadedImage else {
                    continuation.resume(throwing: ImageError.invalidImageData)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Multiple Image Management

    func saveSecondaryImages(_ images: [UIImage], itemId: String) async throws -> [String] {
        var savedURLs: [String] = []

        for (index, image) in images.enumerated() {
            let secondaryId = "\(itemId)_secondary_\(index)_\(UUID().uuidString.prefix(8))"
            let imageURL = try await saveImage(image, id: secondaryId)
            savedURLs.append(imageURL.absoluteString)
        }

        print("📸 OptimizedImageManager - Saved \(savedURLs.count) secondary images for item: \(itemId)")
        return savedURLs
    }

    func addSecondaryImage(_ image: UIImage, itemId: String) async throws -> String {
        let secondaryId = "\(itemId)_secondary_\(UUID().uuidString.prefix(8))"
        let imageURL = try await saveImage(image, id: secondaryId)

        print("📸 OptimizedImageManager - Added secondary image for item: \(itemId)")
        return imageURL.absoluteString
    }

    func loadSecondaryImages(from urlStrings: [String]) async throws -> [UIImage] {
        var images: [UIImage] = []

        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            do {
                let image = try await loadImage(url: url)
                images.append(image)
            } catch {
                print(
                    "📸 OptimizedImageManager - Failed to load secondary image from \(urlString): \(error)")
                continue
            }
        }

        return images
    }

    func deleteSecondaryImage(urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw ImageError.invalidImageData
        }

        // For test environments, bypass NSFileCoordinator to avoid hanging
        if isRunningTests() {
            do {
                try fileManager.removeItem(at: url)
                print("📸 OptimizedImageManager - Deleted secondary image: \(url)")
            } catch {
                print(
                    "📸 OptimizedImageManager - Error deleting secondary image: \(error.localizedDescription)")
                throw error
            }
        } else {
            var error: NSError?
            fileCoordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &error) { url in
                do {
                    try fileManager.removeItem(at: url)
                    print("📸 OptimizedImageManager - Deleted secondary image: \(url)")
                } catch {
                    print(
                        "📸 OptimizedImageManager - Error deleting secondary image: \(error.localizedDescription)"
                    )
                }
            }

            if let error {
                throw error
            }
        }

        // Also delete thumbnail if it exists
        let imageId = url.deletingPathExtension().lastPathComponent
        let thumbnailURL = imagesDirectoryURL.appendingPathComponent("Thumbnails/\(imageId)_thumb.jpg")
        if fileManager.fileExists(atPath: thumbnailURL.path) {
            try? fileManager.removeItem(at: thumbnailURL)
            cache.removeObject(forKey: "\(imageId)_thumb" as NSString)
        }
    }

    // Helper function to detect test environment
    private func isRunningTests() -> Bool {
        return NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.arguments.contains { $0.contains("xctest") }
            || customImagesDirectory != nil  // Test instances use custom directories
    }

    func prepareMultipleImagesForAI(from images: [UIImage]) async -> [String] {
        var base64Images: [String] = []

        for image in images {
            if let base64String = await prepareImageForAI(from: image) {
                base64Images.append(base64String)
            }
        }

        print("📸 OptimizedImageManager - Prepared \(base64Images.count) images for AI analysis")
        return base64Images
    }

    // MARK: - Thumbnail Management

    private func saveThumbnail(_ image: UIImage, id: String) async {
        await Task.detached(priority: .userInitiated) { [self] in
            let thumbnailURL = imagesDirectoryURL.appendingPathComponent("Thumbnails/\(id)_thumb.jpg")

            do {
                try fileManager.createDirectory(
                    at: thumbnailURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            } catch {
                print(
                    "📸 OptimizedImageManager - Error creating thumbnails directory: \(error.localizedDescription)"
                )
                return
            }

            guard let thumbnail = await image.byPreparingThumbnail(ofSize: ImageConfig.thumbnailSize),
                let data = thumbnail.jpegData(compressionQuality: 0.7)
            else { return }

            // Report estimated memory cost for totalCostLimit enforcement
            let estimatedBytes = Int(
                thumbnail.size.width * thumbnail.size.height * thumbnail.scale * thumbnail.scale * 4)
            cache.setObject(thumbnail, forKey: "\(id)_thumb" as NSString, cost: estimatedBytes)

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
        }.value
    }

    func loadThumbnail(id: String) async throws -> UIImage {
        if let cached = cache.object(forKey: "\(id)_thumb" as NSString) {
            return cached
        }

        let thumbnailURL = imagesDirectoryURL.appendingPathComponent("Thumbnails/\(id)_thumb.jpg")

        guard await ensureUbiquitousItemAvailable(at: thumbnailURL) else {
            throw ImageError.iCloudNotAvailable
        }

        let thumbnail = try await loadThumbnailFromDisk(thumbnailURL)
        let cost = Int(thumbnail.size.width * thumbnail.size.height * thumbnail.scale * thumbnail.scale * 4)
        cache.setObject(thumbnail, forKey: "\(id)_thumb" as NSString, cost: cost)
        return thumbnail
    }

    func loadThumbnail(for imageURL: URL) async throws -> UIImage {
        let id = imageURL.deletingPathExtension().lastPathComponent
        if let cached = cache.object(forKey: "\(id)_thumb" as NSString) {
            return cached
        }

        let thumbnailURL = imagesDirectoryURL.appendingPathComponent("Thumbnails/\(id)_thumb.jpg")

        if await ensureUbiquitousItemAvailable(at: thumbnailURL) {
            do {
                let thumbnail = try await loadThumbnailFromDisk(thumbnailURL)
                let cost = Int(thumbnail.size.width * thumbnail.size.height * thumbnail.scale * thumbnail.scale * 4)
                cache.setObject(thumbnail, forKey: "\(id)_thumb" as NSString, cost: cost)
                return thumbnail
            } catch {
                // Fall through to regeneration attempt below.
            }
        }

        // If the thumbnail is missing, regenerate it from the full-size image.
        guard await ensureUbiquitousItemAvailable(at: imageURL) else {
            throw ImageError.iCloudNotAvailable
        }

        return try await Task.detached(priority: .userInitiated) { [self] in
            let fullImage = try await loadImage(url: imageURL)
            await saveThumbnail(fullImage, id: id)

            if let cached = cache.object(forKey: "\(id)_thumb" as NSString) {
                return cached
            }

            let regenerated = try await loadThumbnailFromDisk(thumbnailURL)
            let cost = Int(regenerated.size.width * regenerated.size.height * regenerated.scale * regenerated.scale * 4)
            cache.setObject(regenerated, forKey: "\(id)_thumb" as NSString, cost: cost)
            return regenerated
        }.value
    }

    private func loadThumbnailFromDisk(_ thumbnailURL: URL) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var coordinationError: NSError?
                var readError: NSError?
                var loadedImage: UIImage?

                self.fileCoordinator.coordinate(
                    readingItemAt: thumbnailURL, options: [], error: &coordinationError
                ) { url in
                    do {
                        let data = try Data(contentsOf: url)
                        loadedImage = UIImage(data: data)
                    } catch let error {
                        print(
                            "📸 OptimizedImageManager - Error loading thumbnail: \(error.localizedDescription)")
                        readError = error as NSError
                    }
                }

                if let coordinationError {
                    continuation.resume(throwing: coordinationError)
                    return
                }

                if let readError {
                    continuation.resume(throwing: readError)
                    return
                }

                guard let thumbnail = loadedImage else {
                    continuation.resume(throwing: ImageError.invalidImageData)
                    return
                }

                continuation.resume(returning: thumbnail)
            }
        }
    }

    func loadSecondaryThumbnails(from urlStrings: [String]) async -> [UIImage] {
        var thumbnails: [UIImage] = []

        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }

            do {
                let thumbnail = try await loadThumbnail(for: url)
                thumbnails.append(thumbnail)
            } catch {
                print(
                    "📸 OptimizedImageManager - Failed to load thumbnail for \(url.lastPathComponent): \(error)"
                )
                continue
            }
        }

        return thumbnails
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
                #if canImport(UIKit)
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
                #else
                    let resized = image.resized(to: newSize) ?? image
                    continuation.resume(returning: resized)
                #endif
            }
        }
    }

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

    // ADD: Public method to get image URL
    func getImageURL(for id: String) -> URL {
        return imagesDirectoryURL.appendingPathComponent("\(id).jpg")
    }

    func getThumbnailURL(for id: String) -> URL {
        return imagesDirectoryURL.appendingPathComponent("Thumbnails/\(id)_thumb.jpg")
    }

    func isUbiquitousItemDownloading(_ url: URL) -> Bool {
        guard isUbiquitousItem(url) else { return false }
        guard !fileManager.fileExists(atPath: url.path) else { return false }

        let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        if let status = values?.ubiquitousItemDownloadingStatus {
            return status != URLUbiquitousItemDownloadingStatus.current
        }

        return true
    }

    func imageExists(for url: URL?) -> Bool {
        guard let url = url else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    func thumbnailExists(for id: String) -> Bool {
        let thumbnailURL = getThumbnailURL(for: id)
        return fileManager.fileExists(atPath: thumbnailURL.path)
    }

    /// Regenerate thumbnail from existing full-size image
    func regenerateThumbnail(for imageURL: URL) async throws {
        let id = imageURL.deletingPathExtension().lastPathComponent

        // Check if thumbnail already exists
        guard !thumbnailExists(for: id) else {
            print("📸 OptimizedImageManager - Thumbnail already exists for: \(id)")
            return
        }

        // Load the full-size image
        let fullImage = try await loadImage(url: imageURL)

        // Generate and save thumbnail
        await saveThumbnail(fullImage, id: id)
        print("📸 OptimizedImageManager - Regenerated thumbnail for: \(id)")
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    private func ensureUbiquitousItemAvailable(at url: URL) async -> Bool {
        guard isUbiquitousItem(url) else {
            return fileManager.fileExists(atPath: url.path)
        }

        if isUbiquitousItemDownloaded(url) {
            return true
        }

        do {
            try fileManager.startDownloadingUbiquitousItem(at: url)
        } catch {
            print(
                "📸 OptimizedImageManager - Failed to start iCloud download: \(error.localizedDescription)")
            return false
        }

        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if isUbiquitousItemDownloaded(url) {
                return true
            }
        }

        return fileManager.fileExists(atPath: url.path)
    }

    private func isUbiquitousItem(_ url: URL) -> Bool {
        return (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem ?? false
    }

    private func isUbiquitousItemDownloaded(_ url: URL) -> Bool {
        guard isUbiquitousItem(url) else {
            return fileManager.fileExists(atPath: url.path)
        }

        let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        if let status = values?.ubiquitousItemDownloadingStatus {
            return status == URLUbiquitousItemDownloadingStatus.current
        }

        return fileManager.fileExists(atPath: url.path)
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
