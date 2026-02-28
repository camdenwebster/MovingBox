//
//  DataManager.swift
//  MovingBox
//
//  Created by Camden Webster on 5/1/25.
//

import Foundation
import GRDB
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
        case invalidDatabaseArchive
        case restoreStagingFailed
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
            } else if description.contains("invalidDatabaseArchive") {
                return "This database backup archive is invalid. Use a backup exported from MovingBox."
            } else if description.contains("restoreStagingFailed") {
                return "Unable to stage the database restore. Please try selecting the backup again."
            } else if description.contains("photoNotFound") {
                return "Some photos could not be found during the import process."
            } else if description.contains("fileAccessDenied") {
                return "Unable to access the selected file. Please check file permissions and try again."
            } else if description.contains("fileTooLarge") {
                return "One or more images exceed the 100MB size limit and cannot be imported."
            } else if description.contains("invalidFileType") {
                return "Invalid image file type detected. Only JPG, PNG, and HEIC formats are supported."
            } else if description.contains("containerNotConfigured") {
                return "Database export is only available when MovingBox is using an on-device SQLite file."
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
            } else if description.contains("invalidDatabaseArchive") {
                return "Select a ZIP archive created by MovingBox's Database export option."
            } else if description.contains("restoreStagingFailed") {
                return "Ensure the archive is still available and you have free storage, then try again."
            } else if description.contains("photoNotFound") {
                return "The import will continue, but some images may be missing from your inventory."
            } else if description.contains("fileAccessDenied") {
                return "Try moving the file to a different location or grant the app permission to access it."
            } else if description.contains("fileTooLarge") {
                return "Try compressing the images before exporting, or remove some items from the export."
            } else if description.contains("invalidFileType") {
                return "Convert unsupported images to JPG, PNG, or HEIC format before importing."
            } else if description.contains("containerNotConfigured") {
                return "Switch to a persistent database (not in-memory test mode) and try exporting again."
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
        config: ExportConfig = ExportConfig()
    ) -> AsyncStream<ExportProgress> {
        AsyncStream { continuation in
            Task {
                do {
                    continuation.yield(.preparing)

                    var itemData: [ItemData] = []
                    var locationData: [LocationData] = []
                    var labelData: [LabelData] = []
                    var homeData: [HomeData] = []
                    var insurancePolicyData: [InsurancePolicyData] = []
                    var allPhotoFiles: [ExportPhotoFile] = []

                    var totalSteps = 0
                    var completedSteps = 0

                    if config.includeItems { totalSteps += 1 }
                    if config.includeLocations { totalSteps += 1 }
                    if config.includeLabels { totalSteps += 1 }
                    if config.includeHomes { totalSteps += 1 }
                    if config.includeInsurancePolicies { totalSteps += 1 }
                    totalSteps += 2  // CSV writing + archiving
                    if config.includePhotos { totalSteps += 1 }  // photo copying

                    // Fetch data with progress
                    if config.includeItems {
                        continuation.yield(.fetchingData(phase: "items", progress: 0.0))
                        let result = try await self.fetchItemsForExport(
                            database: database,
                            includedHomeIDs: config.includedHomeIDs,
                            includePhotos: config.includePhotos
                        )
                        itemData = result.items
                        allPhotoFiles.append(contentsOf: result.photos)

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
                        let result = try await self.fetchLocationsForExport(
                            database: database,
                            includedHomeIDs: config.includedHomeIDs,
                            includePhotos: config.includePhotos
                        )
                        locationData = result.locations
                        allPhotoFiles.append(contentsOf: result.photos)

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

                    if config.includeHomes {
                        continuation.yield(
                            .fetchingData(phase: "homes", progress: Double(completedSteps) / Double(totalSteps)))
                        let result = try await self.fetchHomesForExport(
                            database: database,
                            includedHomeIDs: config.includedHomeIDs,
                            includePhotos: config.includePhotos
                        )
                        homeData = result.homes
                        allPhotoFiles.append(contentsOf: result.photos)

                        completedSteps += 1
                        continuation.yield(
                            .fetchingData(phase: "homes", progress: Double(completedSteps) / Double(totalSteps)))
                    }

                    if config.includeInsurancePolicies {
                        continuation.yield(
                            .fetchingData(
                                phase: "insurance policies", progress: Double(completedSteps) / Double(totalSteps)))
                        insurancePolicyData = try await self.fetchInsurancePoliciesForExport(
                            database: database,
                            includedHomeIDs: config.includedHomeIDs
                        )

                        completedSteps += 1
                        continuation.yield(
                            .fetchingData(
                                phase: "insurance policies", progress: Double(completedSteps) / Double(totalSteps)))
                    }

                    guard
                        !itemData.isEmpty || !locationData.isEmpty || !labelData.isEmpty || !homeData.isEmpty
                            || !insurancePolicyData.isEmpty
                    else {
                        throw DataError.nothingToExport
                    }

                    let archiveName =
                        fileName ?? "MovingBox-export-\(DateFormatter.exportDateFormatter.string(from: .init()))"
                        .replacingOccurrences(of: " ", with: "-") + ".zip"

                    // Working directory in tmp
                    let workingRoot = FileManager.default.temporaryDirectory
                        .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
                    try FileManager.default.createDirectory(at: workingRoot, withIntermediateDirectories: true)

                    let photosDir = workingRoot.appendingPathComponent("photos", isDirectory: true)
                    if config.includePhotos {
                        try FileManager.default.createDirectory(
                            at: photosDir,
                            withIntermediateDirectories: true)
                        try FileManager.default.setAttributes(
                            [
                                .posixPermissions: 0o755
                            ], ofItemAtPath: photosDir.path)
                    }

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

                    if config.includeHomes {
                        let homesCSVURL = workingRoot.appendingPathComponent("home-details.csv")
                        try await self.writeHomesCSV(homes: homeData, to: homesCSVURL)
                    }

                    if config.includeInsurancePolicies {
                        let insurancePoliciesCSVURL = workingRoot.appendingPathComponent(
                            "insurance-policy-details.csv")
                        try await self.writeInsurancePoliciesCSV(
                            policies: insurancePolicyData,
                            to: insurancePoliciesCSVURL
                        )
                    }

                    completedSteps += 1
                    continuation.yield(.writingCSV(progress: Double(completedSteps) / Double(totalSteps)))

                    // Copy photos with progress
                    if config.includePhotos {
                        if !allPhotoFiles.isEmpty {
                            try await self.writePhotosToDirectoryWithProgress(
                                photos: allPhotoFiles,
                                destinationDir: photosDir,
                                progressHandler: { current, total in
                                    continuation.yield(.copyingPhotos(current: current, total: total))
                                }
                            )
                        }

                        completedSteps += 1
                    }

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
                        homeCount: homeData.count,
                        insurancePolicyCount: insurancePolicyData.count,
                        photoCount: allPhotoFiles.count
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
        config: ExportConfig = ExportConfig()
    ) async throws -> URL {
        var itemData: [ItemData] = []
        var locationData: [LocationData] = []
        var labelData: [LabelData] = []
        var homeData: [HomeData] = []
        var insurancePolicyData: [InsurancePolicyData] = []
        var allPhotoFiles: [ExportPhotoFile] = []

        // Fetch data — sqlite-data structs are value types, no MainActor needed
        if config.includeItems {
            let result = try await fetchItemsForExport(
                database: database,
                includedHomeIDs: config.includedHomeIDs,
                includePhotos: config.includePhotos
            )
            itemData = result.items
            allPhotoFiles.append(contentsOf: result.photos)

            let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
            TelemetryManager.shared.trackExportBatchSize(
                batchSize: Self.batchSize,
                deviceMemoryGB: memoryGB,
                itemCount: result.items.count
            )
        }

        if config.includeLocations {
            let result = try await fetchLocationsForExport(
                database: database,
                includedHomeIDs: config.includedHomeIDs,
                includePhotos: config.includePhotos
            )
            locationData = result.locations
            allPhotoFiles.append(contentsOf: result.photos)
        }

        if config.includeLabels {
            labelData = try await fetchLabelsForExport(database: database)
        }

        if config.includeHomes {
            let result = try await fetchHomesForExport(
                database: database,
                includedHomeIDs: config.includedHomeIDs,
                includePhotos: config.includePhotos
            )
            homeData = result.homes
            allPhotoFiles.append(contentsOf: result.photos)
        }

        if config.includeInsurancePolicies {
            insurancePolicyData = try await fetchInsurancePoliciesForExport(
                database: database,
                includedHomeIDs: config.includedHomeIDs
            )
        }

        // Don't export if nothing is selected
        guard
            !itemData.isEmpty || !locationData.isEmpty || !labelData.isEmpty || !homeData.isEmpty
                || !insurancePolicyData.isEmpty
        else {
            throw DataError.nothingToExport
        }

        let archiveName =
            fileName ?? "MovingBox-export-\(DateFormatter.exportDateFormatter.string(from: .init()))"
            .replacingOccurrences(of: " ", with: "-") + ".zip"

        // Working directory in tmp
        let workingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: workingRoot,
            withIntermediateDirectories: true)

        let photosDir = workingRoot.appendingPathComponent("photos", isDirectory: true)
        if config.includePhotos {
            try FileManager.default.createDirectory(
                at: photosDir,
                withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [
                    .posixPermissions: 0o755
                ], ofItemAtPath: photosDir.path)
        }

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

        if config.includeHomes {
            let homesCSVURL = workingRoot.appendingPathComponent("home-details.csv")
            try await writeHomesCSV(homes: homeData, to: homesCSVURL)
        }

        if config.includeInsurancePolicies {
            let insurancePoliciesCSVURL = workingRoot.appendingPathComponent("insurance-policy-details.csv")
            try await writeInsurancePoliciesCSV(
                policies: insurancePolicyData,
                to: insurancePoliciesCSVURL
            )
        }

        // Write photo BLOB payloads into the ZIP staging directory.
        if config.includePhotos {
            let uniquePhotoFiles = Array(Set(allPhotoFiles))
            try await writePhotosToDirectory(photos: uniquePhotoFiles, destinationDir: photosDir)
        }

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

    func exportDatabaseArchive(
        database: any DatabaseWriter,
        fileName: String? = nil
    ) async throws -> URL {
        let sqliteFiles = try await fetchSQLiteFilesForExport(database: database)

        let archiveName =
            fileName ?? "MovingBox-database-\(DateFormatter.exportDateFormatter.string(from: .init()))"
            .replacingOccurrences(of: " ", with: "-") + ".zip"

        let workingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("database-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workingRoot, withIntermediateDirectories: true)

        for sourceURL in sqliteFiles {
            let destinationURL = workingRoot.appendingPathComponent(sourceURL.lastPathComponent)
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }

        let archiveURL = try await createArchive(from: workingRoot, archiveName: archiveName)

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
        let includeHomes: Bool
        let includeInsurancePolicies: Bool
        let includePhotos: Bool
        let includedHomeIDs: Set<UUID>?

        init(
            includeItems: Bool = true,
            includeLocations: Bool = true,
            includeLabels: Bool = true,
            includeHomes: Bool = true,
            includeInsurancePolicies: Bool = true,
            includePhotos: Bool = true,
            includedHomeIDs: Set<UUID>? = nil
        ) {
            self.includeItems = includeItems
            self.includeLocations = includeLocations
            self.includeLabels = includeLabels
            self.includeHomes = includeHomes
            self.includeInsurancePolicies = includeInsurancePolicies
            self.includePhotos = includePhotos
            self.includedHomeIDs = includedHomeIDs
        }
    }

    struct ImportConfig {
        let format: ImportFormat
        let includeItems: Bool
        let includeLocations: Bool
        let includeLabels: Bool
        let includeHomes: Bool
        let includeInsurancePolicies: Bool

        init(
            format: ImportFormat = .csvArchive,
            includeItems: Bool = true,
            includeLocations: Bool = true,
            includeLabels: Bool = true,
            includeHomes: Bool = true,
            includeInsurancePolicies: Bool = true
        ) {
            self.format = format
            self.includeItems = includeItems
            self.includeLocations = includeLocations
            self.includeLabels = includeLabels
            self.includeHomes = includeHomes
            self.includeInsurancePolicies = includeInsurancePolicies
        }
    }

    enum ImportFormat: String, CaseIterable, Sendable {
        case csvArchive
        case movingBoxDatabase
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
        let homeCount: Int
        let insurancePolicyCount: Int
        let requiresRestart: Bool

        init(
            itemCount: Int,
            locationCount: Int,
            labelCount: Int,
            homeCount: Int = 0,
            insurancePolicyCount: Int = 0,
            requiresRestart: Bool = false
        ) {
            self.itemCount = itemCount
            self.locationCount = locationCount
            self.labelCount = labelCount
            self.homeCount = homeCount
            self.insurancePolicyCount = insurancePolicyCount
            self.requiresRestart = requiresRestart
        }
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
        let homeCount: Int
        let insurancePolicyCount: Int
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

    private struct ItemData: Sendable {
        let id: UUID
        let title: String
        let quantityString: String
        let quantityInt: Int
        let desc: String
        let serial: String
        let model: String
        let make: String
        let price: Decimal
        let insured: Bool
        let assetId: String
        let notes: String
        let replacementCost: Decimal?
        let depreciationRate: Double?
        let hasUsedAI: Bool
        let createdAt: Date
        let purchaseDate: Date?
        let warrantyExpirationDate: Date?
        let purchaseLocation: String
        let condition: String
        let hasWarranty: Bool
        let attachmentsJSON: String
        let dimensionLength: String
        let dimensionWidth: String
        let dimensionHeight: String
        let dimensionUnit: String
        let weightValue: String
        let weightUnit: String
        let color: String
        let storageRequirements: String
        let isFragile: Bool
        let movingPriority: Int
        let roomDestination: String
        let locationID: UUID?
        let locationName: String
        let homeID: UUID?
        let homeName: String
        let labelNames: [String]
        let photoFilenames: [String]
    }

    private struct LocationData: Sendable {
        let id: UUID
        let name: String
        let desc: String
        let homeID: UUID?
        let homeName: String
        let photoFilename: String?
    }

    private struct HomeData: Sendable {
        let id: UUID
        let name: String
        let address1: String
        let address2: String
        let city: String
        let state: String
        let zip: String
        let country: String
        let purchaseDate: Date
        let purchasePrice: Decimal
        let isPrimary: Bool
        let colorName: String
        let photoFilename: String?
    }

    private struct ExportPhotoFile: Sendable, Hashable {
        let filename: String
        let data: Data
    }

    private struct LabelData: Sendable {
        let name: String
        let desc: String
        let color: UIColor?
        let emoji: String
    }

    private struct InsurancePolicyData: Sendable {
        let id: UUID
        let providerName: String
        let policyNumber: String
        let deductibleAmount: Decimal
        let dwellingCoverageAmount: Decimal
        let personalPropertyCoverageAmount: Decimal
        let lossOfUseCoverageAmount: Decimal
        let liabilityCoverageAmount: Decimal
        let medicalPaymentsCoverageAmount: Decimal
        let startDate: Date
        let endDate: Date
        let homeIDs: [UUID]
        let homeNames: [String]
    }

    /// Preview import without actually creating objects - just validates and counts
    func previewImport(
        from zipURL: URL,
        config: ImportConfig = ImportConfig()
    ) async throws -> ImportResult {
        try await Task.detached(priority: .userInitiated) {
            guard FileManager.default.isReadableFile(atPath: zipURL.path) else {
                throw DataError.fileAccessDenied
            }

            switch config.format {
            case .csvArchive:
                let workingDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("preview-\(UUID().uuidString)", isDirectory: true)
                defer {
                    try? FileManager.default.removeItem(at: workingDir)
                }

                do {
                    try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
                    try FileManager.default.unzipItem(at: zipURL, to: workingDir)
                } catch {
                    throw DataError.invalidZipFile
                }

                let itemCount = try self.previewCSVCount(
                    at: workingDir.appendingPathComponent("inventory.csv"),
                    enabled: config.includeItems
                )
                let locationCount = try self.previewCSVCount(
                    at: workingDir.appendingPathComponent("locations.csv"),
                    enabled: config.includeLocations
                )
                let labelCount = try self.previewCSVCount(
                    at: workingDir.appendingPathComponent("labels.csv"),
                    enabled: config.includeLabels
                )
                let homeCount = try self.previewCSVCount(
                    at: workingDir.appendingPathComponent("home-details.csv"),
                    enabled: config.includeHomes
                )
                let insurancePolicyCount = try self.previewCSVCount(
                    at: workingDir.appendingPathComponent("insurance-policy-details.csv"),
                    enabled: config.includeInsurancePolicies
                )

                return ImportResult(
                    itemCount: itemCount,
                    locationCount: locationCount,
                    labelCount: labelCount,
                    homeCount: homeCount,
                    insurancePolicyCount: insurancePolicyCount,
                    requiresRestart: false
                )

            case .movingBoxDatabase:
                do {
                    try validateDatabaseBackupArchive(at: zipURL)
                } catch {
                    throw DataError.invalidDatabaseArchive
                }
                return ImportResult(
                    itemCount: 0,
                    locationCount: 0,
                    labelCount: 0,
                    homeCount: 0,
                    insurancePolicyCount: 0,
                    requiresRestart: true
                )
            }
        }.value
    }

    /// Imports inventory from a zip file and reports progress through an async sequence.
    func importInventory(
        from zipURL: URL,
        database: any DatabaseWriter,
        config: ImportConfig = ImportConfig()
    ) -> AsyncStream<ImportProgress> {
        AsyncStream { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    guard FileManager.default.isReadableFile(atPath: zipURL.path) else {
                        throw DataError.fileAccessDenied
                    }

                    switch config.format {
                    case .movingBoxDatabase:
                        do {
                            try stagePendingDatabaseRestoreArchive(from: zipURL)
                        } catch let error as PendingDatabaseRestoreError {
                            switch error {
                            case .invalidArchive, .missingDatabaseFile, .multipleDatabaseFiles,
                                .unsupportedDatabaseExtension, .unexpectedArchiveContents:
                                throw DataError.invalidDatabaseArchive
                            default:
                                throw DataError.restoreStagingFailed
                            }
                        } catch {
                            throw DataError.restoreStagingFailed
                        }
                        continuation.yield(
                            .completed(
                                ImportResult(
                                    itemCount: 0,
                                    locationCount: 0,
                                    labelCount: 0,
                                    homeCount: 0,
                                    insurancePolicyCount: 0,
                                    requiresRestart: true
                                )
                            )
                        )
                        continuation.finish()

                    case .csvArchive:
                        let result = try await self.importCSVArchive(
                            from: zipURL,
                            database: database,
                            config: config
                        ) { progress in
                            continuation.yield(.progress(progress))
                        }
                        continuation.yield(.completed(result))
                        continuation.finish()
                    }
                } catch {
                    continuation.yield(.error(SendableError(error)))
                    continuation.finish()
                }
            }
        }
    }

    private enum PhotoImportTarget: Sendable {
        case item(UUID)
        case location(UUID)
        case home(UUID)
    }

    private struct ImageImportTask: Sendable {
        let sourceURL: URL
        let target: PhotoImportTarget
        let sortOrder: Int
    }

    private struct ItemImportEntry: Sendable {
        let item: SQLiteInventoryItem
        let labelIDs: [UUID]
        let photoURLs: [URL]
    }

    private struct GeneratedLabelEntry: Sendable {
        let id: UUID
        let householdID: UUID?
        let name: String
    }

    private struct PolicyImportEntry: Sendable {
        let policy: SQLiteInsurancePolicy
        let homeIDs: [UUID]
    }

    private func importCSVArchive(
        from zipURL: URL,
        database: any DatabaseWriter,
        config: ImportConfig,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> ImportResult {
        let workingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: workingDir)
        }

        do {
            try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: zipURL, to: workingDir)
        } catch {
            throw DataError.invalidZipFile
        }

        let itemsCSVURL = workingDir.appendingPathComponent("inventory.csv")
        let locationsCSVURL = workingDir.appendingPathComponent("locations.csv")
        let labelsCSVURL = workingDir.appendingPathComponent("labels.csv")
        let homesCSVURL = workingDir.appendingPathComponent("home-details.csv")
        let insurancePoliciesCSVURL = workingDir.appendingPathComponent("insurance-policy-details.csv")
        let photosDir = workingDir.appendingPathComponent("photos")

        let itemRows = try readCSVRowsIfExists(at: itemsCSVURL)
        let locationRows = try readCSVRowsIfExists(at: locationsCSVURL)
        let labelRows = try readCSVRowsIfExists(at: labelsCSVURL)
        let homeRows = try readCSVRowsIfExists(at: homesCSVURL)
        let insuranceRows = try readCSVRowsIfExists(at: insurancePoliciesCSVURL)

        var totalRows = 0
        if config.includeHomes { totalRows += max(0, homeRows.count - 1) }
        if config.includeLocations { totalRows += max(0, locationRows.count - 1) }
        if config.includeLabels { totalRows += max(0, labelRows.count - 1) }
        if config.includeItems { totalRows += max(0, itemRows.count - 1) }
        if config.includeInsurancePolicies { totalRows += max(0, insuranceRows.count - 1) }
        guard totalRows > 0 else { throw DataError.invalidCSVFormat }

        var processedRows = 0
        func updateProgress() {
            let current = min(max(Double(processedRows) / Double(totalRows), 0), 1)
            progress(current)
        }

        var locationCount = 0
        var labelCount = 0
        var itemCount = 0
        var homeCount = 0
        var insurancePolicyCount = 0

        let householdID = try await database.read { db in
            try SQLiteHousehold.order(by: \.createdAt).fetchOne(db)?.id
        }

        let existingHomes = try await database.read { db in
            try SQLiteHome.fetchAll(db)
        }
        var homeCacheBySourceID: [String: UUID] = Dictionary(
            uniqueKeysWithValues: existingHomes.map { ($0.id.uuidString.lowercased(), $0.id) }
        )
        var homeCacheByName: [String: UUID] = [:]
        for home in existingHomes where !home.name.isEmpty {
            homeCacheByName[home.name.lowercased()] = home.id
        }

        let existingLocations = try await database.read { db in
            try SQLiteInventoryLocation.fetchAll(db)
        }
        var locationCacheBySourceID: [String: UUID] = Dictionary(
            uniqueKeysWithValues: existingLocations.map { ($0.id.uuidString.lowercased(), $0.id) }
        )
        var locationCacheByName: [String: UUID] = [:]
        var locationHomeCache: [UUID: UUID] = [:]
        for location in existingLocations where !location.name.isEmpty {
            locationCacheByName[location.name.lowercased()] = location.id
            if let homeID = location.homeID {
                locationHomeCache[location.id] = homeID
            }
        }

        let existingLabels = try await database.read { db in
            try SQLiteInventoryLabel.fetchAll(db)
        }
        var labelCache: [String: UUID] = [:]
        for label in existingLabels where !label.name.isEmpty {
            labelCache[label.name.lowercased()] = label.id
        }

        var imageImportTasks: [ImageImportTask] = []

        func normalize(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        func value(
            for keys: [String],
            values: [String],
            index: [String: Int]
        ) -> String {
            for key in keys {
                if let headerIndex = index[key], headerIndex < values.count {
                    return values[headerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return ""
        }

        func splitList(_ value: String) -> [String] {
            value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        func resolveHomeID(homeIDString: String, homeName: String) -> UUID? {
            let normalizedID = normalize(homeIDString)
            if !normalizedID.isEmpty, let cached = homeCacheBySourceID[normalizedID] {
                return cached
            }
            let normalizedName = normalize(homeName)
            if !normalizedName.isEmpty, let cached = homeCacheByName[normalizedName] {
                return cached
            }
            return nil
        }

        if config.includeHomes, homeRows.count > 1 {
            let headers = homeRows[0]
            let index = Dictionary(
                uniqueKeysWithValues: headers.enumerated().map {
                    ($1.lowercased().replacingOccurrences(of: " ", with: ""), $0)
                }
            )

            var homesToInsert: [(sourceID: String, home: SQLiteHome, photoURL: URL?)] = []
            homesToInsert.reserveCapacity(homeRows.count - 1)

            for row in homeRows.dropFirst() {
                let sourceHomeID = normalize(value(for: ["homeid"], values: row, index: index))
                let name = value(for: ["name"], values: row, index: index)
                let homeID = UUID()
                let photoFilename = value(for: ["photofilename"], values: row, index: index)
                var photoURL: URL?
                if !photoFilename.isEmpty {
                    let candidate = photosDir.appendingPathComponent(self.sanitizeFilename(photoFilename))
                    if FileManager.default.fileExists(atPath: candidate.path) {
                        photoURL = candidate
                    }
                }

                homesToInsert.append(
                    (
                        sourceID: sourceHomeID,
                        home: SQLiteHome(
                            id: homeID,
                            name: name,
                            address1: value(for: ["address1"], values: row, index: index),
                            address2: value(for: ["address2"], values: row, index: index),
                            city: value(for: ["city"], values: row, index: index),
                            state: value(for: ["state"], values: row, index: index),
                            zip: value(for: ["zip"], values: row, index: index),
                            country: value(for: ["country"], values: row, index: index),
                            purchaseDate: self.parseCSVDate(value(for: ["purchasedate"], values: row, index: index))
                                ?? Date(),
                            purchasePrice: self.parseDecimal(value(for: ["purchaseprice"], values: row, index: index))
                                ?? 0,
                            isPrimary: self.parseBool(value(for: ["isprimary"], values: row, index: index)),
                            colorName: value(for: ["colorname"], values: row, index: index).isEmpty
                                ? "green" : value(for: ["colorname"], values: row, index: index),
                            householdID: householdID,
                            isPrivate: false
                        ),
                        photoURL: photoURL
                    )
                )

                processedRows += 1
                if processedRows % 25 == 0 || processedRows == totalRows { updateProgress() }
            }

            try await database.write { db in
                for entry in homesToInsert {
                    try SQLiteHome.insert { entry.home }.execute(db)
                }
            }

            for entry in homesToInsert {
                if !entry.sourceID.isEmpty {
                    homeCacheBySourceID[entry.sourceID] = entry.home.id
                }
                if !entry.home.name.isEmpty {
                    homeCacheByName[entry.home.name.lowercased()] = entry.home.id
                }
                if let photoURL = entry.photoURL {
                    imageImportTasks.append(
                        ImageImportTask(
                            sourceURL: photoURL,
                            target: .home(entry.home.id),
                            sortOrder: 0
                        )
                    )
                }
                homeCount += 1
            }
        }

        if config.includeLocations, locationRows.count > 1 {
            let headers = locationRows[0]
            let index = Dictionary(
                uniqueKeysWithValues: headers.enumerated().map {
                    ($1.lowercased().replacingOccurrences(of: " ", with: ""), $0)
                }
            )

            var locationsToInsert: [(sourceID: String, location: SQLiteInventoryLocation, photoURL: URL?)] = []
            locationsToInsert.reserveCapacity(locationRows.count - 1)

            for row in locationRows.dropFirst() {
                let sourceLocationID = normalize(value(for: ["locationid"], values: row, index: index))
                let locationID = UUID()
                let name = value(for: ["name"], values: row, index: index)
                let homeID = resolveHomeID(
                    homeIDString: value(for: ["homeid"], values: row, index: index),
                    homeName: value(for: ["home"], values: row, index: index)
                )
                let photoFilename = value(for: ["photofilename"], values: row, index: index)
                var photoURL: URL?
                if !photoFilename.isEmpty {
                    let candidate = photosDir.appendingPathComponent(self.sanitizeFilename(photoFilename))
                    if FileManager.default.fileExists(atPath: candidate.path) {
                        photoURL = candidate
                    }
                }

                let location = SQLiteInventoryLocation(
                    id: locationID,
                    name: name,
                    desc: value(for: ["description", "desc"], values: row, index: index),
                    sfSymbolName: nil,
                    homeID: homeID
                )
                locationsToInsert.append((sourceID: sourceLocationID, location: location, photoURL: photoURL))

                processedRows += 1
                if processedRows % 25 == 0 || processedRows == totalRows { updateProgress() }
            }

            try await database.write { db in
                for entry in locationsToInsert {
                    try SQLiteInventoryLocation.insert { entry.location }.execute(db)
                }
            }

            for entry in locationsToInsert {
                if !entry.sourceID.isEmpty {
                    locationCacheBySourceID[entry.sourceID] = entry.location.id
                }
                if !entry.location.name.isEmpty {
                    locationCacheByName[entry.location.name.lowercased()] = entry.location.id
                }
                if let homeID = entry.location.homeID {
                    locationHomeCache[entry.location.id] = homeID
                }
                if let photoURL = entry.photoURL {
                    imageImportTasks.append(
                        ImageImportTask(
                            sourceURL: photoURL,
                            target: .location(entry.location.id),
                            sortOrder: 0
                        )
                    )
                }
                locationCount += 1
            }
        }

        if config.includeLabels, labelRows.count > 1 {
            let headers = labelRows[0]
            let index = Dictionary(
                uniqueKeysWithValues: headers.enumerated().map {
                    ($1.lowercased().replacingOccurrences(of: " ", with: ""), $0)
                }
            )

            var labelsToInsert: [SQLiteInventoryLabel] = []
            labelsToInsert.reserveCapacity(labelRows.count - 1)
            for row in labelRows.dropFirst() {
                let name = value(for: ["name"], values: row, index: index)
                let label = SQLiteInventoryLabel(
                    id: UUID(),
                    householdID: householdID,
                    name: name,
                    desc: value(for: ["description", "desc"], values: row, index: index),
                    color: Self.parseHexColor(value(for: ["colorhex"], values: row, index: index)),
                    emoji: value(for: ["emoji"], values: row, index: index)
                )
                labelsToInsert.append(label)
                processedRows += 1
                if processedRows % 25 == 0 || processedRows == totalRows { updateProgress() }
            }

            try await database.write { db in
                for label in labelsToInsert {
                    try SQLiteInventoryLabel.insert { label }.execute(db)
                }
            }

            for label in labelsToInsert {
                if !label.name.isEmpty {
                    labelCache[label.name.lowercased()] = label.id
                }
                labelCount += 1
            }
        }

        if config.includeItems, itemRows.count > 1 {
            let headers = itemRows[0]
            let index = Dictionary(
                uniqueKeysWithValues: headers.enumerated().map {
                    ($1.lowercased().replacingOccurrences(of: " ", with: ""), $0)
                }
            )

            let photoColumnIndices: [Int] = headers.enumerated().compactMap { headerIndex, value in
                let normalized = value.lowercased().replacingOccurrences(of: " ", with: "")
                return normalized.hasPrefix("photofilename") ? headerIndex : nil
            }

            var itemsToInsert: [ItemImportEntry] = []
            var generatedLocations: [SQLiteInventoryLocation] = []
            var generatedLabels: [GeneratedLabelEntry] = []

            for row in itemRows.dropFirst() {
                let title = value(for: ["title"], values: row, index: index)
                guard !title.isEmpty else { continue }

                let locationName = value(for: ["location"], values: row, index: index)
                let sourceLocationID = normalize(value(for: ["locationid"], values: row, index: index))
                var resolvedHomeID = resolveHomeID(
                    homeIDString: value(for: ["homeid"], values: row, index: index),
                    homeName: value(for: ["home"], values: row, index: index)
                )

                var locationID: UUID?
                if config.includeLocations {
                    if !sourceLocationID.isEmpty, let cached = locationCacheBySourceID[sourceLocationID] {
                        locationID = cached
                    } else if let cached = locationCacheByName[locationName.lowercased()] {
                        locationID = cached
                    } else if !locationName.isEmpty {
                        let generatedLocationID = UUID()
                        let generatedLocation = SQLiteInventoryLocation(
                            id: generatedLocationID,
                            name: locationName,
                            desc: "",
                            sfSymbolName: nil,
                            homeID: resolvedHomeID
                        )
                        generatedLocations.append(generatedLocation)
                        locationCacheByName[locationName.lowercased()] = generatedLocationID
                        locationID = generatedLocationID
                    }
                }

                if resolvedHomeID == nil, let locationID, let homeID = locationHomeCache[locationID] {
                    resolvedHomeID = homeID
                }

                let labelNames = splitList(value(for: ["label"], values: row, index: index))
                var labelIDs: [UUID] = []
                if config.includeLabels {
                    var seenLabelIDs: Set<UUID> = []
                    for labelName in labelNames.prefix(5) {
                        let key = labelName.lowercased()
                        let labelID: UUID
                        if let cached = labelCache[key] {
                            labelID = cached
                        } else {
                            let generatedLabelID = UUID()
                            labelCache[key] = generatedLabelID
                            generatedLabels.append(
                                GeneratedLabelEntry(
                                    id: generatedLabelID,
                                    householdID: householdID,
                                    name: labelName
                                )
                            )
                            labelID = generatedLabelID
                        }
                        if !seenLabelIDs.contains(labelID) {
                            seenLabelIDs.insert(labelID)
                            labelIDs.append(labelID)
                        }
                    }
                }

                let photoURLs: [URL] = photoColumnIndices.compactMap { photoIndex in
                    guard photoIndex < row.count else { return nil }
                    let filename = row[photoIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !filename.isEmpty else { return nil }
                    let candidate = photosDir.appendingPathComponent(self.sanitizeFilename(filename))
                    return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
                }

                var parsedItem = SQLiteInventoryItem(
                    id: UUID(),
                    title: title,
                    quantityString: value(for: ["quantitystring"], values: row, index: index).isEmpty
                        ? "1" : value(for: ["quantitystring"], values: row, index: index),
                    quantityInt: self.parseInt(value(for: ["quantityint"], values: row, index: index)) ?? 1,
                    desc: value(for: ["description", "desc"], values: row, index: index),
                    serial: value(for: ["serial"], values: row, index: index),
                    model: value(for: ["model"], values: row, index: index),
                    make: value(for: ["make"], values: row, index: index),
                    price: self.parseDecimal(value(for: ["price"], values: row, index: index)) ?? 0,
                    insured: self.parseBool(value(for: ["insured"], values: row, index: index)),
                    assetId: value(for: ["assetid"], values: row, index: index),
                    notes: value(for: ["notes"], values: row, index: index),
                    replacementCost: self.parseDecimal(value(for: ["replacementcost"], values: row, index: index)),
                    depreciationRate: self.parseDouble(value(for: ["depreciationrate"], values: row, index: index)),
                    hasUsedAI: self.parseBool(value(for: ["hasusedai"], values: row, index: index)),
                    createdAt: self.parseCSVDate(value(for: ["createdat"], values: row, index: index)) ?? Date(),
                    purchaseDate: self.parseCSVDate(value(for: ["purchasedate"], values: row, index: index)),
                    warrantyExpirationDate: self.parseCSVDate(
                        value(for: ["warrantyexpirationdate"], values: row, index: index)
                    ),
                    purchaseLocation: value(for: ["purchaselocation"], values: row, index: index),
                    condition: value(for: ["condition"], values: row, index: index),
                    hasWarranty: self.parseBool(value(for: ["haswarranty"], values: row, index: index)),
                    attachments: self.decodeAttachments(
                        from: value(for: ["attachmentsjson"], values: row, index: index)),
                    dimensionLength: value(for: ["dimensionlength"], values: row, index: index),
                    dimensionWidth: value(for: ["dimensionwidth"], values: row, index: index),
                    dimensionHeight: value(for: ["dimensionheight"], values: row, index: index),
                    dimensionUnit: value(for: ["dimensionunit"], values: row, index: index).isEmpty
                        ? "inches" : value(for: ["dimensionunit"], values: row, index: index),
                    weightValue: value(for: ["weightvalue"], values: row, index: index),
                    weightUnit: value(for: ["weightunit"], values: row, index: index).isEmpty
                        ? "lbs" : value(for: ["weightunit"], values: row, index: index),
                    color: value(for: ["color"], values: row, index: index),
                    storageRequirements: value(for: ["storagerequirements"], values: row, index: index),
                    isFragile: self.parseBool(value(for: ["isfragile"], values: row, index: index)),
                    movingPriority: self.parseInt(value(for: ["movingpriority"], values: row, index: index)) ?? 3,
                    roomDestination: value(for: ["roomdestination"], values: row, index: index),
                    locationID: locationID,
                    homeID: resolvedHomeID
                )
                parsedItem.labelIDs = labelIDs

                itemsToInsert.append(
                    ItemImportEntry(
                        item: parsedItem,
                        labelIDs: labelIDs,
                        photoURLs: photoURLs
                    )
                )

                processedRows += 1
                if processedRows % 25 == 0 || processedRows == totalRows { updateProgress() }
            }

            try await database.write { db in
                for location in generatedLocations {
                    try SQLiteInventoryLocation.insert { location }.execute(db)
                }
                for generatedLabel in generatedLabels {
                    try SQLiteInventoryLabel.insert {
                        SQLiteInventoryLabel(
                            id: generatedLabel.id,
                            householdID: generatedLabel.householdID,
                            name: generatedLabel.name,
                            desc: "",
                            color: nil,
                            emoji: ""
                        )
                    }.execute(db)
                }
                for entry in itemsToInsert {
                    try SQLiteInventoryItem.insert { entry.item }.execute(db)
                    for labelID in entry.labelIDs {
                        try SQLiteInventoryItemLabel.insert {
                            SQLiteInventoryItemLabel(
                                id: UUID(),
                                inventoryItemID: entry.item.id,
                                inventoryLabelID: labelID
                            )
                        }.execute(db)
                    }
                }
            }

            for location in generatedLocations {
                if let homeID = location.homeID {
                    locationHomeCache[location.id] = homeID
                }
                locationCount += 1
            }
            labelCount += generatedLabels.count
            itemCount += itemsToInsert.count

            for entry in itemsToInsert {
                for (sortOrder, photoURL) in entry.photoURLs.enumerated() {
                    imageImportTasks.append(
                        ImageImportTask(
                            sourceURL: photoURL,
                            target: .item(entry.item.id),
                            sortOrder: sortOrder
                        )
                    )
                }
            }
        }

        if config.includeInsurancePolicies, insuranceRows.count > 1 {
            let headers = insuranceRows[0]
            let index = Dictionary(
                uniqueKeysWithValues: headers.enumerated().map {
                    ($1.lowercased().replacingOccurrences(of: " ", with: ""), $0)
                }
            )

            var policiesToInsert: [PolicyImportEntry] = []
            policiesToInsert.reserveCapacity(insuranceRows.count - 1)
            for row in insuranceRows.dropFirst() {
                let policyID = UUID()
                let homeIDTokens = splitList(value(for: ["homeids"], values: row, index: index))
                let homeNameTokens = splitList(value(for: ["homes"], values: row, index: index))

                var resolvedHomeIDs: [UUID] = []
                for token in homeIDTokens {
                    if let cached = homeCacheBySourceID[token.lowercased()] {
                        resolvedHomeIDs.append(cached)
                    }
                }
                if resolvedHomeIDs.isEmpty {
                    for homeName in homeNameTokens {
                        if let cached = homeCacheByName[homeName.lowercased()] {
                            resolvedHomeIDs.append(cached)
                        }
                    }
                }

                let policy = SQLiteInsurancePolicy(
                    id: policyID,
                    providerName: value(for: ["providername"], values: row, index: index),
                    policyNumber: value(for: ["policynumber"], values: row, index: index),
                    deductibleAmount: self.parseDecimal(
                        value(for: ["deductibleamount"], values: row, index: index)
                    ) ?? 0,
                    dwellingCoverageAmount: self.parseDecimal(
                        value(for: ["dwellingcoverageamount"], values: row, index: index)
                    ) ?? 0,
                    personalPropertyCoverageAmount: self.parseDecimal(
                        value(for: ["personalpropertycoverageamount"], values: row, index: index)
                    ) ?? 0,
                    lossOfUseCoverageAmount: self.parseDecimal(
                        value(for: ["lossofusecoverageamount"], values: row, index: index)
                    ) ?? 0,
                    liabilityCoverageAmount: self.parseDecimal(
                        value(for: ["liabilitycoverageamount"], values: row, index: index)
                    ) ?? 0,
                    medicalPaymentsCoverageAmount: self.parseDecimal(
                        value(for: ["medicalpaymentscoverageamount"], values: row, index: index)
                    ) ?? 0,
                    startDate: self.parseCSVDate(value(for: ["startdate"], values: row, index: index))
                        ?? Date(),
                    endDate: self.parseCSVDate(value(for: ["enddate"], values: row, index: index))
                        ?? Date()
                )
                policiesToInsert.append(
                    PolicyImportEntry(
                        policy: policy,
                        homeIDs: Array(Set(resolvedHomeIDs))
                    )
                )

                processedRows += 1
                if processedRows % 25 == 0 || processedRows == totalRows { updateProgress() }
            }

            try await database.write { db in
                for entry in policiesToInsert {
                    try SQLiteInsurancePolicy.insert { entry.policy }.execute(db)
                    for homeID in entry.homeIDs {
                        try SQLiteHomeInsurancePolicy.insert {
                            SQLiteHomeInsurancePolicy(
                                id: UUID(),
                                homeID: homeID,
                                insurancePolicyID: entry.policy.id
                            )
                        }.execute(db)
                    }
                }
            }

            insurancePolicyCount += policiesToInsert.count
        }

        if !imageImportTasks.isEmpty {
            let imageBatchSize = 20
            for batchStart in stride(from: 0, to: imageImportTasks.count, by: imageBatchSize) {
                let batchEnd = min(batchStart + imageBatchSize, imageImportTasks.count)
                let batch = Array(imageImportTasks[batchStart..<batchEnd])

                let payloads: [(ImageImportTask, Data)] = try await withThrowingTaskGroup(
                    of: (ImageImportTask, Data).self
                ) { group in
                    for task in batch {
                        group.addTask {
                            try self.validateImageFile(task.sourceURL)
                            let data = try Data(contentsOf: task.sourceURL)
                            return (task, data)
                        }
                    }

                    var allPayloads: [(ImageImportTask, Data)] = []
                    for try await payload in group {
                        allPayloads.append(payload)
                    }
                    return allPayloads
                }

                try await database.write { db in
                    for (task, imageData) in payloads {
                        switch task.target {
                        case .item(let itemID):
                            try SQLiteInventoryItemPhoto.insert {
                                SQLiteInventoryItemPhoto(
                                    id: UUID(),
                                    inventoryItemID: itemID,
                                    data: imageData,
                                    sortOrder: task.sortOrder
                                )
                            }.execute(db)
                        case .location(let locationID):
                            try SQLiteInventoryLocationPhoto.insert {
                                SQLiteInventoryLocationPhoto(
                                    id: UUID(),
                                    inventoryLocationID: locationID,
                                    data: imageData,
                                    sortOrder: task.sortOrder
                                )
                            }.execute(db)
                        case .home(let homeID):
                            try SQLiteHomePhoto.insert {
                                SQLiteHomePhoto(
                                    id: UUID(),
                                    homeID: homeID,
                                    data: imageData,
                                    sortOrder: task.sortOrder
                                )
                            }.execute(db)
                        }
                    }
                }
            }
        }

        progress(1.0)
        return ImportResult(
            itemCount: itemCount,
            locationCount: locationCount,
            labelCount: labelCount,
            homeCount: homeCount,
            insurancePolicyCount: insurancePolicyCount,
            requiresRestart: false
        )
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

    private nonisolated func previewCSVCount(at url: URL, enabled: Bool) throws -> Int {
        guard enabled, FileManager.default.fileExists(atPath: url.path) else { return 0 }
        let rows = try readCSVRowsIfExists(at: url)
        return max(0, rows.count - 1)
    }

    private nonisolated func readCSVRowsIfExists(at url: URL) throws -> [[String]] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let csvString = try String(contentsOf: url, encoding: .utf8)
        let lines =
            csvString
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return lines.map(parseCSVRow)
    }

    private nonisolated func parseBool(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "true" || normalized == "1" || normalized == "yes"
    }

    private nonisolated func parseInt(_ value: String) -> Int? {
        Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private nonisolated func parseDouble(_ value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private nonisolated func parseDecimal(_ value: String) -> Decimal? {
        Decimal(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private nonisolated func parseCSVDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let date = Self.csvISO8601DateFormatter.date(from: trimmed) {
            return date
        }
        return Self.csvISO8601FallbackDateFormatter.date(from: trimmed)
    }

    private nonisolated func decodeAttachments(from json: String) -> [AttachmentInfo] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let data = trimmed.data(using: .utf8) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([AttachmentInfo].self, from: data)) ?? []
    }

    // MARK: - Fetch Helpers (Export)

    /// Fetches all inventory items with their related location/label/home names for export.
    ///
    /// Since sqlite-data models are value-type structs, no MainActor isolation is needed.
    /// Related data (location name, label name, home name) is fetched via separate queries
    /// using foreign key IDs.
    ///
    /// - Parameter database: DatabaseReader to read from
    /// - Returns: Tuple of (item data array, photo blobs to embed in ZIP)
    /// - Throws: DataError if fetch fails
    private func fetchItemsForExport(
        database: any DatabaseReader,
        includedHomeIDs: Set<UUID>?,
        includePhotos: Bool
    ) async throws -> (items: [ItemData], photos: [ExportPhotoFile]) {
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

            let allItemPhotos =
                try SQLiteInventoryItemPhoto
                .order(by: \.sortOrder)
                .fetchAll(db)
            let itemPhotosByItemID = Dictionary(
                grouping: allItemPhotos,
                by: \.inventoryItemID
            )

            var allItemData: [ItemData] = []
            var allPhotoFiles: [ExportPhotoFile] = []

            for item in items {
                let location = item.locationID.flatMap { locationsByID[$0] }
                let resolvedHomeID = item.homeID ?? location?.homeID

                if let includedHomeIDs,
                    let resolvedHomeID,
                    !includedHomeIDs.contains(resolvedHomeID)
                {
                    continue
                }

                let locationName = location?.name ?? ""
                let homeName = resolvedHomeID.flatMap { homesByID[$0]?.name } ?? ""

                let labelNames: [String] = (itemLabelsByItemID[item.id] ?? [])
                    .compactMap { labelsByID[$0.inventoryLabelID]?.name }
                    .sorted()

                var photoFilenames: [String] = []
                if let photos = itemPhotosByItemID[item.id] {
                    for photo in photos {
                        let ext = self.photoFileExtension(for: photo.data)
                        let filename =
                            "item-\(item.id.uuidString.lowercased())-\(photo.id.uuidString.lowercased()).\(ext)"
                        photoFilenames.append(filename)
                        if includePhotos {
                            allPhotoFiles.append(.init(filename: filename, data: photo.data))
                        }
                    }
                }

                allItemData.append(
                    ItemData(
                        id: item.id,
                        title: item.title,
                        quantityString: item.quantityString,
                        quantityInt: item.quantityInt,
                        desc: item.desc,
                        serial: item.serial,
                        model: item.model,
                        make: item.make,
                        price: item.price,
                        insured: item.insured,
                        assetId: item.assetId,
                        notes: item.notes,
                        replacementCost: item.replacementCost,
                        depreciationRate: item.depreciationRate,
                        hasUsedAI: item.hasUsedAI,
                        createdAt: item.createdAt,
                        purchaseDate: item.purchaseDate,
                        warrantyExpirationDate: item.warrantyExpirationDate,
                        purchaseLocation: item.purchaseLocation,
                        condition: item.condition,
                        hasWarranty: item.hasWarranty,
                        attachmentsJSON: Self.encodeAttachmentsAsJSONString(item.attachments),
                        dimensionLength: item.dimensionLength,
                        dimensionWidth: item.dimensionWidth,
                        dimensionHeight: item.dimensionHeight,
                        dimensionUnit: item.dimensionUnit,
                        weightValue: item.weightValue,
                        weightUnit: item.weightUnit,
                        color: item.color,
                        storageRequirements: item.storageRequirements,
                        isFragile: item.isFragile,
                        movingPriority: item.movingPriority,
                        roomDestination: item.roomDestination,
                        locationID: item.locationID,
                        locationName: locationName,
                        homeID: resolvedHomeID,
                        homeName: homeName,
                        labelNames: labelNames,
                        photoFilenames: photoFilenames
                    ))
            }

            return (allItemData, allPhotoFiles)
        }
    }

    /// Fetches all location data for export.
    ///
    /// - Parameter database: DatabaseReader to read from
    /// - Returns: Tuple of (location data array, photo blobs to embed in ZIP)
    /// - Throws: DataError if fetch fails
    private func fetchLocationsForExport(
        database: any DatabaseReader,
        includedHomeIDs: Set<UUID>?,
        includePhotos: Bool
    ) async throws -> (locations: [LocationData], photos: [ExportPhotoFile]) {
        try await database.read { db in
            let locations =
                try SQLiteInventoryLocation
                .order(by: \.name)
                .fetchAll(db)

            let allHomes = try SQLiteHome.fetchAll(db)
            let homesByID = Dictionary(uniqueKeysWithValues: allHomes.map { ($0.id, $0) })

            let allLocationPhotos =
                try SQLiteInventoryLocationPhoto
                .order(by: \.sortOrder)
                .fetchAll(db)
            let primaryLocationPhotoByLocationID = Dictionary(
                grouping: allLocationPhotos,
                by: \.inventoryLocationID
            ).compactMapValues(\.first)

            var allLocationData: [LocationData] = []
            var allPhotoFiles: [ExportPhotoFile] = []

            for location in locations {
                if let includedHomeIDs,
                    let homeID = location.homeID,
                    !includedHomeIDs.contains(homeID)
                {
                    continue
                }

                var photoFilename: String?
                if let primaryPhoto = primaryLocationPhotoByLocationID[location.id] {
                    let ext = self.photoFileExtension(for: primaryPhoto.data)
                    let fileName =
                        "location-\(location.id.uuidString.lowercased())-\(primaryPhoto.id.uuidString.lowercased()).\(ext)"
                    photoFilename = fileName
                    if includePhotos {
                        allPhotoFiles.append(.init(filename: fileName, data: primaryPhoto.data))
                    }
                }

                allLocationData.append(
                    LocationData(
                        id: location.id,
                        name: location.name,
                        desc: location.desc,
                        homeID: location.homeID,
                        homeName: location.homeID.flatMap { homesByID[$0]?.name } ?? "",
                        photoFilename: photoFilename
                    ))
            }

            return (allLocationData, allPhotoFiles)
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
                LabelData(
                    name: label.name,
                    desc: label.desc,
                    color: label.color,
                    emoji: label.emoji
                )
            }
        }
    }

    private func fetchHomesForExport(
        database: any DatabaseReader,
        includedHomeIDs: Set<UUID>?,
        includePhotos: Bool
    ) async throws -> (homes: [HomeData], photos: [ExportPhotoFile]) {
        try await database.read { db in
            let homes = try SQLiteHome.order(by: \.name).fetchAll(db)
            let homePhotos = try SQLiteHomePhoto.order(by: \.sortOrder).fetchAll(db)
            let primaryHomePhotoByHomeID = Dictionary(
                grouping: homePhotos,
                by: \.homeID
            ).compactMapValues(\.first)

            var exportHomes: [HomeData] = []
            var exportPhotos: [ExportPhotoFile] = []

            for home in homes {
                if let includedHomeIDs, !includedHomeIDs.contains(home.id) {
                    continue
                }

                var photoFilename: String?
                if let photo = primaryHomePhotoByHomeID[home.id] {
                    let ext = self.photoFileExtension(for: photo.data)
                    let filename =
                        "home-\(home.id.uuidString.lowercased())-\(photo.id.uuidString.lowercased()).\(ext)"
                    photoFilename = filename
                    if includePhotos {
                        exportPhotos.append(.init(filename: filename, data: photo.data))
                    }
                }

                exportHomes.append(
                    HomeData(
                        id: home.id,
                        name: home.name,
                        address1: home.address1,
                        address2: home.address2,
                        city: home.city,
                        state: home.state,
                        zip: home.zip,
                        country: home.country,
                        purchaseDate: home.purchaseDate,
                        purchasePrice: home.purchasePrice,
                        isPrimary: home.isPrimary,
                        colorName: home.colorName,
                        photoFilename: photoFilename
                    ))
            }

            return (exportHomes, exportPhotos)
        }
    }

    private func fetchInsurancePoliciesForExport(
        database: any DatabaseReader,
        includedHomeIDs: Set<UUID>?
    ) async throws -> [InsurancePolicyData] {
        try await database.read { db in
            let policies = try SQLiteInsurancePolicy.order(by: \.providerName).fetchAll(db)
            let policyLinks = try SQLiteHomeInsurancePolicy.fetchAll(db)
            let policyLinksByPolicyID = Dictionary(grouping: policyLinks, by: \.insurancePolicyID)
            let homes = try SQLiteHome.fetchAll(db)
            let homesByID = Dictionary(uniqueKeysWithValues: homes.map { ($0.id, $0) })

            return policies.compactMap { policy in
                let homeIDs = (policyLinksByPolicyID[policy.id] ?? []).map(\.homeID)
                let includePolicy: Bool
                if let includedHomeIDs {
                    if homeIDs.isEmpty {
                        includePolicy = true
                    } else {
                        includePolicy = homeIDs.contains { includedHomeIDs.contains($0) }
                    }
                } else {
                    includePolicy = true
                }

                guard includePolicy else { return nil }

                let homeNames = homeIDs.compactMap { homesByID[$0]?.displayName }.sorted()
                return InsurancePolicyData(
                    id: policy.id,
                    providerName: policy.providerName,
                    policyNumber: policy.policyNumber,
                    deductibleAmount: policy.deductibleAmount,
                    dwellingCoverageAmount: policy.dwellingCoverageAmount,
                    personalPropertyCoverageAmount: policy.personalPropertyCoverageAmount,
                    lossOfUseCoverageAmount: policy.lossOfUseCoverageAmount,
                    liabilityCoverageAmount: policy.liabilityCoverageAmount,
                    medicalPaymentsCoverageAmount: policy.medicalPaymentsCoverageAmount,
                    startDate: policy.startDate,
                    endDate: policy.endDate,
                    homeIDs: homeIDs,
                    homeNames: homeNames
                )
            }
        }
    }

    private func fetchSQLiteFilesForExport(
        database: any DatabaseReader
    ) async throws -> [URL] {
        try await database.read { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA database_list")

            guard
                let mainRow = rows.first(where: { row in
                    let name: String = row["name"]
                    return name == "main"
                })
            else {
                throw DataError.containerNotConfigured
            }

            let mainDatabasePath: String? = mainRow["file"]
            guard
                let mainDatabasePath,
                !mainDatabasePath.isEmpty,
                mainDatabasePath != ":memory:",
                FileManager.default.fileExists(atPath: mainDatabasePath)
            else {
                throw DataError.containerNotConfigured
            }

            var fileURLs: [URL] = [URL(fileURLWithPath: mainDatabasePath)]
            for suffix in ["-wal", "-shm"] {
                let sidecarPath = mainDatabasePath + suffix
                if FileManager.default.fileExists(atPath: sidecarPath) {
                    fileURLs.append(URL(fileURLWithPath: sidecarPath))
                }
            }
            return fileURLs
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

    // MARK: - Photo Export Helpers

    private nonisolated func writePhotosToDirectoryWithProgress(
        photos: [ExportPhotoFile],
        destinationDir: URL,
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws {
        let maxConcurrentWrites = 5
        var failedWrites: [(filename: String, error: Error)] = []
        var activeTasks = 0
        var completedCount = 0
        let totalCount = photos.count

        try await withThrowingTaskGroup(of: (String, Error?).self) { group in
            var pendingPhotos = photos[...]

            while !pendingPhotos.isEmpty || activeTasks > 0 {
                while activeTasks < maxConcurrentWrites, let photo = pendingPhotos.popFirst() {
                    activeTasks += 1
                    group.addTask {
                        do {
                            let fileName = self.sanitizeFilename(photo.filename)
                            let dest = destinationDir.appendingPathComponent(fileName)
                            try? FileManager.default.removeItem(at: dest)
                            try photo.data.write(to: dest, options: .atomic)
                            return (fileName, nil)
                        } catch {
                            return (photo.filename, error)
                        }
                    }
                }

                if let result = try await group.next() {
                    activeTasks -= 1
                    completedCount += 1

                    if let error = result.1 {
                        failedWrites.append((filename: result.0, error: error))
                    }

                    // Report progress based on total photo count for optimal UX
                    let threshold = ProgressMapper.photoProgressThreshold(for: totalCount)
                    if completedCount % threshold == 0 || completedCount == totalCount {
                        progressHandler(completedCount, totalCount)
                    }
                }
            }
        }

        if !failedWrites.isEmpty {
            let failureRate = Double(failedWrites.count) / Double(max(photos.count, 1))
            TelemetryManager.shared.trackPhotoCopyFailures(
                failureCount: failedWrites.count,
                totalPhotos: photos.count,
                failureRate: failureRate
            )

            print("Photo export completed with \(failedWrites.count) write failures:")
            for failure in failedWrites.prefix(3) {
                print("   - \(failure.filename): \(failure.error.localizedDescription)")
            }
            print("   Export will continue without missing photos.")
        }
    }

    private nonisolated func writePhotosToDirectory(
        photos: [ExportPhotoFile],
        destinationDir: URL
    ) async throws {
        try await writePhotosToDirectoryWithProgress(
            photos: photos,
            destinationDir: destinationDir,
            progressHandler: { _, _ in }
        )
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

    private nonisolated func photoFileExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))
        guard !bytes.isEmpty else { return "jpg" }

        // JPEG magic number.
        if bytes.count >= 3, bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return "jpg"
        }

        // PNG magic number.
        if bytes.count >= 8,
            bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47,
            bytes[4] == 0x0D, bytes[5] == 0x0A, bytes[6] == 0x1A, bytes[7] == 0x0A
        {
            return "png"
        }

        // HEIF/HEIC signature lives in ISO BMFF ftyp box.
        if bytes.count >= 12 {
            let brandData = Data(bytes[8..<12])
            if let brand = String(data: brandData, encoding: .ascii),
                ["heic", "heix", "hevc", "heif", "mif1"].contains(brand)
            {
                return "heic"
            }
        }

        return "jpg"
    }

    // MARK: - Image Import Helpers
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

    // MARK: - CSV Writing Helpers
    private func writeCSV(items: [ItemData], to url: URL) async throws {
        let maxPhotoCount = max(1, items.map { $0.photoFilenames.count }.max() ?? 0)
        let photoHeaders = (0..<maxPhotoCount).map { index in
            index == 0 ? "PhotoFilename" : "PhotoFilename\(index + 1)"
        }

        let csvLines: [String] = {
            var lines: [String] = []
            let header =
                [
                    "Title",
                    "Description",
                    "Location",
                    "Label",
                    "Home",
                    "QuantityString",
                    "QuantityInt",
                    "Serial",
                    "Model",
                    "Make",
                    "Price",
                    "Insured",
                    "AssetID",
                    "Notes",
                    "ReplacementCost",
                    "DepreciationRate",
                    "HasUsedAI",
                    "CreatedAt",
                    "PurchaseDate",
                    "WarrantyExpirationDate",
                    "PurchaseLocation",
                    "Condition",
                    "HasWarranty",
                    "AttachmentsJSON",
                    "DimensionLength",
                    "DimensionWidth",
                    "DimensionHeight",
                    "DimensionUnit",
                    "WeightValue",
                    "WeightUnit",
                    "Color",
                    "StorageRequirements",
                    "IsFragile",
                    "MovingPriority",
                    "RoomDestination",
                    "ItemID",
                    "LocationID",
                    "HomeID",
                ] + photoHeaders
            lines.append(header.joined(separator: ","))

            for item in items {
                var row: [String] = [
                    item.title,
                    item.desc,
                    item.locationName,
                    item.labelNames.joined(separator: ","),
                    item.homeName,
                    item.quantityString,
                    String(item.quantityInt),
                    item.serial,
                    item.model,
                    item.make,
                    item.price.description,
                    item.insured ? "true" : "false",
                    item.assetId,
                    item.notes,
                    item.replacementCost?.description ?? "",
                    item.depreciationRate.map { String($0) } ?? "",
                    item.hasUsedAI ? "true" : "false",
                    Self.csvDateString(item.createdAt),
                    Self.csvDateString(item.purchaseDate),
                    Self.csvDateString(item.warrantyExpirationDate),
                    item.purchaseLocation,
                    item.condition,
                    item.hasWarranty ? "true" : "false",
                    item.attachmentsJSON,
                    item.dimensionLength,
                    item.dimensionWidth,
                    item.dimensionHeight,
                    item.dimensionUnit,
                    item.weightValue,
                    item.weightUnit,
                    item.color,
                    item.storageRequirements,
                    item.isFragile ? "true" : "false",
                    String(item.movingPriority),
                    item.roomDestination,
                    item.id.uuidString,
                    item.locationID?.uuidString ?? "",
                    item.homeID?.uuidString ?? "",
                ]

                row.append(
                    contentsOf: (0..<maxPhotoCount).map { photoIndex in
                        guard photoIndex < item.photoFilenames.count else { return "" }
                        return item.photoFilenames[photoIndex]
                    })

                lines.append(row.map(Self.escapeForCSV).joined(separator: ","))
            }
            return lines
        }()

        let csvString = csvLines.joined(separator: "\n")
        try csvString.data(using: .utf8)?.write(to: url)
    }

    private static func csvDateString(_ date: Date?) -> String {
        guard let date else { return "" }
        return csvISO8601DateFormatter.string(from: date)
    }

    private static let csvISO8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let csvISO8601FallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private nonisolated static func encodeAttachmentsAsJSONString(_ attachments: [AttachmentInfo]) -> String {
        guard !attachments.isEmpty else { return "[]" }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(attachments) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
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

        var index = row.startIndex
        while index < row.endIndex {
            let character = row[index]
            if character == "\"" {
                let nextIndex = row.index(after: index)
                if insideQuotes, nextIndex < row.endIndex, row[nextIndex] == "\"" {
                    currentValue.append("\"")
                    index = row.index(after: nextIndex)
                    continue
                }
                insideQuotes.toggle()
            } else if character == "," && !insideQuotes {
                values.append(currentValue)
                currentValue = ""
            } else {
                currentValue.append(character)
            }
            index = row.index(after: index)
        }

        values.append(currentValue)

        return values.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func writeLocationsCSV(locations: [LocationData], to url: URL) async throws {
        let csvLines: [String] = {
            var lines: [String] = []
            let header = ["Name", "Description", "PhotoFilename", "Home", "HomeID", "LocationID"]
            lines.append(header.joined(separator: ","))

            for location in locations {
                let row: [String] = [
                    location.name,
                    location.desc,
                    location.photoFilename ?? "",
                    location.homeName,
                    location.homeID?.uuidString ?? "",
                    location.id.uuidString,
                ]
                lines.append(row.map(Self.escapeForCSV).joined(separator: ","))
            }
            return lines
        }()

        let csvString = csvLines.joined(separator: "\n")
        try csvString.data(using: .utf8)?.write(to: url)
    }

    private func writeHomesCSV(homes: [HomeData], to url: URL) async throws {
        let csvLines: [String] = {
            var lines: [String] = []
            let header = [
                "HomeID",
                "Name",
                "Address1",
                "Address2",
                "City",
                "State",
                "Zip",
                "Country",
                "PurchaseDate",
                "PurchasePrice",
                "IsPrimary",
                "ColorName",
                "PhotoFilename",
            ]
            lines.append(header.joined(separator: ","))

            for home in homes {
                let row: [String] = [
                    home.id.uuidString,
                    home.name,
                    home.address1,
                    home.address2,
                    home.city,
                    home.state,
                    home.zip,
                    home.country,
                    Self.csvDateString(home.purchaseDate),
                    home.purchasePrice.description,
                    home.isPrimary ? "true" : "false",
                    home.colorName,
                    home.photoFilename ?? "",
                ]
                lines.append(row.map(Self.escapeForCSV).joined(separator: ","))
            }
            return lines
        }()

        let csvString = csvLines.joined(separator: "\n")
        try csvString.data(using: .utf8)?.write(to: url)
    }

    private func writeInsurancePoliciesCSV(
        policies: [InsurancePolicyData],
        to url: URL
    ) async throws {
        let csvLines: [String] = {
            var lines: [String] = []
            let header = [
                "PolicyID",
                "ProviderName",
                "PolicyNumber",
                "DeductibleAmount",
                "DwellingCoverageAmount",
                "PersonalPropertyCoverageAmount",
                "LossOfUseCoverageAmount",
                "LiabilityCoverageAmount",
                "MedicalPaymentsCoverageAmount",
                "StartDate",
                "EndDate",
                "Homes",
                "HomeIDs",
            ]
            lines.append(header.joined(separator: ","))

            for policy in policies {
                let row: [String] = [
                    policy.id.uuidString,
                    policy.providerName,
                    policy.policyNumber,
                    policy.deductibleAmount.description,
                    policy.dwellingCoverageAmount.description,
                    policy.personalPropertyCoverageAmount.description,
                    policy.lossOfUseCoverageAmount.description,
                    policy.liabilityCoverageAmount.description,
                    policy.medicalPaymentsCoverageAmount.description,
                    Self.csvDateString(policy.startDate),
                    Self.csvDateString(policy.endDate),
                    policy.homeNames.joined(separator: ","),
                    policy.homeIDs.map(\.uuidString).joined(separator: ","),
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
        let locationResult = try await fetchLocationsForExport(
            database: database,
            includedHomeIDs: nil,
            includePhotos: true
        )
        let labelData = try await fetchLabelsForExport(database: database)

        // Extract item data and collect photo blobs
        // SQLiteInventoryItem is a value type — no MainActor needed
        let (itemData, itemPhotos): ([ItemData], [ExportPhotoFile]) = try await database.read { db in
            var itemData: [ItemData] = []
            var photoFiles: [ExportPhotoFile] = []
            let itemIDSet = Set(items.map(\.id))
            let allLocations = try SQLiteInventoryLocation.fetchAll(db)
            let locationsByID = Dictionary(uniqueKeysWithValues: allLocations.map { ($0.id, $0) })

            let allHomes = try SQLiteHome.fetchAll(db)
            let homesByID = Dictionary(uniqueKeysWithValues: allHomes.map { ($0.id, $0) })

            let allItemLabels = try SQLiteInventoryItemLabel.fetchAll(db)
            let itemLabelsByItemID = Dictionary(grouping: allItemLabels, by: \.inventoryItemID)

            let allLabels = try SQLiteInventoryLabel.fetchAll(db)
            let labelsByID = Dictionary(uniqueKeysWithValues: allLabels.map { ($0.id, $0) })

            let allItemPhotos =
                try SQLiteInventoryItemPhoto
                .order(by: \.sortOrder)
                .fetchAll(db)
                .filter { itemIDSet.contains($0.inventoryItemID) }
            let itemPhotosByItemID = Dictionary(
                grouping: allItemPhotos,
                by: \.inventoryItemID
            )

            for item in items {
                let location = item.locationID.flatMap { locationsByID[$0] }
                let resolvedHomeID = item.homeID ?? location?.homeID
                let locationName = location?.name ?? ""
                let homeName = resolvedHomeID.flatMap { homesByID[$0]?.name } ?? ""

                let labelNames: [String] = (itemLabelsByItemID[item.id] ?? [])
                    .compactMap { labelsByID[$0.inventoryLabelID]?.name }
                    .sorted()

                var photoFilenames: [String] = []
                if let photos = itemPhotosByItemID[item.id] {
                    for photo in photos {
                        let ext = self.photoFileExtension(for: photo.data)
                        let filename =
                            "item-\(item.id.uuidString.lowercased())-\(photo.id.uuidString.lowercased()).\(ext)"
                        photoFilenames.append(filename)
                        photoFiles.append(.init(filename: filename, data: photo.data))
                    }
                }

                itemData.append(
                    ItemData(
                        id: item.id,
                        title: item.title,
                        quantityString: item.quantityString,
                        quantityInt: item.quantityInt,
                        desc: item.desc,
                        serial: item.serial,
                        model: item.model,
                        make: item.make,
                        price: item.price,
                        insured: item.insured,
                        assetId: item.assetId,
                        notes: item.notes,
                        replacementCost: item.replacementCost,
                        depreciationRate: item.depreciationRate,
                        hasUsedAI: item.hasUsedAI,
                        createdAt: item.createdAt,
                        purchaseDate: item.purchaseDate,
                        warrantyExpirationDate: item.warrantyExpirationDate,
                        purchaseLocation: item.purchaseLocation,
                        condition: item.condition,
                        hasWarranty: item.hasWarranty,
                        attachmentsJSON: Self.encodeAttachmentsAsJSONString(item.attachments),
                        dimensionLength: item.dimensionLength,
                        dimensionWidth: item.dimensionWidth,
                        dimensionHeight: item.dimensionHeight,
                        dimensionUnit: item.dimensionUnit,
                        weightValue: item.weightValue,
                        weightUnit: item.weightUnit,
                        color: item.color,
                        storageRequirements: item.storageRequirements,
                        isFragile: item.isFragile,
                        movingPriority: item.movingPriority,
                        roomDestination: item.roomDestination,
                        locationID: item.locationID,
                        locationName: locationName,
                        homeID: resolvedHomeID,
                        homeName: homeName,
                        labelNames: labelNames,
                        photoFilenames: photoFilenames
                    ))
            }

            return (itemData, photoFiles)
        }

        let locationData = locationResult.locations
        var allPhotoFiles = itemPhotos
        allPhotoFiles.append(contentsOf: locationResult.photos)

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

        // Write photos from BLOB payloads into the ZIP staging directory.
        let uniquePhotoFiles = Array(Set(allPhotoFiles))
        try await writePhotosToDirectory(photos: uniquePhotoFiles, destinationDir: photosDir)

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
