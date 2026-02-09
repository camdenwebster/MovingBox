//
//  DataManager.swift
//  MovingBox
//
//  Created by Camden Webster on 5/1/25.
//

import Foundation
import SQLiteData
import SwiftUI
import ZIPFoundation

/// # DataManager: Swift Concurrency-Safe Import/Export Actor
///
/// Handles bulk import and export of inventory data using sqlite-data (StructuredQueries + GRDB).
///
/// ## Architecture Overview
///
/// This actor implements a **DatabaseReader/DatabaseWriter** pattern where:
/// - Views pass `any DatabaseWriter` (Sendable) to export/import functions
/// - Functions use `database.read {}` and `database.write {}` for all SQL operations
/// - sqlite-data value types (`SQLiteInventoryItem`, etc.) are `Sendable` structs,
///   eliminating the MainActor dance required by SwiftData's `@Model` classes
///
/// ## Key Design Decisions
///
/// ### 1. Actor Isolation
/// All export/import functions are marked `nonisolated` to allow returning `AsyncStream`
/// without actor hopping. Since sqlite-data models are value-type structs, no MainActor
/// isolation is required for property access.
///
/// ### 2. Swift Concurrency Safety
/// - `DatabaseReader`/`DatabaseWriter` are Sendable (GRDB protocol requirement)
/// - `SQLiteInventoryItem` and friends are `nonisolated struct` — fully Sendable
/// - No MainActor wrappers needed for data extraction
///
/// ### 3. Batch Processing Strategy
/// - Dynamic batch sizes based on device memory (50-300 items per batch)
/// - sqlite-data handles transaction management internally via `database.write {}`
/// - Background file operations for photo copying and archive creation
/// - Progress reporting via AsyncStream for responsive UI
///
/// ### 4. Performance Optimizations
/// - Direct SQL reads without MainActor overhead
/// - Pre-fetching and caching for relationship lookups during import
/// - Streaming data processing to minimize memory peaks
/// - Background file operations with concurrent photo copying
///
/// ## Usage Example
///
/// ```swift
/// // In a SwiftUI view:
/// @Dependency(\.defaultDatabase) var database
///
/// func exportData() async {
///     for await progress in DataManager.shared.exportInventoryWithProgress(
///         database: database,
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
            NSError(
                domain: "DataManagerError", code: -1,
                userInfo: [
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
                return
                    "This doesn't appear to be a MovingBox export file. Please use a ZIP file that was exported from MovingBox."
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
                return
                    "MovingBox can only import files that were exported from the app. If you have data from another app, you'll need to manually add it."
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

    private init() {}

    /// Exports inventory with progress reporting via AsyncStream.
    ///
    /// Uses `database.read {}` to fetch all data as value-type structs.
    /// Since sqlite-data models are Sendable structs, no MainActor isolation is needed.
    ///
    /// - Parameters:
    ///   - database: A DatabaseWriter (Sendable, safe to pass across actors)
    ///   - fileName: Optional custom filename (defaults to timestamped name)
    ///   - config: What data types to include (items, locations, labels)
    /// - Returns: AsyncStream yielding ExportProgress updates
    nonisolated func exportInventoryWithProgress(
        database: any DatabaseWriter,
        fileName: String? = nil,
        config: ExportConfig = ExportConfig(includeItems: true, includeLocations: true, includeLabels: true)
    ) -> AsyncStream<ExportProgress> {
        AsyncStream { continuation in
            Task {
                do {
                    continuation.yield(.preparing)

                    var itemData: [ItemData] = []
                    var locationData: [LocationData] = []
                    var labelData: [LabelData] = []
                    var allPhotoURLs: [URL] = []

                    var totalSteps = 0
                    var completedSteps = 0

                    if config.includeItems { totalSteps += 1 }
                    if config.includeLocations { totalSteps += 1 }
                    if config.includeLabels { totalSteps += 1 }
                    totalSteps += 3  // CSV writing, photo copying, archiving

                    // Fetch data with progress
                    if config.includeItems {
                        continuation.yield(.fetchingData(phase: "items", progress: 0.0))
                        let result = try await self.fetchItemsForExport(database: database)
                        guard !result.items.isEmpty else { throw DataError.nothingToExport }
                        itemData = result.items
                        allPhotoURLs.append(contentsOf: result.photoURLs)

                        completedSteps += 1
                        continuation.yield(
                            .fetchingData(phase: "items", progress: Double(completedSteps) / Double(totalSteps)))

                        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
                        TelemetryManager.shared.trackExportBatchSize(
                            batchSize: Self.batchSize,
                            deviceMemoryGB: memoryGB,
                            itemCount: result.items.count
                        )
                    }

                    if config.includeLocations {
                        continuation.yield(
                            .fetchingData(phase: "locations", progress: Double(completedSteps) / Double(totalSteps)))
                        let result = try await self.fetchLocationsForExport(database: database)
                        locationData = result.locations
                        allPhotoURLs.append(contentsOf: result.photoURLs)

                        completedSteps += 1
                        continuation.yield(
                            .fetchingData(phase: "locations", progress: Double(completedSteps) / Double(totalSteps)))
                    }

                    if config.includeLabels {
                        continuation.yield(
                            .fetchingData(phase: "labels", progress: Double(completedSteps) / Double(totalSteps)))
                        labelData = try await self.fetchLabelsForExport(database: database)

                        completedSteps += 1
                        continuation.yield(
                            .fetchingData(phase: "labels", progress: Double(completedSteps) / Double(totalSteps)))
                    }

                    guard !itemData.isEmpty || !locationData.isEmpty || !labelData.isEmpty else {
                        throw DataError.nothingToExport
                    }

                    let archiveName =
                        fileName ?? "MovingBox-export-\(DateFormatter.exportDateFormatter.string(from: .init()))"
                        .replacingOccurrences(of: " ", with: "-") + ".zip"

                    // Working directory in tmp
                    let workingRoot = FileManager.default.temporaryDirectory
                        .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
                    let photosDir = workingRoot.appendingPathComponent("photos", isDirectory: true)
                    try FileManager.default.createDirectory(
                        at: photosDir,
                        withIntermediateDirectories: true)
                    try FileManager.default.setAttributes(
                        [
                            .posixPermissions: 0o755
                        ], ofItemAtPath: photosDir.path)

                    // Write CSV files
                    continuation.yield(.writingCSV(progress: Double(completedSteps) / Double(totalSteps)))

                    if config.includeItems {
                        let itemsCSVURL = workingRoot.appendingPathComponent("inventory.csv")
                        try await self.writeCSV(items: itemData, to: itemsCSVURL)
                    }

                    if config.includeLocations {
                        let locationsCSVURL = workingRoot.appendingPathComponent("locations.csv")
                        try await self.writeLocationsCSV(locations: locationData, to: locationsCSVURL)
                    }

                    if config.includeLabels {
                        let labelsCSVURL = workingRoot.appendingPathComponent("labels.csv")
                        try await self.writeLabelsCSV(labels: labelData, to: labelsCSVURL)
                    }

                    completedSteps += 1
                    continuation.yield(.writingCSV(progress: Double(completedSteps) / Double(totalSteps)))

                    // Copy photos with progress
                    if !allPhotoURLs.isEmpty {
                        try await self.copyPhotosToDirectoryWithProgress(
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

                    let archiveURL = try await self.createArchive(
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
                        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
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

    /// Exports all inventory items (and their photos) into a single **zip** file that also
    /// contains `inventory.csv`.  The returned `URL` points to the finished archive
    /// inside the temporary directory -- caller is expected to share / move / delete.
    /// For progress reporting, use `exportInventoryWithProgress` instead.
    func exportInventory(
        database: any DatabaseWriter, fileName: String? = nil,
        config: ExportConfig = ExportConfig(includeItems: true, includeLocations: true, includeLabels: true)
    ) async throws -> URL {
        var itemData: [ItemData] = []
        var locationData: [LocationData] = []
        var labelData: [LabelData] = []
        var allPhotoURLs: [URL] = []

        // Fetch data — sqlite-data structs are value types, no MainActor needed
        if config.includeItems {
            let result = try await fetchItemsForExport(database: database)
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
            let result = try await fetchLocationsForExport(database: database)
            locationData = result.locations
            allPhotoURLs.append(contentsOf: result.photoURLs)
        }

        if config.includeLabels {
            labelData = try await fetchLabelsForExport(database: database)
        }

        // Don't export if nothing is selected
        guard !itemData.isEmpty || !locationData.isEmpty || !labelData.isEmpty else {
            throw DataError.nothingToExport
        }

        let archiveName =
            fileName ?? "MovingBox-export-\(DateFormatter.exportDateFormatter.string(from: .init()))"
            .replacingOccurrences(of: " ", with: "-") + ".zip"

        // Working directory in tmp
        let workingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        let photosDir = workingRoot.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(
            at: photosDir,
            withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [
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
        // Photo URLs were already collected during fetching
        try await copyPhotosToDirectory(photoURLs: allPhotoURLs, destinationDir: photosDir)

        // Create ZIP archive using unified helper
        let archiveURL = try await createArchive(from: workingRoot, archiveName: archiveName)

        // Clean up working directory after a substantial delay to ensure caller can access archive
        // Using a delay prevents race conditions in test environments where
        // the file might be accessed immediately after this function returns.
        // The delay must be long enough for tests to open and read the archive.
        Task.detached {
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
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
    /// - **fetchingData**: 0-30% - Fetching from sqlite-data (scales with item count)
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
        homeName: String,
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
            try FileManager.default.setAttributes(
                [
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
    /// Uses `database.write {}` for all insert operations. Since sqlite-data models are
    /// value-type structs, no MainActor isolation is needed for property access.
    ///
    /// - Parameters:
    ///   - zipURL: URL to the zip file containing exported data
    ///   - database: A DatabaseWriter (Sendable, safe to pass across actors)
    ///   - config: What data types to import (items, locations, labels)
    /// - Returns: AsyncStream yielding ImportProgress updates
    func importInventory(
        from zipURL: URL,
        database: any DatabaseWriter,
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
                    try FileManager.default.setAttributes(
                        [
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
                        let locationCount =
                            locationCSV.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                            .count - 1
                        totalRows += locationCount
                    }

                    if config.includeLabels, FileManager.default.fileExists(atPath: labelsCSVURL.path) {
                        let labelsCSV = try String(contentsOf: labelsCSVURL, encoding: .utf8)
                        let labelCount =
                            labelsCSV.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                            .count - 1
                        totalRows += labelCount
                    }

                    if config.includeItems, FileManager.default.fileExists(atPath: itemsCSVURL.path) {
                        let itemsCSV = try String(contentsOf: itemsCSVURL, encoding: .utf8)
                        let itemCount =
                            itemsCSV.components(separatedBy: .newlines)
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

                    // Pre-fetch existing locations and labels for caching
                    // UUID-based caches since sqlite-data uses value types
                    var locationCache: [String: UUID] = [:]
                    var labelCache: [String: UUID] = [:]

                    // Also cache locationID -> homeID for setting item homeID
                    var locationHomeCache: [UUID: UUID] = [:]

                    let existingLocations = try await database.read { db in
                        try SQLiteInventoryLocation.all.fetchAll(db)
                    }
                    for location in existingLocations {
                        locationCache[location.name] = location.id
                        if let homeID = location.homeID {
                            locationHomeCache[location.id] = homeID
                        }
                    }

                    let existingLabels = try await database.read { db in
                        try SQLiteInventoryLabel.all.fetchAll(db)
                    }
                    for label in existingLabels {
                        labelCache[label.name] = label.id
                    }

                    // Collect image copy tasks for concurrent processing
                    struct ImageCopyTask: Sendable {
                        let sourceURL: URL
                        let destinationFilename: String
                        let targetID: UUID
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
                            struct LocationParseData {
                                let name: String
                                let desc: String
                                let photoFilename: String
                                let photoURL: URL?
                            }

                            var locationDataBatch: [LocationParseData] = []

                            for row in rows.dropFirst() {
                                let values = self.parseCSVRow(row)
                                guard values.count >= 3 else { continue }

                                var photoURL: URL? = nil
                                if !values[2].isEmpty {
                                    let sanitizedFilename = self.sanitizeFilename(values[2])
                                    let url = photosDir.appendingPathComponent(sanitizedFilename)
                                    if FileManager.default.fileExists(atPath: url.path) {
                                        photoURL = url
                                    }
                                }

                                locationDataBatch.append(
                                    LocationParseData(
                                        name: values[0],
                                        desc: values[1],
                                        photoFilename: values[2],
                                        photoURL: photoURL
                                    ))

                                processedRows += 1

                                // Process batch when full
                                if locationDataBatch.count >= batchSize {
                                    let batchToProcess = locationDataBatch
                                    locationDataBatch.removeAll()

                                    try await database.write { db in
                                        for data in batchToProcess {
                                            let locationID = UUID()
                                            try SQLiteInventoryLocation.insert(
                                                SQLiteInventoryLocation(
                                                    id: locationID,
                                                    name: data.name,
                                                    desc: data.desc
                                                )
                                            ).execute(db)

                                            if let photoURL = data.photoURL {
                                                imageCopyTasks.append(
                                                    ImageCopyTask(
                                                        sourceURL: photoURL,
                                                        destinationFilename: data.photoFilename,
                                                        targetID: locationID,
                                                        isLocation: true
                                                    ))
                                            }

                                            locationCache[data.name] = locationID
                                            locationCount += 1
                                        }
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

                                try await database.write { db in
                                    for data in batchToProcess {
                                        let locationID = UUID()
                                        try SQLiteInventoryLocation.insert(
                                            SQLiteInventoryLocation(
                                                id: locationID,
                                                name: data.name,
                                                desc: data.desc
                                            )
                                        ).execute(db)

                                        if let photoURL = data.photoURL {
                                            imageCopyTasks.append(
                                                ImageCopyTask(
                                                    sourceURL: photoURL,
                                                    destinationFilename: data.photoFilename,
                                                    targetID: locationID,
                                                    isLocation: true
                                                ))
                                        }

                                        locationCache[data.name] = locationID
                                        locationCount += 1
                                    }
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
                            struct LabelParseData {
                                let name: String
                                let desc: String
                                let colorHex: String
                                let emoji: String
                            }

                            var labelDataBatch: [LabelParseData] = []

                            for row in rows.dropFirst() {
                                let values = self.parseCSVRow(row)
                                guard values.count >= 4 else { continue }

                                labelDataBatch.append(
                                    LabelParseData(
                                        name: values[0],
                                        desc: values[1],
                                        colorHex: values[2],
                                        emoji: values[3]
                                    ))

                                processedRows += 1

                                // Process batch when full
                                if labelDataBatch.count >= batchSize {
                                    let batchToProcess = labelDataBatch
                                    labelDataBatch.removeAll()

                                    try await database.write { db in
                                        for data in batchToProcess {
                                            let labelID = UUID()
                                            let labelColor = Self.parseHexColor(data.colorHex)

                                            try SQLiteInventoryLabel.insert(
                                                SQLiteInventoryLabel(
                                                    id: labelID,
                                                    name: data.name,
                                                    desc: data.desc,
                                                    color: labelColor,
                                                    emoji: data.emoji
                                                )
                                            ).execute(db)

                                            labelCache[data.name] = labelID
                                            labelCount += 1
                                        }
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

                                try await database.write { db in
                                    for data in batchToProcess {
                                        let labelID = UUID()
                                        let labelColor = Self.parseHexColor(data.colorHex)

                                        try SQLiteInventoryLabel.insert(
                                            SQLiteInventoryLabel(
                                                id: labelID,
                                                name: data.name,
                                                desc: data.desc,
                                                color: labelColor,
                                                emoji: data.emoji
                                            )
                                        ).execute(db)

                                        labelCache[data.name] = labelID
                                        labelCount += 1
                                    }
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
                            struct ItemParseData {
                                let title: String
                                let desc: String
                                let locationName: String
                                let labelName: String
                                let photoFilename: String
                                let photoURL: URL?
                            }

                            var itemDataBatch: [ItemParseData] = []

                            for row in rows.dropFirst() {
                                let values = self.parseCSVRow(row)
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

                                itemDataBatch.append(
                                    ItemParseData(
                                        title: values[0],
                                        desc: values[1],
                                        locationName: values[2],
                                        labelName: values[3],
                                        photoFilename: photoFilename,
                                        photoURL: photoURL
                                    ))

                                processedRows += 1

                                // Process batch when full
                                if itemDataBatch.count >= batchSize {
                                    let batchToProcess = itemDataBatch
                                    itemDataBatch.removeAll()

                                    try await database.write { db in
                                        for data in batchToProcess {
                                            let itemID = UUID()

                                            // Resolve location
                                            var locationID: UUID? = nil
                                            var homeID: UUID? = nil

                                            if config.includeLocations && !data.locationName.isEmpty {
                                                if let cachedLocationID = locationCache[data.locationName] {
                                                    locationID = cachedLocationID
                                                    homeID = locationHomeCache[cachedLocationID]
                                                } else {
                                                    // Create new location on the fly
                                                    let newLocationID = UUID()
                                                    try SQLiteInventoryLocation.insert(
                                                        SQLiteInventoryLocation(
                                                            id: newLocationID,
                                                            name: data.locationName,
                                                            desc: ""
                                                        )
                                                    ).execute(db)
                                                    locationCache[data.locationName] = newLocationID
                                                    locationID = newLocationID
                                                }
                                            }

                                            try SQLiteInventoryItem.insert(
                                                SQLiteInventoryItem(
                                                    id: itemID,
                                                    title: data.title,
                                                    desc: data.desc,
                                                    locationID: locationID,
                                                    homeID: homeID
                                                )
                                            ).execute(db)

                                            // Resolve labels and create join table entries
                                            if config.includeLabels && !data.labelName.isEmpty {
                                                // Support comma-separated label names
                                                let labelNames = data.labelName.split(separator: ",").map {
                                                    $0.trimmingCharacters(in: .whitespaces)
                                                }
                                                var addedLabelIDs: Set<UUID> = []
                                                for labelName in labelNames.prefix(5) {
                                                    var labelID: UUID
                                                    if let cachedLabelID = labelCache[labelName] {
                                                        labelID = cachedLabelID
                                                    } else {
                                                        // Create new label on the fly
                                                        labelID = UUID()
                                                        try SQLiteInventoryLabel.insert(
                                                            SQLiteInventoryLabel(
                                                                id: labelID,
                                                                name: labelName,
                                                                desc: "",
                                                                emoji: ""
                                                            )
                                                        ).execute(db)
                                                        labelCache[labelName] = labelID
                                                    }

                                                    // Avoid duplicate join entries
                                                    if !addedLabelIDs.contains(labelID) {
                                                        addedLabelIDs.insert(labelID)
                                                        try SQLiteInventoryItemLabel.insert(
                                                            SQLiteInventoryItemLabel(
                                                                id: UUID(),
                                                                inventoryItemID: itemID,
                                                                inventoryLabelID: labelID
                                                            )
                                                        ).execute(db)
                                                    }
                                                }
                                            }

                                            if let photoURL = data.photoURL {
                                                imageCopyTasks.append(
                                                    ImageCopyTask(
                                                        sourceURL: photoURL,
                                                        destinationFilename: data.photoFilename,
                                                        targetID: itemID,
                                                        isLocation: false
                                                    ))
                                            }

                                            itemCount += 1
                                        }
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

                                try await database.write { db in
                                    for data in batchToProcess {
                                        let itemID = UUID()

                                        // Resolve location
                                        var locationID: UUID? = nil
                                        var homeID: UUID? = nil

                                        if config.includeLocations && !data.locationName.isEmpty {
                                            if let cachedLocationID = locationCache[data.locationName] {
                                                locationID = cachedLocationID
                                                homeID = locationHomeCache[cachedLocationID]
                                            } else {
                                                let newLocationID = UUID()
                                                try SQLiteInventoryLocation.insert(
                                                    SQLiteInventoryLocation(
                                                        id: newLocationID,
                                                        name: data.locationName,
                                                        desc: ""
                                                    )
                                                ).execute(db)
                                                locationCache[data.locationName] = newLocationID
                                                locationID = newLocationID
                                            }
                                        }

                                        try SQLiteInventoryItem.insert(
                                            SQLiteInventoryItem(
                                                id: itemID,
                                                title: data.title,
                                                desc: data.desc,
                                                locationID: locationID,
                                                homeID: homeID
                                            )
                                        ).execute(db)

                                        // Resolve labels and create join table entries
                                        if config.includeLabels && !data.labelName.isEmpty {
                                            let labelNames = data.labelName.split(separator: ",").map {
                                                $0.trimmingCharacters(in: .whitespaces)
                                            }
                                            var addedLabelIDs: Set<UUID> = []
                                            for labelName in labelNames.prefix(5) {
                                                var labelID: UUID
                                                if let cachedLabelID = labelCache[labelName] {
                                                    labelID = cachedLabelID
                                                } else {
                                                    labelID = UUID()
                                                    try SQLiteInventoryLabel.insert(
                                                        SQLiteInventoryLabel(
                                                            id: labelID,
                                                            name: labelName,
                                                            desc: "",
                                                            emoji: ""
                                                        )
                                                    ).execute(db)
                                                    labelCache[labelName] = labelID
                                                }

                                                if !addedLabelIDs.contains(labelID) {
                                                    addedLabelIDs.insert(labelID)
                                                    try SQLiteInventoryItemLabel.insert(
                                                        SQLiteInventoryItemLabel(
                                                            id: UUID(),
                                                            inventoryItemID: itemID,
                                                            inventoryLabelID: labelID
                                                        )
                                                    ).execute(db)
                                                }
                                            }
                                        }

                                        if let photoURL = data.photoURL {
                                            imageCopyTasks.append(
                                                ImageCopyTask(
                                                    sourceURL: photoURL,
                                                    destinationFilename: data.photoFilename,
                                                    targetID: itemID,
                                                    isLocation: false
                                                ))
                                        }

                                        itemCount += 1
                                    }
                                }
                            }
                        }
                    }

                    // Copy images sequentially in small batches to avoid memory issues with large imports
                    if !imageCopyTasks.isEmpty {
                        print("Copying \(imageCopyTasks.count) images...")

                        let imageBatchSize = 20
                        for batchStart in stride(from: 0, to: imageCopyTasks.count, by: imageBatchSize) {
                            let batchEnd = min(batchStart + imageBatchSize, imageCopyTasks.count)
                            let batch = Array(imageCopyTasks[batchStart..<batchEnd])

                            let copyResults = try await withThrowingTaskGroup(of: (Int, URL?, URL?).self) { group in
                                for (index, task) in batch.enumerated() {
                                    group.addTask {
                                        do {
                                            let copiedURL = try self.copyImageToDocuments(
                                                task.sourceURL, filename: task.destinationFilename)
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

                            // Insert photo BLOBs from copied image files
                            try await database.write { db in
                                for (originalIndex, _, copiedURL) in copyResults {
                                    guard let copiedURL = copiedURL,
                                        let imageData = try? Data(contentsOf: copiedURL)
                                    else { continue }

                                    let task = imageCopyTasks[originalIndex]

                                    if task.isLocation {
                                        try SQLiteInventoryLocationPhoto.insert {
                                            SQLiteInventoryLocationPhoto(
                                                id: UUID(),
                                                inventoryLocationID: task.targetID,
                                                data: imageData,
                                                sortOrder: 0
                                            )
                                        }.execute(db)
                                    } else {
                                        try SQLiteInventoryItemPhoto.insert {
                                            SQLiteInventoryItemPhoto(
                                                id: UUID(),
                                                inventoryItemID: task.targetID,
                                                data: imageData,
                                                sortOrder: 0
                                            )
                                        }.execute(db)
                                    }
                                }
                            }
                        }
                    }

                    continuation.yield(
                        .completed(
                            ImportResult(
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

    /// Parses a hex color string into a UIColor.
    /// Supports formats: "#RRGGBB" or "RRGGBB"
    private static func parseHexColor(_ colorHex: String) -> UIColor? {
        guard !colorHex.isEmpty else { return nil }

        var hexString = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.remove(at: hexString.startIndex)
        }

        guard hexString.count == 6 else { return nil }

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }

    // MARK: - Fetch Helpers (Export)

    /// Fetches all inventory items with their related location/label/home names for export.
    ///
    /// Since sqlite-data models are value-type structs, no MainActor isolation is needed.
    /// Related data (location name, label name, home name) is fetched via separate queries
    /// using foreign key IDs.
    ///
    /// - Parameter database: DatabaseReader to read from
    /// - Returns: Tuple of (item data array, photo URLs array)
    /// - Throws: DataError if fetch fails
    private func fetchItemsForExport(
        database: any DatabaseReader
    ) async throws -> (items: [ItemData], photoURLs: [URL]) {
        try await database.read { db in
            let items =
                try SQLiteInventoryItem
                .order(by: \.title)
                .fetchAll(db)

            // Pre-fetch all related data into lookup dictionaries
            let allLocations = try SQLiteInventoryLocation.fetchAll(db)
            let locationsByID = Dictionary(uniqueKeysWithValues: allLocations.map { ($0.id, $0) })

            let allHomes = try SQLiteHome.fetchAll(db)
            let homesByID = Dictionary(uniqueKeysWithValues: allHomes.map { ($0.id, $0) })

            let allItemLabels = try SQLiteInventoryItemLabel.fetchAll(db)
            let itemLabelsByItemID = Dictionary(grouping: allItemLabels, by: \.inventoryItemID)

            let allLabels = try SQLiteInventoryLabel.fetchAll(db)
            let labelsByID = Dictionary(uniqueKeysWithValues: allLabels.map { ($0.id, $0) })

            var allItemData: [ItemData] = []
            var allPhotoURLs: [URL] = []

            for item in items {
                var locationName = ""
                var homeName = ""
                if let locationID = item.locationID,
                    let location = locationsByID[locationID]
                {
                    locationName = location.name
                    if let homeID = location.homeID, let home = homesByID[homeID] {
                        homeName = home.name
                    }
                }

                var labelName = ""
                if let firstItemLabel = itemLabelsByItemID[item.id]?.first,
                    let label = labelsByID[firstItemLabel.inventoryLabelID]
                {
                    labelName = label.name
                }

                allItemData.append(
                    (
                        title: item.title,
                        desc: item.desc,
                        locationName: locationName,
                        labelName: labelName,
                        homeName: homeName,
                        quantity: item.quantityInt,
                        serial: item.serial,
                        model: item.model,
                        make: item.make,
                        price: item.price,
                        insured: item.insured,
                        notes: item.notes,
                        imageURL: nil,
                        hasUsedAI: item.hasUsedAI
                    ))

                // TODO: Export photo BLOBs from inventoryItemPhotos table
            }

            return (allItemData, allPhotoURLs)
        }
    }

    /// Fetches all location data for export.
    ///
    /// - Parameter database: DatabaseReader to read from
    /// - Returns: Tuple of (location data array, photo URLs array)
    /// - Throws: DataError if fetch fails
    private func fetchLocationsForExport(
        database: any DatabaseReader
    ) async throws -> (locations: [LocationData], photoURLs: [URL]) {
        try await database.read { db in
            let locations =
                try SQLiteInventoryLocation
                .order(by: \.name)
                .fetchAll(db)

            var allLocationData: [LocationData] = []
            let allPhotoURLs: [URL] = []

            for location in locations {
                allLocationData.append(
                    (
                        name: location.name,
                        desc: location.desc,
                        imageURL: nil
                    ))
                // TODO: Export photo BLOBs from inventoryLocationPhotos table
            }

            return (allLocationData, allPhotoURLs)
        }
    }

    /// Fetches all label data for export.
    ///
    /// - Parameter database: DatabaseReader to read from
    /// - Returns: Array of label data
    /// - Throws: DataError if fetch fails
    private func fetchLabelsForExport(
        database: any DatabaseReader
    ) async throws -> [LabelData] {
        try await database.read { db in
            let labels =
                try SQLiteInventoryLabel
                .order(by: \.name)
                .fetchAll(db)

            return labels.map { label in
                (
                    name: label.name,
                    desc: label.desc,
                    color: label.color,
                    emoji: label.emoji
                )
            }
        }
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
                        !isDirectory.boolValue
                    {
                        try archive.addEntry(with: relativePath, relativeTo: sourceDirectory)

                        filesProcessed += 1

                        // Report progress every 10 files or on completion
                        if let handler = progressHandler,
                            filesProcessed % 10 == 0 || filesProcessed == totalFiles
                        {
                            handler(filesProcessed, totalFiles)
                        }
                    }
                }
                // Archive is released here when it goes out of scope
            }

            // Ensure the archive is fully written to disk before proceeding
            // This is critical for test reliability where files are accessed immediately
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

            // Verify the archive was created successfully
            guard FileManager.default.fileExists(atPath: archiveURL.path) else {
                throw DataError.failedCreateZip
            }

            // Set proper permissions on the archive
            try FileManager.default.setAttributes(
                [
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

            print("Photo copy completed with \(failedCopies.count) failures:")
            if notFoundCount > 0 {
                print("   \(notFoundCount) photos not found (may have been deleted)")
            }
            if otherErrors > 0 {
                print("   \(otherErrors) photos failed due to other errors")
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

            print("Photo copy completed with \(failedCopies.count) failures:")
            if notFoundCount > 0 {
                print("   \(notFoundCount) photos not found (may have been deleted)")
            }
            if otherErrors > 0 {
                print("   \(otherErrors) photos failed due to other errors")
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
        let sanitized =
            filename
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
                "Title", "Description", "Location", "Label", "Home", "Quantity", "Serial", "Model", "Make",
                "Price", "Insured", "Notes", "PhotoFilename", "HasUsedAI",
            ]
            lines.append(header.joined(separator: ","))

            for item in items {
                let row: [String] = [
                    item.title,
                    item.desc,
                    item.locationName,
                    item.labelName,
                    item.homeName,
                    String(item.quantity),
                    item.serial,
                    item.model,
                    item.make,
                    item.price.description,
                    item.insured ? "true" : "false",
                    item.notes,
                    item.imageURL?.lastPathComponent ?? "",
                    item.hasUsedAI ? "true" : "false",
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
        } else {
            return value
        }
    }

    private nonisolated func parseCSVRow(_ row: String) -> [String] {
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
                    location.imageURL?.lastPathComponent ?? "",
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
                let colorHex =
                    label.color.map { color -> String in
                        var red: CGFloat = 0
                        var green: CGFloat = 0
                        var blue: CGFloat = 0
                        var alpha: CGFloat = 0
                        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                        return String(
                            format: "#%02X%02X%02X",
                            Int(red * 255),
                            Int(green * 255),
                            Int(blue * 255))
                    } ?? ""

                let row: [String] = [
                    label.name,
                    label.desc,
                    colorHex,
                    label.emoji,
                ]
                lines.append(row.map(Self.escapeForCSV).joined(separator: ","))
            }
            return lines
        }()

        let csvString = csvLines.joined(separator: "\n")
        try csvString.data(using: .utf8)?.write(to: url)
    }

    /// Exports specific SQLiteInventoryItems (and their photos) along with all locations and labels into a zip file
    func exportSpecificItems(items: [SQLiteInventoryItem], database: any DatabaseWriter, fileName: String? = nil)
        async throws -> URL
    {
        guard !items.isEmpty else { throw DataError.nothingToExport }

        // Get all locations and labels
        let locationResult = try await fetchLocationsForExport(database: database)
        let labelData = try await fetchLabelsForExport(database: database)

        // Extract item data and collect photo URLs
        // SQLiteInventoryItem is a value type — no MainActor needed
        let (itemData, itemPhotoURLs): ([ItemData], [URL]) = try await database.read { db in
            var itemData: [ItemData] = []
            var photoURLs: [URL] = []

            for item in items {
                // Get location name and home name via foreign keys
                var locationName = ""
                var homeName = ""
                if let locationID = item.locationID {
                    if let location = try SQLiteInventoryLocation.find(locationID).fetchOne(db) {
                        locationName = location.name
                        if let homeID = location.homeID {
                            if let home = try SQLiteHome.find(homeID).fetchOne(db) {
                                homeName = home.name
                            }
                        }
                    }
                }

                // Get first label name via join table
                var labelName = ""
                let itemLabels =
                    try SQLiteInventoryItemLabel
                    .where { itemLabel in itemLabel.inventoryItemID == item.id }
                    .fetchAll(db)
                if let firstItemLabel = itemLabels.first {
                    if let label = try SQLiteInventoryLabel.find(firstItemLabel.inventoryLabelID).fetchOne(db) {
                        labelName = label.name
                    }
                }

                let data: ItemData = (
                    title: item.title,
                    desc: item.desc,
                    locationName: locationName,
                    labelName: labelName,
                    homeName: homeName,
                    quantity: item.quantityInt,
                    serial: item.serial,
                    model: item.model,
                    make: item.make,
                    price: item.price,
                    insured: item.insured,
                    notes: item.notes,
                    imageURL: nil,
                    hasUsedAI: item.hasUsedAI
                )
                itemData.append(data)
            }

            return (itemData, photoURLs)
        }

        let locationData = locationResult.locations
        var allPhotoURLs = itemPhotoURLs
        allPhotoURLs.append(contentsOf: locationResult.photoURLs)

        let archiveName =
            fileName ?? "Selected-Items-export-\(DateFormatter.exportDateFormatter.string(from: .init()))"
            .replacingOccurrences(of: " ", with: "-") + ".zip"

        // Working directory in tmp
        let workingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        let photosDir = workingRoot.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(
            at: photosDir,
            withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [
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

extension DateFormatter {
    fileprivate static let exportDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

extension UIColor {
    fileprivate convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
