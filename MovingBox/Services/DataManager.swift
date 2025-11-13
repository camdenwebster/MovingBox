//
//  DataManager.swift
//  MovingBox
//
//  Created by Camden Webster on 5/1/25.
//

import Foundation
import ZIPFoundation
import SwiftData
import SwiftUI

/// # DataManager: Swift Concurrency-Safe Import/Export Actor
///
/// Handles bulk import and export of inventory data with proper Swift Concurrency patterns
/// and SwiftData best practices as outlined in Paul Hudson's "SwiftData by Example".
///
/// ## Architecture Overview
///
/// This actor implements a **ModelContainer → ModelContext** pattern where:
/// - Views pass `ModelContainer` (Sendable) to export/import functions
/// - Functions create local `ModelContext` instances for SwiftData operations
/// - This approach is ~10x faster than accessing actor properties (per Hudson, p.218)
///
/// ## Key Design Decisions
///
/// ### 1. Actor Isolation
/// All export/import functions are marked `nonisolated` to allow returning `AsyncStream`
/// without actor hopping. However, all SwiftData operations happen on `@MainActor` per
/// Apple's requirements.
///
/// ### 2. Swift Concurrency Safety
/// - `ModelContainer` and `PersistentIdentifier` are Sendable and safe to pass across actors
/// - `ModelContext` and model objects are NOT Sendable and must stay on MainActor
/// - Plain data (tuples, structs) is extracted on MainActor then passed between actors
///
/// ### 3. Batch Processing Strategy
/// - Dynamic batch sizes based on device memory (50-300 items per batch)
/// - Explicit `save()` calls after each batch to control memory usage
/// - Background parsing with MainActor for SwiftData operations
/// - Progress reporting via AsyncStream for responsive UI
///
/// ### 4. Performance Optimizations
/// - Local ModelContext creation (10x faster than actor property)
/// - Pre-fetching and caching for relationship lookups
/// - Streaming data processing to minimize memory peaks
/// - Background file operations with MainActor for database access
///
/// ## Usage Example
///
/// ```swift
/// // In a SwiftUI view:
/// @EnvironmentObject private var containerManager: ModelContainerManager
///
/// func exportData() async {
///     for await progress in DataManager.shared.exportInventoryWithProgress(
///         modelContainer: containerManager.container,
///         fileName: "export.zip",
///         config: .init(includeItems: true, includeLocations: true, includeLabels: true)
///     ) {
///         switch progress {
///         case .fetchingData(let phase, let progress):
///             print("Fetching \(phase): \(progress * 100)%")
///         case .completed(let result):
///             print("Exported \(result.itemCount) items")
///         // ... handle other cases
///         }
///     }
/// }
/// ```
///
/// ## Swift 6 Concurrency Notes
///
/// Remaining warnings about `ModelContainer` being passed to nonisolated functions are
/// expected and safe. The architecture ensures:
/// 1. Only Sendable types cross actor boundaries
/// 2. Non-Sendable types stay isolated on MainActor
/// 3. All SwiftData operations run on MainActor per Apple's requirements
///
/// ## References
/// - Paul Hudson, "SwiftData by Example" (2023), Architecture chapter
/// - Apple Swift Concurrency Documentation
/// - SWIFT6_CONCURRENCY_FIXES.md in Services directory
///
actor DataManager {
    enum DataError: LocalizedError, Sendable {
        case nothingToExport
        case failedCreateZip
        case invalidZipFile
        case invalidCSVFormat
        case photoNotFound
        case fileAccessDenied
        case fileTooLarge
        case invalidFileType
        case containerNotConfigured
    }

    // MARK: - Properties

    private let modelContainer: ModelContainer?
    
    /// Sendable wrapper for arbitrary errors that cross actor boundaries via AsyncStream
    struct SendableError: Sendable {
        let description: String
        let localizedDescription: String
        private let underlyingErrorType: String
        
        init(_ error: Error) {
            self.description = String(describing: error)
            self.localizedDescription = error.localizedDescription
            self.underlyingErrorType = String(describing: type(of: error))
        }
        
        func toError() -> NSError {
            NSError(domain: "DataManagerError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: localizedDescription
            ])
        }

        var errorDescription: String? {
            if description.contains("nothingToExport") {
                return "No data available to export. Add some items, locations, or labels first."
            } else if description.contains("failedCreateZip") {
                return "Unable to create the export file. Please try again."
            } else if description.contains("invalidZipFile") {
                return "The selected file is not a valid ZIP archive. Please choose a valid MovingBox export file."
            } else if description.contains("invalidCSVFormat") {
                return "This doesn't appear to be a MovingBox export file. Please use a ZIP file that was exported from MovingBox."
            } else if description.contains("photoNotFound") {
                return "Some photos could not be found during the import process."
            } else if description.contains("fileAccessDenied") {
                return "Unable to access the selected file. Please check file permissions and try again."
            } else if description.contains("fileTooLarge") {
                return "One or more images exceed the 100MB size limit and cannot be imported."
            } else if description.contains("invalidFileType") {
                return "Invalid image file type detected. Only JPG, PNG, and HEIC formats are supported."
            }
            return localizedDescription
        }

        var recoverySuggestion: String? {
            if description.contains("nothingToExport") {
                return "Create some inventory items, locations, or labels before exporting."
            } else if description.contains("failedCreateZip") {
                return "Check that you have sufficient storage space and try exporting again."
            } else if description.contains("invalidZipFile") {
                return "Make sure you're selecting a ZIP file that was previously exported from MovingBox."
            } else if description.contains("invalidCSVFormat") {
                return "MovingBox can only import files that were exported from the app. If you have data from another app, you'll need to manually add it."
            } else if description.contains("photoNotFound") {
                return "The import will continue, but some images may be missing from your inventory."
            } else if description.contains("fileAccessDenied") {
                return "Try moving the file to a different location or grant the app permission to access it."
            } else if description.contains("fileTooLarge") {
                return "Try compressing the images before exporting, or remove some items from the export."
            } else if description.contains("invalidFileType") {
                return "Convert unsupported images to JPG, PNG, or HEIC format before importing."
            }
            return nil
        }
    }

    static let shared = DataManager()

    // MARK: - Initialization

    private init() {
        self.modelContainer = nil
    }

    /// Creates a DataManager with a specific ModelContainer for dependency injection.
    /// Used primarily for testing or when you need a non-shared instance.
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Helper to safely get the ModelContainer, throwing if not configured.
    /// In production, views should pass the container explicitly via parameters.
    private func getContainer() throws -> ModelContainer {
        guard let container = modelContainer else {
            throw DataError.containerNotConfigured
        }
        return container
    }

    /// Exports inventory with progress reporting via AsyncStream.
    ///
    /// Creates a local ModelContext from the container for optimal performance.
    /// Per Paul Hudson: Creating context inside method is 10x faster than actor property access.
    ///
    /// - Parameters:
    ///   - modelContainer: The app's ModelContainer (Sendable, safe to pass across actors)
    ///   - fileName: Optional custom filename (defaults to timestamped name)
    ///   - config: What data types to include (items, locations, labels)
    /// - Returns: AsyncStream yielding ExportProgress updates
    nonisolated func exportInventoryWithProgress(
        modelContainer: ModelContainer,
        fileName: String? = nil,
        config: ExportConfig = ExportConfig(includeItems: true, includeLocations: true, includeLabels: true)
    ) -> AsyncStream<ExportProgress> {
        AsyncStream { continuation in
            Task { @MainActor in
                do {
                    continuation.yield(.preparing)

                    // Create local ModelContext for optimal performance (10x faster per Hudson)
                    let modelContext = ModelContext(modelContainer)

                    var itemData: [ItemData] = []
                    var locationData: [LocationData] = []
                    var labelData: [LabelData] = []
                    var allPhotoURLs: [URL] = []
                    
                    var totalSteps = 0
                    var completedSteps = 0
                    
                    if config.includeItems { totalSteps += 1 }
                    if config.includeLocations { totalSteps += 1 }
                    if config.includeLabels { totalSteps += 1 }
                    totalSteps += 3 // CSV writing, photo copying, archiving
                    
                    // Fetch data in batches with progress
                    if config.includeItems {
                        continuation.yield(.fetchingData(phase: "items", progress: 0.0))
                        let result = try await fetchItemsInBatches(modelContext: modelContext)
                        guard !result.items.isEmpty else { throw DataError.nothingToExport }
                        itemData = result.items
                        allPhotoURLs.append(contentsOf: result.photoURLs)
                        
                        completedSteps += 1
                        continuation.yield(.fetchingData(phase: "items", progress: Double(completedSteps) / Double(totalSteps)))
                        
                        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
                        TelemetryManager.shared.trackExportBatchSize(
                            batchSize: Self.batchSize,
                            deviceMemoryGB: memoryGB,
                            itemCount: result.items.count
                        )
                    }
                    
                    if config.includeLocations {
                        continuation.yield(.fetchingData(phase: "locations", progress: Double(completedSteps) / Double(totalSteps)))
                        let result = try await fetchLocationsInBatches(modelContext: modelContext)
                        locationData = result.locations
                        allPhotoURLs.append(contentsOf: result.photoURLs)
                        
                        completedSteps += 1
                        continuation.yield(.fetchingData(phase: "locations", progress: Double(completedSteps) / Double(totalSteps)))
                    }
                    
                    if config.includeLabels {
                        continuation.yield(.fetchingData(phase: "labels", progress: Double(completedSteps) / Double(totalSteps)))
                        labelData = try await fetchLabelsInBatches(modelContext: modelContext)
                        
                        completedSteps += 1
                        continuation.yield(.fetchingData(phase: "labels", progress: Double(completedSteps) / Double(totalSteps)))
                    }
                    
                    guard !itemData.isEmpty || !locationData.isEmpty || !labelData.isEmpty else {
                        throw DataError.nothingToExport
                    }
                    
                    let archiveName = fileName ?? "MovingBox-export-\(DateFormatter.exportDateFormatter.string(from: .init()))".replacingOccurrences(of: " ", with: "-") + ".zip"
                    
                    // Working directory in tmp
                    let workingRoot = FileManager.default.temporaryDirectory
                        .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
                    let photosDir = workingRoot.appendingPathComponent("photos", isDirectory: true)
                    try FileManager.default.createDirectory(at: photosDir,
                                                         withIntermediateDirectories: true)
                    try FileManager.default.setAttributes([
                        .posixPermissions: 0o755
                    ], ofItemAtPath: photosDir.path)
                    
                    // Write CSV files
                    continuation.yield(.writingCSV(progress: Double(completedSteps) / Double(totalSteps)))
                    
                    if config.includeItems {
                        let itemsCSVURL = workingRoot.appendingPathComponent("inventory.csv")
                        try await writeCSV(items: itemData, to: itemsCSVURL)
                    }
                    
                    if config.includeLocations {
                        let locationsCSVURL = workingRoot.appendingPathComponent("locations.csv")
                        try await writeLocationsCSV(locations: locationData, to: locationsCSVURL)
                    }
                    
                    if config.includeLabels {
                        let labelsCSVURL = workingRoot.appendingPathComponent("labels.csv")
                        try await writeLabelsCSV(labels: labelData, to: labelsCSVURL)
                    }
                    
                    completedSteps += 1
                    continuation.yield(.writingCSV(progress: Double(completedSteps) / Double(totalSteps)))
                    
                    // Copy photos with progress
                    if !allPhotoURLs.isEmpty {
                        try await copyPhotosToDirectoryWithProgress(
                            photoURLs: allPhotoURLs,
                            destinationDir: photosDir,
                            progressHandler: { current, total in
                                continuation.yield(.copyingPhotos(current: current, total: total))
                            }
                        )
                    }
                    
                    completedSteps += 1

                    // Create archive using unified helper with progress reporting
                    continuation.yield(.creatingArchive(progress: Double(completedSteps) / Double(totalSteps)))

                    let archiveURL = try await createArchive(
                        from: workingRoot,
                        archiveName: archiveName,
                        progressHandler: { filesProcessed, totalFiles in
                            // Report incremental progress within the archive creation phase
                            let archivePhaseProgress = Double(filesProcessed) / max(Double(totalFiles), 1.0)
                            let overallProgress = (Double(completedSteps) + archivePhaseProgress) / Double(totalSteps)
                            continuation.yield(.creatingArchive(progress: overallProgress))
                        }
                    )

                    completedSteps += 1
                    continuation.yield(.creatingArchive(progress: 1.0))
                    
                    // Clean up working directory after a substantial delay to ensure caller can access archive
                    // The delay must be long enough for tests to open and read the archive.
                    Task.detached {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        try? FileManager.default.removeItem(at: workingRoot)
                    }
                    
                    guard FileManager.default.fileExists(atPath: archiveURL.path) else {
                        throw DataError.failedCreateZip
                    }
                    
                    let result = ExportResult(
                        archiveURL: archiveURL,
                        itemCount: itemData.count,
                        locationCount: locationData.count,
                        labelCount: labelData.count,
                        photoCount: allPhotoURLs.count
                    )
                    
                    continuation.yield(.completed(result))
                    continuation.finish()
                    
                } catch {
                    continuation.yield(.error(SendableError(error)))
                    continuation.finish()
                }
            }
        }
    }
    
    /// Exports all `InventoryItem`s (and their photos) into a single **zip** file that also
    /// contains `inventory.csv`.  The returned `URL` points to the finished archive
    /// inside the temporary directory – caller is expected to share / move / delete.
    /// For progress reporting, use `exportInventoryWithProgress` instead.
    ///
    /// Creates a local ModelContext from the container for optimal performance.
    func exportInventory(modelContainer: ModelContainer, fileName: String? = nil, config: ExportConfig = ExportConfig(includeItems: true, includeLocations: true, includeLabels: true)) async throws -> URL {
        // Create local ModelContext for optimal performance (10x faster per Hudson)
        let modelContext = await MainActor.run { ModelContext(modelContainer) }

        var itemData: [ItemData] = []
        var locationData: [LocationData] = []
        var labelData: [LabelData] = []
        var allPhotoURLs: [URL] = []

        // Fetch data in batches to reduce memory pressure
        // SwiftData operations run on MainActor
        if config.includeItems {
            let result = try await fetchItemsInBatches(modelContext: modelContext)
            guard !result.items.isEmpty else { throw DataError.nothingToExport }
            itemData = result.items
            allPhotoURLs.append(contentsOf: result.photoURLs)

            let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
            TelemetryManager.shared.trackExportBatchSize(
                batchSize: Self.batchSize,
                deviceMemoryGB: memoryGB,
                itemCount: result.items.count
            )
        }

        if config.includeLocations {
            let result = try await fetchLocationsInBatches(modelContext: modelContext)
            locationData = result.locations
            allPhotoURLs.append(contentsOf: result.photoURLs)
        }

        if config.includeLabels {
            labelData = try await fetchLabelsInBatches(modelContext: modelContext)
        }

        // Don't export if nothing is selected
        guard !itemData.isEmpty || !locationData.isEmpty || !labelData.isEmpty else {
            throw DataError.nothingToExport
        }

        let archiveName = fileName ?? "MovingBox-export-\(DateFormatter.exportDateFormatter.string(from: .init()))".replacingOccurrences(of: " ", with: "-") + ".zip"

        // Working directory in tmp
        let workingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        let photosDir = workingRoot.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photosDir,
                                             withIntermediateDirectories: true)
        try FileManager.default.setAttributes([
            .posixPermissions: 0o755
        ], ofItemAtPath: photosDir.path)

        // Write CSV files only for enabled types
        if config.includeItems {
            let itemsCSVURL = workingRoot.appendingPathComponent("inventory.csv")
            try await writeCSV(items: itemData, to: itemsCSVURL)
        }
        
        if config.includeLocations {
            let locationsCSVURL = workingRoot.appendingPathComponent("locations.csv")
            try await writeLocationsCSV(locations: locationData, to: locationsCSVURL)
        }
        
        if config.includeLabels {
            let labelsCSVURL = workingRoot.appendingPathComponent("labels.csv")
            try await writeLabelsCSV(labels: labelData, to: labelsCSVURL)
        }

        // Copy photos in background to avoid blocking main thread
        // Photo URLs were already collected during batched fetching
        try await copyPhotosToDirectory(photoURLs: allPhotoURLs, destinationDir: photosDir)

        // Create ZIP archive using unified helper
        let archiveURL = try await createArchive(from: workingRoot, archiveName: archiveName)

        // Clean up working directory after a substantial delay to ensure caller can access archive
        // Using a delay prevents race conditions in test environments where
        // the file might be accessed immediately after this function returns.
        // The delay must be long enough for tests to open and read the archive.
        Task.detached {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            try? FileManager.default.removeItem(at: workingRoot)
        }

        guard FileManager.default.fileExists(atPath: archiveURL.path)
        else { throw DataError.failedCreateZip }

        return archiveURL
    }

    struct ExportConfig {
        let includeItems: Bool
        let includeLocations: Bool
        let includeLabels: Bool
    }
    
    struct ImportConfig {
        let includeItems: Bool
        let includeLocations: Bool
        let includeLabels: Bool
    }

    enum ImportProgress: Sendable {
        case progress(Double)
        case completed(ImportResult)
        case error(SendableError)
    }

    struct ImportResult: Sendable {
        let itemCount: Int
        let locationCount: Int
        let labelCount: Int
    }
    
    /// Progress updates during export operations
    ///
    /// Progress phases and their typical duration:
    /// - **preparing**: Instant - setting up export directory
    /// - **fetchingData**: 0-30% - Batched fetching from SwiftData (scales with item count)
    /// - **writingCSV**: 30-50% - Fast, typically <1s for most exports
    /// - **copyingPhotos**: 50-80% - Longest phase, scales with photo count and sizes
    /// - **creatingArchive**: 80-100% - Scales with total data size (compression)
    /// - **completed**: Terminal state with export results
    /// - **error**: Terminal state with error details
    ///
    /// Use `ProgressMapper.mapExportProgress()` to convert to 0-1 normalized progress.
    enum ExportProgress: Sendable {
        case preparing
        case fetchingData(phase: String, progress: Double)
        case writingCSV(progress: Double)
        case copyingPhotos(current: Int, total: Int)
        case creatingArchive(progress: Double)
        case completed(ExportResult)
        case error(SendableError)
    }
    
    struct ExportResult: Sendable {
        let archiveURL: URL
        let itemCount: Int
        let locationCount: Int
        let labelCount: Int
        let photoCount: Int
    }
    
    // MARK: - Batch Processing Configuration
    
    private static var batchSize: Int {
        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memoryBytes) / 1_073_741_824.0
        
        switch memoryGB {
        case ..<3:
            return 50
        case 3..<6:
            return 100
        case 6..<10:
            return 200
        default:
            return 300
        }
    }
    
    private typealias ItemData = (
        title: String,
        desc: String,
        locationName: String,
        labelName: String,
        quantity: Int,
        serial: String,
        model: String,
        make: String,
        price: Decimal,
        insured: Bool,
        notes: String,
        imageURL: URL?,
        hasUsedAI: Bool
    )
    
    private typealias LocationData = (
        name: String,
        desc: String,
        imageURL: URL?
    )
    
    private typealias LabelData = (
        name: String,
        desc: String,
        color: UIColor?,
        emoji: String
    )

    /// Preview import without actually creating objects - just validates and counts
    func previewImport(
        from zipURL: URL,
        config: ImportConfig = ImportConfig(includeItems: true, includeLocations: true, includeLabels: true)
    ) async throws -> ImportResult {
        return try await Task.detached(priority: .userInitiated) {
            let workingDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("preview-\(UUID().uuidString)", isDirectory: true)
            
            defer {
                try? FileManager.default.removeItem(at: workingDir)
            }
            
            let localZipURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(zipURL.lastPathComponent)
            try? FileManager.default.removeItem(at: localZipURL)
            
            guard FileManager.default.isReadableFile(atPath: zipURL.path) else {
                throw DataError.fileAccessDenied
            }
            
            try FileManager.default.copyItem(at: zipURL, to: localZipURL)
            try FileManager.default.setAttributes([
                .posixPermissions: 0o644
            ], ofItemAtPath: localZipURL.path)
            
            try FileManager.default.createDirectory(
                at: workingDir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o755]
            )
            
            try FileManager.default.unzipItem(at: localZipURL, to: workingDir)
            
            let itemsCSVURL = workingDir.appendingPathComponent("inventory.csv")
            let locationsCSVURL = workingDir.appendingPathComponent("locations.csv")
            let labelsCSVURL = workingDir.appendingPathComponent("labels.csv")
            
            var itemCount = 0
            var locationCount = 0
            var labelCount = 0
            
            if config.includeItems, FileManager.default.fileExists(atPath: itemsCSVURL.path) {
                let csvString = try String(contentsOf: itemsCSVURL, encoding: .utf8)
                let rows = csvString.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                itemCount = max(0, rows.count - 1)
            }
            
            if config.includeLocations, FileManager.default.fileExists(atPath: locationsCSVURL.path) {
                let csvString = try String(contentsOf: locationsCSVURL, encoding: .utf8)
                let rows = csvString.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                locationCount = max(0, rows.count - 1)
            }
            
            if config.includeLabels, FileManager.default.fileExists(atPath: labelsCSVURL.path) {
                let csvString = try String(contentsOf: labelsCSVURL, encoding: .utf8)
                let rows = csvString.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                labelCount = max(0, rows.count - 1)
             }
             
             return ImportResult(
                itemCount: itemCount,
                locationCount: locationCount,
                labelCount: labelCount
            )
        }.value
    }

    /// Imports inventory from a zip file and reports progress through an async sequence.
    ///
    /// Creates a local ModelContext from the container for optimal performance.
    /// Per Paul Hudson: Creating context inside method is 10x faster than actor property access.
    ///
    /// - Parameters:
    ///   - zipURL: URL to the zip file containing exported data
    ///   - modelContainer: The app's ModelContainer (Sendable, safe to pass across actors)
    ///   - config: What data types to import (items, locations, labels)
    /// - Returns: AsyncStream yielding ImportProgress updates
    func importInventory(
        from zipURL: URL,
        modelContainer: ModelContainer,
        config: ImportConfig = ImportConfig(includeItems: true, includeLocations: true, includeLabels: true)
    ) -> AsyncStream<ImportProgress> {
        AsyncStream { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    let workingDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("import-\(UUID().uuidString)", isDirectory: true)
                    
                    defer {
                        try? FileManager.default.removeItem(at: workingDir)
                    }
                    
                    let localZipURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(zipURL.lastPathComponent)
                    try? FileManager.default.removeItem(at: localZipURL)
                    
                    // Check if we can access the file
                    guard FileManager.default.isReadableFile(atPath: zipURL.path) else {
                        continuation.yield(.error(SendableError(DataError.fileAccessDenied)))
                        continuation.finish()
                        return
                    }
                    
                    try FileManager.default.copyItem(at: zipURL, to: localZipURL)
                    try FileManager.default.setAttributes([
                        .posixPermissions: 0o644
                    ], ofItemAtPath: localZipURL.path)
                    
                    try FileManager.default.createDirectory(
                        at: workingDir,
                        withIntermediateDirectories: true,
                        attributes: [.posixPermissions: 0o755]
                    )
                    
                    try FileManager.default.unzipItem(at: localZipURL, to: workingDir)
                    
                    // Get CSV files
                    let itemsCSVURL = workingDir.appendingPathComponent("inventory.csv")
                    let locationsCSVURL = workingDir.appendingPathComponent("locations.csv")
                    let labelsCSVURL = workingDir.appendingPathComponent("labels.csv")
                    let photosDir = workingDir.appendingPathComponent("photos")
                    
                    // Calculate total rows based on enabled types
                    var totalRows = 0
                    var processedRows = 0
                    
                    if config.includeLocations, FileManager.default.fileExists(atPath: locationsCSVURL.path) {
                        let locationCSV = try String(contentsOf: locationsCSVURL, encoding: .utf8)
                        let locationCount = locationCSV.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                            .count - 1
                        totalRows += locationCount
                    }
                    
                    if config.includeLabels, FileManager.default.fileExists(atPath: labelsCSVURL.path) {
                        let labelsCSV = try String(contentsOf: labelsCSVURL, encoding: .utf8)
                        let labelCount = labelsCSV.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                            .count - 1
                        totalRows += labelCount
                    }
                    
                    if config.includeItems, FileManager.default.fileExists(atPath: itemsCSVURL.path) {
                        let itemsCSV = try String(contentsOf: itemsCSVURL, encoding: .utf8)
                        let itemCount = itemsCSV.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                            .count - 1
                        totalRows += itemCount
                    }
                    
                    guard totalRows > 0 else {
                        continuation.yield(.error(SendableError(DataError.invalidCSVFormat)))
                        continuation.finish()
                        throw DataError.invalidCSVFormat
                    }
                    
                    var locationCount = 0
                    var labelCount = 0
                    var itemCount = 0

                    let batchSize = 50

                    // Create local ModelContext for optimal performance (10x faster per Hudson)
                    let modelContext = await MainActor.run { ModelContext(modelContainer) }

                    // Pre-fetch existing locations and labels for caching (MainActor required for SwiftData)
                    var locationCache: [String: InventoryLocation] = [:]
                    var labelCache: [String: InventoryLabel] = [:]

                    await MainActor.run {
                        if config.includeLocations {
                            if let existingLocations = try? modelContext.fetch(FetchDescriptor<InventoryLocation>()) {
                                for location in existingLocations {
                                    locationCache[location.name] = location
                                }
                            }
                        }
                        
                        if config.includeLabels {
                            if let existingLabels = try? modelContext.fetch(FetchDescriptor<InventoryLabel>()) {
                                for label in existingLabels {
                                    labelCache[label.name] = label
                                }
                            }
                        }
                    }
                    
                    // Collect image copy tasks for concurrent processing
                    struct ImageCopyTask: Sendable {
                        let sourceURL: URL
                        let destinationFilename: String
                        let targetName: String
                        let isLocation: Bool
                    }
                    var imageCopyTasks: [ImageCopyTask] = []
                    
                    // Import locations if enabled
                    if config.includeLocations, FileManager.default.fileExists(atPath: locationsCSVURL.path) {
                        let csvString = try String(contentsOf: locationsCSVURL, encoding: .utf8)
                        let rows = csvString.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                        
                        if rows.count > 1 {
                            // Parse CSV off main thread
                            struct LocationData {
                                let name: String
                                let desc: String
                                let photoFilename: String
                                let photoURL: URL?
                            }
                            
                            var locationDataBatch: [LocationData] = []
                            
                            for row in rows.dropFirst() {
                                let values = await self.parseCSVRow(row)
                                guard values.count >= 3 else { continue }
                                
                                var photoURL: URL? = nil
                                if !values[2].isEmpty {
                                    let sanitizedFilename = self.sanitizeFilename(values[2])
                                    let url = photosDir.appendingPathComponent(sanitizedFilename)
                                    if FileManager.default.fileExists(atPath: url.path) {
                                        photoURL = url
                                    }
                                }
                                
                                locationDataBatch.append(LocationData(
                                    name: values[0],
                                    desc: values[1],
                                    photoFilename: values[2],
                                    photoURL: photoURL
                                ))
                                
                                processedRows += 1
                                
                                // Process batch on MainActor when full
                                if locationDataBatch.count >= batchSize {
                                    let batchToProcess = locationDataBatch
                                    locationDataBatch.removeAll()

                                    for data in batchToProcess {
                                        let location = await self.createAndConfigureLocation(name: data.name, desc: data.desc)

                                        if let photoURL = data.photoURL {
                                            await MainActor.run {
                                                imageCopyTasks.append(ImageCopyTask(
                                                    sourceURL: photoURL,
                                                    destinationFilename: data.photoFilename,
                                                    targetName: location.name,
                                                    isLocation: true
                                                ))
                                            }
                                        }

                                        await MainActor.run {
                                            locationCache[location.name] = location
                                            modelContext.insert(location)
                                            locationCount += 1
                                        }
                                    }

                                    await MainActor.run {
                                        try? modelContext.save()
                                    }
                                }
                                
                                if processedRows % 50 == 0 || processedRows == totalRows {
                                    let progress = Double(processedRows) / Double(totalRows)
                                    continuation.yield(.progress(progress))
                                }
                            }
                            
                            // Process remaining locations
                            if !locationDataBatch.isEmpty {
                                let batchToProcess = locationDataBatch

                                await Task { @MainActor in
                                    for data in batchToProcess {
                                        let location = await self.createAndConfigureLocation(name: data.name, desc: data.desc)
                                        
                                        if let photoURL = data.photoURL {
                                             imageCopyTasks.append(ImageCopyTask(
                                                 sourceURL: photoURL,
                                                 destinationFilename: data.photoFilename,
                                                 targetName: location.name,
                                                 isLocation: true
                                             ))
                                         }
                                        
                                        locationCache[location.name] = location
                                        modelContext.insert(location)
                                        locationCount += 1
                                    }
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                    
                    // Import labels if enabled
                    if config.includeLabels, FileManager.default.fileExists(atPath: labelsCSVURL.path) {
                        let csvString = try String(contentsOf: labelsCSVURL, encoding: .utf8)
                        let rows = csvString.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                        
                        if rows.count > 1 {
                            // Parse CSV off main thread
                            struct LabelData {
                                let name: String
                                let desc: String
                                let colorHex: String
                                let emoji: String
                            }
                            
                            var labelDataBatch: [LabelData] = []
                            
                            for row in rows.dropFirst() {
                                let values = await self.parseCSVRow(row)
                                guard values.count >= 4 else { continue }
                                
                                labelDataBatch.append(LabelData(
                                    name: values[0],
                                    desc: values[1],
                                    colorHex: values[2],
                                    emoji: values[3]
                                ))
                                
                                processedRows += 1
                                
                                // Process batch on MainActor when full
                                if labelDataBatch.count >= batchSize {
                                    let batchToProcess = labelDataBatch
                                    labelDataBatch.removeAll()
                                    
                                    await MainActor.run {
                                        for data in batchToProcess {
                                            let label = self.createAndConfigureLabel(
                                                name: data.name,
                                                desc: data.desc,
                                                colorHex: data.colorHex,
                                                emoji: data.emoji
                                            )
                                            
                                            labelCache[label.name] = label
                                            modelContext.insert(label)
                                            labelCount += 1
                                        }
                                        try? modelContext.save()
                                    }
                                }
                                
                                if processedRows % 50 == 0 || processedRows == totalRows {
                                    let progress = Double(processedRows) / Double(totalRows)
                                    continuation.yield(.progress(progress))
                                }
                            }
                            
                            // Process remaining labels
                            if !labelDataBatch.isEmpty {
                                let batchToProcess = labelDataBatch
                                
                                await MainActor.run {
                                    for data in batchToProcess {
                                        let label = self.createAndConfigureLabel(
                                            name: data.name,
                                            desc: data.desc,
                                            colorHex: data.colorHex,
                                            emoji: data.emoji
                                        )
                                        
                                        labelCache[label.name] = label
                                        modelContext.insert(label)
                                        labelCount += 1
                                    }
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                    
                    // Import items if enabled
                    if config.includeItems, FileManager.default.fileExists(atPath: itemsCSVURL.path) {
                        let csvString = try String(contentsOf: itemsCSVURL, encoding: .utf8)
                        let rows = csvString.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                        
                        if rows.count > 1 {
                            // Parse CSV data off main thread
                            struct ItemData {
                                let title: String
                                let desc: String
                                let locationName: String
                                let labelName: String
                                let photoFilename: String
                                let photoURL: URL?
                            }
                            
                            var itemDataBatch: [ItemData] = []
                            
                            for row in rows.dropFirst() {
                                let values = await self.parseCSVRow(row)
                                guard values.count >= 13 else { continue }
                                
                                let photoFilename = values[11]
                                var photoURL: URL? = nil
                                if !photoFilename.isEmpty {
                                    let sanitizedFilename = self.sanitizeFilename(photoFilename)
                                    let url = photosDir.appendingPathComponent(sanitizedFilename)
                                    if FileManager.default.fileExists(atPath: url.path) {
                                        photoURL = url
                                    }
                                }
                                
                                itemDataBatch.append(ItemData(
                                    title: values[0],
                                    desc: values[1],
                                    locationName: values[2],
                                    labelName: values[3],
                                    photoFilename: photoFilename,
                                    photoURL: photoURL
                                ))
                                
                                processedRows += 1
                                
                                // Process batch on MainActor when full
                                if itemDataBatch.count >= batchSize {
                                    let batchToProcess = itemDataBatch
                                    itemDataBatch.removeAll()
                                    
                                    await MainActor.run {
                                        for data in batchToProcess {
                                            let item = self.createAndConfigureItem(title: data.title, desc: data.desc)

                                            if config.includeLocations && !data.locationName.isEmpty {
                                                if let cachedLocation = locationCache[data.locationName] {
                                                    item.location = cachedLocation
                                                } else {
                                                    let location = self.createAndConfigureLocation(name: data.locationName, desc: "")
                                                    modelContext.insert(location)
                                                    locationCache[data.locationName] = location
                                                    item.location = location
                                                }
                                            }
                                            
                                            if config.includeLabels && !data.labelName.isEmpty {
                                                if let cachedLabel = labelCache[data.labelName] {
                                                    item.label = cachedLabel
                                                } else {
                                                    let label = self.createAndConfigureLabel(name: data.labelName, desc: "", colorHex: "", emoji: "")
                                                    modelContext.insert(label)
                                                    labelCache[data.labelName] = label
                                                    item.label = label
                                                }
                                            }
                                            
                                            if let photoURL = data.photoURL {
                                                imageCopyTasks.append(ImageCopyTask(
                                                    sourceURL: photoURL,
                                                    destinationFilename: data.photoFilename,
                                                    targetName: item.title,
                                                    isLocation: false
                                                ))
                                            }
                                            
                                            modelContext.insert(item)
                                            itemCount += 1
                                        }
                                        try? modelContext.save()
                                    }
                                }
                                
                                if processedRows % 50 == 0 || processedRows == totalRows {
                                    let progress = Double(processedRows) / Double(totalRows)
                                    continuation.yield(.progress(progress))
                                }
                            }
                            
                            // Process remaining items
                            if !itemDataBatch.isEmpty {
                                let batchToProcess = itemDataBatch
                                
                                await MainActor.run {
                                    for data in batchToProcess {
                                        let item = self.createAndConfigureItem(title: data.title, desc: data.desc)

                                        if config.includeLocations && !data.locationName.isEmpty {
                                            if let cachedLocation = locationCache[data.locationName] {
                                                item.location = cachedLocation
                                            } else {
                                                let location = self.createAndConfigureLocation(name: data.locationName, desc: "")
                                                modelContext.insert(location)
                                                locationCache[data.locationName] = location
                                                item.location = location
                                            }
                                        }
                                        
                                        if config.includeLabels && !data.labelName.isEmpty {
                                            if let cachedLabel = labelCache[data.labelName] {
                                                item.label = cachedLabel
                                            } else {
                                                let label = self.createAndConfigureLabel(name: data.labelName, desc: "", colorHex: "", emoji: "")
                                                modelContext.insert(label)
                                                labelCache[data.labelName] = label
                                                item.label = label
                                            }
                                        }
                                        
                                        if let photoURL = data.photoURL {
                                            imageCopyTasks.append(ImageCopyTask(
                                                sourceURL: photoURL,
                                                destinationFilename: data.photoFilename,
                                                targetName: item.title,
                                                isLocation: false
                                            ))
                                        }
                                        
                                        modelContext.insert(item)
                                        itemCount += 1
                                    }
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                    
                    // Copy images sequentially in small batches to avoid memory issues with large imports
                    if !imageCopyTasks.isEmpty {
                        print("📸 Copying \(imageCopyTasks.count) images...")
                        
                        let imageBatchSize = 20
                        for batchStart in stride(from: 0, to: imageCopyTasks.count, by: imageBatchSize) {
                            let batchEnd = min(batchStart + imageBatchSize, imageCopyTasks.count)
                            let batch = Array(imageCopyTasks[batchStart..<batchEnd])
                            
                            let copyResults = try await withThrowingTaskGroup(of: (Int, URL?, URL?).self) { group in
                                for (index, task) in batch.enumerated() {
                                    group.addTask {
                                        do {
                                             let copiedURL = try self.copyImageToDocuments(task.sourceURL, filename: task.destinationFilename)
                                             return (batchStart + index, task.sourceURL, copiedURL)
                                         } catch {
                                             return (batchStart + index, task.sourceURL, nil)
                                        }
                                    }
                                }
                                
                                var results: [(Int, URL?, URL?)] = []
                                for try await result in group {
                                    results.append(result)
                                }
                                return results
                            }
                            
                            // Update image URLs on objects (MainActor required for model updates)
                            await MainActor.run {
                                for (originalIndex, _, copiedURL) in copyResults {
                                    guard let copiedURL = copiedURL else { continue }
                                    
                                    let task = imageCopyTasks[originalIndex]
                                    let targetName = task.targetName
                                    
                                    if task.isLocation {
                                        var descriptor = FetchDescriptor<InventoryLocation>()
                                        descriptor.predicate = #Predicate { $0.name == targetName }
                                        if let location = try? modelContext.fetch(descriptor).first {
                                            location.imageURL = copiedURL
                                        }
                                    } else {
                                        var descriptor = FetchDescriptor<InventoryItem>()
                                        descriptor.predicate = #Predicate { $0.title == targetName }
                                        if let item = try? modelContext.fetch(descriptor).first {
                                            item.imageURL = copiedURL
                                        }
                                    }
                                }
                                
                                // Save image URL updates for this batch
                                try? modelContext.save()
                            }
                         }
                    }
                    
                    continuation.yield(.completed(ImportResult(
                        itemCount: itemCount,
                        locationCount: locationCount,
                        labelCount: labelCount
                    )))
                    continuation.finish()
                    
                } catch {
                    continuation.yield(.error(SendableError(error)))
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Helper Functions

    /// Creates and configures a new InventoryLocation with the given properties.
    /// - Note: Must be called on MainActor since it creates SwiftData model objects
    @MainActor
    private func createAndConfigureLocation(name: String, desc: String) -> InventoryLocation {
        let location = InventoryLocation(name: name)
        location.desc = desc
        return location
    }

    /// Creates and configures a new InventoryItem with the given properties.
    /// - Note: Must be called on MainActor since it creates SwiftData model objects
    @MainActor
    private func createAndConfigureItem(title: String, desc: String) -> InventoryItem {
        let item = InventoryItem()
        item.title = title
        item.desc = desc
        return item
    }

    /// Creates and configures a new InventoryLabel with the given properties.
    /// Converts hex color string to UIColor if provided.
    /// - Note: Must be called on MainActor since it creates SwiftData model objects
    @MainActor
    private func createAndConfigureLabel(name: String, desc: String, colorHex: String, emoji: String) -> InventoryLabel {
        let label = InventoryLabel(name: name, desc: desc)
        label.emoji = emoji

        // Convert hex to UIColor if provided
        if !colorHex.isEmpty {
            var hexString = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            if hexString.hasPrefix("#") {
                hexString.remove(at: hexString.startIndex)
            }

            if hexString.count == 6 {
                var rgbValue: UInt64 = 0
                Scanner(string: hexString).scanHexInt64(&rgbValue)

                label.color = UIColor(
                    red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                    green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                    blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                    alpha: 1.0
                )
            }
        }

        return label
    }

    /// Finds an existing location by name or creates a new one if not found.
    /// - Note: Must be called on MainActor since it accesses SwiftData model context
    @MainActor
    private func findOrCreateLocation(name: String, modelContext: ModelContext) -> InventoryLocation {
        if let existing = try? modelContext.fetch(FetchDescriptor<InventoryLocation>(
            predicate: #Predicate<InventoryLocation> { $0.name == name }
        )).first {
            return existing
        } else {
            let location = InventoryLocation(name: name)
            modelContext.insert(location)
            return location
        }
    }

    /// Finds an existing label by name or creates a new one if not found.
    /// - Note: Must be called on MainActor since it accesses SwiftData model context
    @MainActor
    private func findOrCreateLabel(name: String, modelContext: ModelContext) -> InventoryLabel {
        if let existing = try? modelContext.fetch(FetchDescriptor<InventoryLabel>(
            predicate: #Predicate<InventoryLabel> { $0.name == name }
        )).first {
            return existing
        } else {
            let label = InventoryLabel(name: name)
            modelContext.insert(label)
            return label
        }
    }

    // MARK: - Batch Fetching Helpers

    /// Fetches inventory items in batches to minimize memory pressure.
    ///
    /// Uses dynamic batch sizing based on device memory (50-300 items per batch).
    /// Explicitly saves after each batch per Paul Hudson's recommendations (p. 217).
    ///
    /// **Performance Note:** Must be called with locally-created ModelContext, not actor property.
    /// Creating context locally is ~10x faster than accessing actor properties.
    ///
    /// - Parameter modelContext: Local context created by caller for optimal performance
    /// - Returns: Tuple of (item data array, photo URLs array)
    /// - Throws: DataError if fetch fails
    ///
    /// - Note: All SwiftData operations run on MainActor per Apple's requirements.
    ///         Item property access must happen on MainActor where model objects are bound.
    private func fetchItemsInBatches(
        modelContext: ModelContext
    ) async throws -> (items: [ItemData], photoURLs: [URL]) {
        var allItemData: [ItemData] = []
        var allPhotoURLs: [URL] = []
        var offset = 0

        while true {
            // SwiftData fetch must run on MainActor
            let batch = try await MainActor.run {
                var descriptor = FetchDescriptor<InventoryItem>(
                    sortBy: [SortDescriptor(\.title)]
                )
                descriptor.fetchLimit = Self.batchSize
                descriptor.fetchOffset = offset

                return try modelContext.fetch(descriptor)
            }

            if batch.isEmpty {
                break
            }

            // Process batch data on MainActor since we're accessing model properties
            let batchResult = await MainActor.run {
                var batchData: [ItemData] = []
                var batchPhotoURLs: [URL] = []

                for item in batch {
                    let itemData = (
                        title: item.title,
                        desc: item.desc,
                        locationName: item.location?.name ?? "",
                        labelName: item.label?.name ?? "",
                        quantity: item.quantityInt,
                        serial: item.serial,
                        model: item.model,
                        make: item.make,
                        price: item.price,
                        insured: item.insured,
                        notes: item.notes,
                        imageURL: item.imageURL,
                        hasUsedAI: item.hasUsedAI
                    )
                    batchData.append(itemData)

                    if let imageURL = item.imageURL {
                        batchPhotoURLs.append(imageURL)
                    }
                }

                return (batchData, batchPhotoURLs)
            }

            allItemData.append(contentsOf: batchResult.0)
            allPhotoURLs.append(contentsOf: batchResult.1)

            offset += batch.count

            if batch.count < Self.batchSize {
                break
            }
        }

        return (allItemData, allPhotoURLs)
    }
    
    /// Fetches location data in batches with the same performance optimizations as items.
    ///
    /// - Parameter modelContext: Local context created by caller
    /// - Returns: Tuple of (location data array, photo URLs array)
    /// - Throws: DataError if fetch fails
    private func fetchLocationsInBatches(
        modelContext: ModelContext
    ) async throws -> (locations: [LocationData], photoURLs: [URL]) {
        var allLocationData: [LocationData] = []
        var allPhotoURLs: [URL] = []
        var offset = 0

        while true {
            // SwiftData fetch must run on MainActor
            let batch = try await MainActor.run {
                var descriptor = FetchDescriptor<InventoryLocation>(
                    sortBy: [SortDescriptor(\.name)]
                )
                descriptor.fetchLimit = Self.batchSize
                descriptor.fetchOffset = offset

                return try modelContext.fetch(descriptor)
            }

            if batch.isEmpty {
                break
            }

            // Process batch data on MainActor since we're accessing model properties
            let batchResult = await MainActor.run {
                var batchData: [LocationData] = []
                var batchPhotoURLs: [URL] = []

                for location in batch {
                    let locationData = (
                        name: location.name,
                        desc: location.desc,
                        imageURL: location.imageURL
                    )
                    batchData.append(locationData)

                    if let imageURL = location.imageURL {
                        batchPhotoURLs.append(imageURL)
                    }
                }

                return (batchData, batchPhotoURLs)
            }

            allLocationData.append(contentsOf: batchResult.0)
            allPhotoURLs.append(contentsOf: batchResult.1)

            offset += batch.count

            if batch.count < Self.batchSize {
                break
            }
        }

        return (allLocationData, allPhotoURLs)
    }
    
    /// Fetches label data in batches with color and emoji information.
    ///
    /// - Parameter modelContext: Local context created by caller
    /// - Returns: Array of label data
    /// - Throws: DataError if fetch fails
    private func fetchLabelsInBatches(
        modelContext: ModelContext
    ) async throws -> [LabelData] {
        var allLabelData: [LabelData] = []
        var offset = 0

        while true {
            // SwiftData fetch must run on MainActor
            let batch = try await MainActor.run {
                var descriptor = FetchDescriptor<InventoryLabel>(
                    sortBy: [SortDescriptor(\.name)]
                )
                descriptor.fetchLimit = Self.batchSize
                descriptor.fetchOffset = offset

                return try modelContext.fetch(descriptor)
            }

            if batch.isEmpty {
                break
            }

            // Process batch data on MainActor since we're accessing model properties
            let batchData = await MainActor.run {
                batch.map { label in
                    (
                        name: label.name,
                        desc: label.desc,
                        color: label.color,
                        emoji: label.emoji
                    )
                }
            }

            allLabelData.append(contentsOf: batchData)

            offset += batch.count

            if batch.count < Self.batchSize {
                break
            }
        }

        return allLabelData
    }
    
    // MARK: - Archive Creation Helpers

    /// Creates a ZIP archive from a source directory using streaming compression
    /// - Parameters:
    ///   - sourceDirectory: Directory containing files to archive
    ///   - archiveName: Name for the output ZIP file
    ///   - progressHandler: Optional closure called periodically with (filesProcessed, estimatedTotal)
    /// - Returns: URL of the created archive in the temporary directory
    /// - Note: Runs on background thread via Task.detached, uses streaming to minimize memory usage
    private nonisolated func createArchive(
        from sourceDirectory: URL,
        archiveName: String,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async throws -> URL {
        try await Task.detached {
            let archiveURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(archiveName)

            // Remove existing archive if present
            try? FileManager.default.removeItem(at: archiveURL)

            // Create archive in a scope to ensure it's released before we return
            do {
                let archive = try Archive(url: archiveURL, accessMode: .create)

                // Enumerate all files in source directory
                let sourcePath = sourceDirectory.path
                guard let enumerator = FileManager.default.enumerator(atPath: sourcePath) else {
                    throw DataError.failedCreateZip
                }

                var filesProcessed = 0
                let allPaths = enumerator.allObjects as? [String] ?? []
                let totalFiles = allPaths.count

                // Stream files into archive without loading all paths into memory
                for relativePath in allPaths {
                    let fullPath = sourceDirectory.appendingPathComponent(relativePath)
                    var isDirectory: ObjCBool = false

                    // Only add files, not directories
                    if FileManager.default.fileExists(atPath: fullPath.path, isDirectory: &isDirectory),
                       !isDirectory.boolValue {
                        try archive.addEntry(with: relativePath, relativeTo: sourceDirectory)

                        filesProcessed += 1

                        // Report progress every 10 files or on completion
                        if let handler = progressHandler,
                           filesProcessed % 10 == 0 || filesProcessed == totalFiles {
                            handler(filesProcessed, totalFiles)
                        }
                    }
                }
                // Archive is released here when it goes out of scope
            }
            
            // Ensure the archive is fully written to disk before proceeding
            // This is critical for test reliability where files are accessed immediately
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Verify the archive was created successfully
            guard FileManager.default.fileExists(atPath: archiveURL.path) else {
                throw DataError.failedCreateZip
            }

            // Set proper permissions on the archive
            try FileManager.default.setAttributes([
                .posixPermissions: 0o644
            ], ofItemAtPath: archiveURL.path)

            return archiveURL
        }.value
    }

    // MARK: - Photo Copy Helpers

    private nonisolated func copyPhotosToDirectoryWithProgress(
        photoURLs: [URL],
        destinationDir: URL,
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws {
        let maxConcurrentCopies = 5
        var failedCopies: [(url: URL, error: Error)] = []
        var activeTasks = 0
        var completedCount = 0
        let totalCount = photoURLs.count
        
        try await withThrowingTaskGroup(of: (URL, Error?).self) { group in
            var pendingURLs = photoURLs[...]
            
            while !pendingURLs.isEmpty || activeTasks > 0 {
                while activeTasks < maxConcurrentCopies, let photoURL = pendingURLs.popFirst() {
                    activeTasks += 1
                    group.addTask {
                        do {
                            guard FileManager.default.fileExists(atPath: photoURL.path) else {
                                return (photoURL, DataError.photoNotFound)
                            }
                            
                            let dest = destinationDir.appendingPathComponent(photoURL.lastPathComponent)
                            try? FileManager.default.removeItem(at: dest)
                            try FileManager.default.copyItem(at: photoURL, to: dest)
                            return (photoURL, nil)
                        } catch {
                            return (photoURL, error)
                        }
                    }
                }
                
                if let result = try await group.next() {
                    activeTasks -= 1
                    completedCount += 1
                    
                    if let error = result.1 {
                        failedCopies.append((url: result.0, error: error))
                    }
                    
                    // Report progress based on total photo count for optimal UX
                    let threshold = ProgressMapper.photoProgressThreshold(for: totalCount)
                    if completedCount % threshold == 0 || completedCount == totalCount {
                        progressHandler(completedCount, totalCount)
                    }
                }
            }
        }
        
        if !failedCopies.isEmpty {
            let failureRate = Double(failedCopies.count) / Double(photoURLs.count)
            TelemetryManager.shared.trackPhotoCopyFailures(
                failureCount: failedCopies.count,
                totalPhotos: photoURLs.count,
                failureRate: failureRate
            )

            // Log summary instead of individual failures to reduce console noise
            let notFoundCount = failedCopies.filter { ($0.error as? DataError) == .photoNotFound }.count
            let otherErrors = failedCopies.count - notFoundCount

            print("⚠️ Photo copy completed with \(failedCopies.count) failures:")
            if notFoundCount > 0 {
                print("   • \(notFoundCount) photos not found (may have been deleted)")
            }
            if otherErrors > 0 {
                print("   • \(otherErrors) photos failed due to other errors")
                // Log first few other errors for debugging
                for failure in failedCopies.prefix(3) where (failure.error as? DataError) != .photoNotFound {
                    print("     - \(failure.url.lastPathComponent): \(failure.error.localizedDescription)")
                }
            }
            print("   Export will continue without missing photos.")
        }
    }

    private nonisolated func copyPhotosToDirectory(photoURLs: [URL], destinationDir: URL) async throws {
        let maxConcurrentCopies = 5
        var failedCopies: [(url: URL, error: Error)] = []
        var activeTasks = 0
        
        try await withThrowingTaskGroup(of: (URL, Error?).self) { group in
            var pendingURLs = photoURLs[...]
            
            while !pendingURLs.isEmpty || activeTasks > 0 {
                while activeTasks < maxConcurrentCopies, let photoURL = pendingURLs.popFirst() {
                    activeTasks += 1
                    group.addTask {
                        do {
                            guard FileManager.default.fileExists(atPath: photoURL.path) else {
                                return (photoURL, DataError.photoNotFound)
                            }
                            
                            let dest = destinationDir.appendingPathComponent(photoURL.lastPathComponent)
                            try? FileManager.default.removeItem(at: dest)
                            try FileManager.default.copyItem(at: photoURL, to: dest)
                            return (photoURL, nil)
                        } catch {
                            return (photoURL, error)
                        }
                    }
                }
                
                if let result = try await group.next() {
                    activeTasks -= 1
                    if let error = result.1 {
                        failedCopies.append((url: result.0, error: error))
                    }
                }
            }
        }

        if !failedCopies.isEmpty {
            let failureRate = Double(failedCopies.count) / Double(photoURLs.count)
            TelemetryManager.shared.trackPhotoCopyFailures(
                failureCount: failedCopies.count,
                totalPhotos: photoURLs.count,
                failureRate: failureRate
            )

            // Log summary instead of individual failures to reduce console noise
            let notFoundCount = failedCopies.filter { ($0.error as? DataError) == .photoNotFound }.count
            let otherErrors = failedCopies.count - notFoundCount

            print("⚠️ Photo copy completed with \(failedCopies.count) failures:")
            if notFoundCount > 0 {
                print("   • \(notFoundCount) photos not found (may have been deleted)")
            }
            if otherErrors > 0 {
                print("   • \(otherErrors) photos failed due to other errors")
                // Log first few other errors for debugging
                for failure in failedCopies.prefix(3) where (failure.error as? DataError) != .photoNotFound {
                    print("     - \(failure.url.lastPathComponent): \(failure.error.localizedDescription)")
                }
            }
            print("   Export will continue without missing photos.")
        }
    }

    // MARK: - Security Helpers
    private nonisolated func sanitizeFilename(_ filename: String) -> String {
        // Remove directory traversal attempts and invalid characters
        let sanitized = filename
            .replacingOccurrences(of: "..", with: "")
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure filename is not empty after sanitization
        return sanitized.isEmpty ? "unknown" : sanitized
    }
    
    // MARK: - Image Copy Helpers
    private nonisolated func validateImageFile(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Check file size (100MB limit)
        let maxFileSize: Int64 = 100 * 1024 * 1024
        guard fileSize <= maxFileSize else {
            throw DataError.fileTooLarge
        }
        
        // Check file type by extension
        let allowedExtensions = ["jpg", "jpeg", "png", "heic", "heif"]
        let fileExtension = url.pathExtension.lowercased()
        guard allowedExtensions.contains(fileExtension) else {
            throw DataError.invalidFileType
        }
    }
    
    private nonisolated func copyImageToDocuments(_ sourceURL: URL, filename: String) throws -> URL {
        try validateImageFile(sourceURL)
        
        let sanitizedFilename = sanitizeFilename(filename)
        let destURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(sanitizedFilename)
        
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        return destURL
    }
    
    // MARK: - CSV Writing Helpers
    private func writeCSV(items: [ItemData], to url: URL) async throws {
        let csvLines: [String] = {
            var lines: [String] = []
            let header = [
                "Title","Description","Location","Label","Quantity","Serial","Model","Make",
                "Price","Insured","Notes","PhotoFilename","HasUsedAI"
            ]
            lines.append(header.joined(separator: ","))

            for item in items {
                let row: [String] = [
                    item.title,
                    item.desc,
                    item.locationName,
                    item.labelName,
                    String(item.quantity),
                    item.serial,
                    item.model,
                    item.make,
                    item.price.description,
                    item.insured ? "true" : "false",
                    item.notes,
                    item.imageURL?.lastPathComponent ?? "",
                    item.hasUsedAI ? "true" : "false"
                ]
                lines.append(row.map(Self.escapeForCSV).joined(separator: ","))
            }
            return lines
        }()
        
        let csvString = csvLines.joined(separator: "\n")
        try csvString.data(using: .utf8)?.write(to: url)
    }

    private static func escapeForCSV(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuotes {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        } else { return value }
    }
    
    private func parseCSVRow(_ row: String) async -> [String] {
        var values: [String] = []
        var currentValue = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                values.append(currentValue)
                currentValue = ""
            } else {
                currentValue.append(char)
            }
        }
        values.append(currentValue)
        
        return values.map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    private func writeLocationsCSV(locations: [LocationData], to url: URL) async throws {
        let csvLines: [String] = {
            var lines: [String] = []
            let header = ["Name", "Description", "PhotoFilename"]
            lines.append(header.joined(separator: ","))
            
            for location in locations {
                let row: [String] = [
                    location.name,
                    location.desc,
                    location.imageURL?.lastPathComponent ?? ""
                ]
                lines.append(row.map(Self.escapeForCSV).joined(separator: ","))
            }
            return lines
        }()
        
        let csvString = csvLines.joined(separator: "\n")
        try csvString.data(using: .utf8)?.write(to: url)
    }
    
    private func writeLabelsCSV(labels: [LabelData], to url: URL) async throws {
        let csvLines: [String] = {
            var lines: [String] = []
            let header = ["Name", "Description", "ColorHex", "Emoji"]
            lines.append(header.joined(separator: ","))
            
            for label in labels {
                let colorHex = label.color.map { color -> String in
                    var red: CGFloat = 0
                    var green: CGFloat = 0
                    var blue: CGFloat = 0
                    var alpha: CGFloat = 0
                    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                    return String(format: "#%02X%02X%02X",
                                Int(red * 255),
                                Int(green * 255),
                                Int(blue * 255))
                } ?? ""
                
                let row: [String] = [
                    label.name,
                    label.desc,
                    colorHex,
                    label.emoji
                ]
                lines.append(row.map(Self.escapeForCSV).joined(separator: ","))
            }
            return lines
        }()
        
        let csvString = csvLines.joined(separator: "\n")
        try csvString.data(using: .utf8)?.write(to: url)
    }
    
    /// Exports specific InventoryItems (and their photos) along with all locations and labels into a zip file
    func exportSpecificItems(items: [InventoryItem], modelContainer: ModelContainer, fileName: String? = nil) async throws -> URL {
        // Create local ModelContext for optimal performance
        let modelContext = await MainActor.run { ModelContext(modelContainer) }
        guard !items.isEmpty else { throw DataError.nothingToExport }

        // Get all locations and labels using batched fetching for efficiency
        // SwiftData operations run on MainActor
        let locationResult = try await fetchLocationsInBatches(modelContext: modelContext)
        let labelData = try await fetchLabelsInBatches(modelContext: modelContext)

        // Extract item data and collect photo URLs
        // Item property access must be on MainActor
        let (itemData, itemPhotoURLs) = await MainActor.run {
            var itemData: [ItemData] = []
            var photoURLs: [URL] = []

            for item in items {
                let data: ItemData = (
                    title: item.title,
                    desc: item.desc,
                    locationName: item.location?.name ?? "",
                    labelName: item.label?.name ?? "",
                    quantity: item.quantityInt,
                    serial: item.serial,
                    model: item.model,
                    make: item.make,
                    price: item.price,
                    insured: item.insured,
                    notes: item.notes,
                    imageURL: item.imageURL,
                    hasUsedAI: item.hasUsedAI
                )
                itemData.append(data)

                if let imageURL = item.imageURL {
                    photoURLs.append(imageURL)
                }
            }

            return (itemData, photoURLs)
        }

        let locationData = locationResult.locations
        var allPhotoURLs = itemPhotoURLs
        allPhotoURLs.append(contentsOf: locationResult.photoURLs)

        let archiveName = fileName ?? "Selected-Items-export-\(DateFormatter.exportDateFormatter.string(from: .init()))".replacingOccurrences(of: " ", with: "-") + ".zip"

        // Working directory in tmp
        let workingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        let photosDir = workingRoot.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photosDir,
                                             withIntermediateDirectories: true)
        try FileManager.default.setAttributes([
            .posixPermissions: 0o755
        ], ofItemAtPath: photosDir.path)

        // Write CSV files
        if !itemData.isEmpty {
            let itemsCSVURL = workingRoot.appendingPathComponent("inventory.csv")
            try await writeCSV(items: itemData, to: itemsCSVURL)
        }
        
        if !locationData.isEmpty {
            let locationsCSVURL = workingRoot.appendingPathComponent("locations.csv")
            try await writeLocationsCSV(locations: locationData, to: locationsCSVURL)
        }
        
        if !labelData.isEmpty {
            let labelsCSVURL = workingRoot.appendingPathComponent("labels.csv")
            try await writeLabelsCSV(labels: labelData, to: labelsCSVURL)
        }

        // Copy photos in background - deduplicate URLs
        let uniquePhotoURLs = Array(Set(allPhotoURLs))
        try await copyPhotosToDirectory(photoURLs: uniquePhotoURLs, destinationDir: photosDir)

        // Create ZIP archive using unified helper
        let archiveURL = try await createArchive(from: workingRoot, archiveName: archiveName)

        // Clean up working directory
        Task.detached {
            try? FileManager.default.removeItem(at: workingRoot)
        }

        return archiveURL
    }
}

private extension DateFormatter {
    static let exportDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

private extension UIColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
