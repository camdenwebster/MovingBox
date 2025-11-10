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

actor DataManager {
    enum DataError: Error {
        case nothingToExport
        case failedCreateZip
        case invalidZipFile
        case invalidCSVFormat
        case photoNotFound
        case fileAccessDenied
        case fileTooLarge
        case invalidFileType
    }

    static let shared = DataManager()
    private init() {}

    /// Exports inventory with progress reporting via AsyncStream
    nonisolated func exportInventoryWithProgress(
        modelContext: ModelContext,
        fileName: String? = nil,
        config: ExportConfig = ExportConfig(includeItems: true, includeLocations: true, includeLabels: true)
    ) -> AsyncStream<ExportProgress> {
        AsyncStream { continuation in
            Task { @MainActor in
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
                    
                    // Create archive
                    continuation.yield(.creatingArchive(progress: Double(completedSteps) / Double(totalSteps)))
                    
                    let archiveURL = try await Task.detached {
                        let archiveURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(archiveName)
                        try? FileManager.default.removeItem(at: archiveURL)
                        
                        try FileManager.default.zipItem(at: workingRoot,
                                                      to: archiveURL,
                                                      shouldKeepParent: false,
                                                      compressionMethod: .deflate)
                        
                        try FileManager.default.setAttributes([
                            .posixPermissions: 0o644
                        ], ofItemAtPath: archiveURL.path)
                        
                        return archiveURL
                    }.value
                    
                    completedSteps += 1
                    continuation.yield(.creatingArchive(progress: 1.0))
                    
                    // Clean up
                    Task.detached {
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
                    continuation.yield(.error(error))
                    continuation.finish()
                }
            }
        }
    }
    
    /// Exports all `InventoryItem`s (and their photos) into a single **zip** file that also
    /// contains `inventory.csv`.  The returned `URL` points to the finished archive
    /// inside the temporary directory – caller is expected to share / move / delete.
    /// For progress reporting, use `exportInventoryWithProgress` instead.
    @MainActor
    func exportInventory(modelContext: ModelContext, fileName: String? = nil, config: ExportConfig = ExportConfig(includeItems: true, includeLocations: true, includeLabels: true)) async throws -> URL {
        var itemData: [ItemData] = []
        var locationData: [LocationData] = []
        var labelData: [LabelData] = []
        var allPhotoURLs: [URL] = []
        
        // Fetch data in batches to reduce memory pressure
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

        // Zip with proper permissions - run on background
        let archiveURL = try await Task.detached {
            let archiveURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(archiveName)
            try? FileManager.default.removeItem(at: archiveURL)
            
            try FileManager.default.zipItem(at: workingRoot,
                                          to: archiveURL,
                                          shouldKeepParent: false,
                                          compressionMethod: .deflate)
            
            try FileManager.default.setAttributes([
                .posixPermissions: 0o644
            ], ofItemAtPath: archiveURL.path)
            
            return archiveURL
        }.value

        // Clean up working directory with proper error handling
        Task.detached {
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

    enum ImportProgress {
        case progress(Double)
        case completed(ImportResult)
        case error(Error)
    }

    struct ImportResult {
        let itemCount: Int
        let locationCount: Int
        let labelCount: Int
    }
    
    enum ExportProgress {
        case preparing
        case fetchingData(phase: String, progress: Double)
        case writingCSV(progress: Double)
        case copyingPhotos(current: Int, total: Int)
        case creatingArchive(progress: Double)
        case completed(ExportResult)
        case error(Error)
    }
    
    struct ExportResult {
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

    /// Exports inventory from a zip file and reports progress through an async sequence
    func importInventory(
        from zipURL: URL,
        modelContext: ModelContext,
        config: ImportConfig = ImportConfig(includeItems: true, includeLocations: true, includeLabels: true)
    ) -> AsyncStream<ImportProgress> {
        AsyncStream { continuation in
            Task { @MainActor in
                do {
                    print("📦 Starting import from: \(zipURL.lastPathComponent)")
                    
                    // Create working directory with proper permissions
                    let workingDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("import-\(UUID().uuidString)", isDirectory: true)
                    
                    defer {
                        try? FileManager.default.removeItem(at: workingDir)
                    }
                    
                    // Create local copy and unzip with proper permissions
                    print("📦 Creating local copy and unzipping...")
                    let localZipURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(zipURL.lastPathComponent)
                    try? FileManager.default.removeItem(at: localZipURL)
                    
                    // Check if we can access the file
                    guard FileManager.default.isReadableFile(atPath: zipURL.path) else {
                        print("❌ File access denied: \(zipURL.path)")
                        continuation.yield(.error(DataError.fileAccessDenied))
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
                        continuation.yield(.error(DataError.invalidCSVFormat))
                        continuation.finish()
                        throw DataError.invalidCSVFormat
                    }
                    
                    var locationCount = 0
                    var labelCount = 0
                    var itemCount = 0
                    
                    // Import locations if enabled
                    if config.includeLocations, FileManager.default.fileExists(atPath: locationsCSVURL.path) {
                        let csvString = try String(contentsOf: locationsCSVURL, encoding: .utf8)
                        let rows = csvString.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                        
                        if rows.count > 1 {
                            for row in rows.dropFirst() {
                                // Yield control to prevent UI freezing
                                await Task.yield()
                                
                                let values = await parseCSVRow(row)
                                guard values.count >= 3 else { continue }
                                
                                let location = createAndConfigureLocation(
                                    name: values[0],
                                    desc: values[1]
                                )
                                
                                if !values[2].isEmpty {
                                    let sanitizedFilename = sanitizeFilename(values[2])
                                    let photoURL = photosDir.appendingPathComponent(sanitizedFilename)
                                    if FileManager.default.fileExists(atPath: photoURL.path) {
                                        do {
                                            location.imageURL = try copyImageToDocuments(photoURL, filename: values[2])
                                        } catch {
                                            print("⚠️ Failed to copy location image: \(error)")
                                        }
                                    }
                                }
                                
                                modelContext.insert(location)
                                locationCount += 1
                                processedRows += 1
                                let progress = Double(processedRows) / Double(totalRows)
                                continuation.yield(.progress(progress))
                            }
                        }
                    }
                    
                    // Import labels if enabled
                    if config.includeLabels, FileManager.default.fileExists(atPath: labelsCSVURL.path) {
                        let csvString = try String(contentsOf: labelsCSVURL, encoding: .utf8)
                        let rows = csvString.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                        
                        if rows.count > 1 {
                            for row in rows.dropFirst() {
                                // Yield control to prevent UI freezing
                                await Task.yield()
                                
                                let values = await parseCSVRow(row)
                                guard values.count >= 4 else { continue }
                                
                                let label = createAndConfigureLabel(
                                    name: values[0],
                                    desc: values[1],
                                    colorHex: values[2],
                                    emoji: values[3]
                                )
                                
                                modelContext.insert(label)
                                labelCount += 1
                                processedRows += 1
                                let progress = Double(processedRows) / Double(totalRows)
                                continuation.yield(.progress(progress))
                            }
                        }
                    }
                    
                    // Import items if enabled
                    if config.includeItems, FileManager.default.fileExists(atPath: itemsCSVURL.path) {
                        let csvString = try String(contentsOf: itemsCSVURL, encoding: .utf8)
                        let rows = csvString.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                        
                        if rows.count > 1 {
                            for row in rows.dropFirst() {
                                // Yield control to prevent UI freezing
                                await Task.yield()
                                
                                let values = await parseCSVRow(row)
                                guard values.count >= 13 else { continue }
                                
                                let item = createAndConfigureItem(
                                    title: values[0],
                                    desc: values[1]
                                )
                                
                                if config.includeLocations {
                                    let location = findOrCreateLocation(
                                        name: values[2],
                                        modelContext: modelContext
                                    )
                                    item.location = location
                                }
                                
                                if config.includeLabels {
                                    let label = findOrCreateLabel(
                                        name: values[3],
                                        modelContext: modelContext
                                    )
                                    item.label = label
                                }
                                
                                let photoFilename = values[11]
                                if !photoFilename.isEmpty {
                                    let sanitizedFilename = sanitizeFilename(photoFilename)
                                    let photoURL = photosDir.appendingPathComponent(sanitizedFilename)
                                    if FileManager.default.fileExists(atPath: photoURL.path) {
                                        do {
                                            item.imageURL = try copyImageToDocuments(photoURL, filename: photoFilename)
                                        } catch {
                                            print("⚠️ Failed to copy item image: \(error)")
                                        }
                                    }
                                }
                                
                                modelContext.insert(item)
                                itemCount += 1
                                processedRows += 1
                                let progress = Double(processedRows) / Double(totalRows)
                                continuation.yield(.progress(progress))
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
                    continuation.yield(.error(error))
                    continuation.finish()
                }
            }
        }
    }
    
    @MainActor
    private func createAndConfigureLocation(name: String, desc: String) -> InventoryLocation {
        let location = InventoryLocation(name: name)
        location.desc = desc
        return location
    }
    
    @MainActor
    private func createAndConfigureItem(title: String, desc: String) -> InventoryItem {
        let item = InventoryItem()
        item.title = title
        item.desc = desc
        return item
    }
    
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
    
    @MainActor
    private func fetchItemsInBatches(
        modelContext: ModelContext
    ) async throws -> (items: [ItemData], photoURLs: [URL]) {
        var allItemData: [ItemData] = []
        var allPhotoURLs: [URL] = []
        var offset = 0
        
        while true {
            var descriptor = FetchDescriptor<InventoryItem>(
                sortBy: [SortDescriptor(\.title)]
            )
            descriptor.fetchLimit = Self.batchSize
            descriptor.fetchOffset = offset
            
            let batch = try modelContext.fetch(descriptor)
            
            if batch.isEmpty {
                break
            }
            
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
                allItemData.append(itemData)
                
                if let imageURL = item.imageURL {
                    allPhotoURLs.append(imageURL)
                }
            }
            
            offset += batch.count
            
            if batch.count < Self.batchSize {
                break
            }
        }
        
        return (allItemData, allPhotoURLs)
    }
    
    @MainActor
    private func fetchLocationsInBatches(
        modelContext: ModelContext
    ) async throws -> (locations: [LocationData], photoURLs: [URL]) {
        var allLocationData: [LocationData] = []
        var allPhotoURLs: [URL] = []
        var offset = 0
        
        while true {
            var descriptor = FetchDescriptor<InventoryLocation>(
                sortBy: [SortDescriptor(\.name)]
            )
            descriptor.fetchLimit = Self.batchSize
            descriptor.fetchOffset = offset
            
            let batch = try modelContext.fetch(descriptor)
            
            if batch.isEmpty {
                break
            }
            
            for location in batch {
                let locationData = (
                    name: location.name,
                    desc: location.desc,
                    imageURL: location.imageURL
                )
                allLocationData.append(locationData)
                
                if let imageURL = location.imageURL {
                    allPhotoURLs.append(imageURL)
                }
            }
            
            offset += batch.count
            
            if batch.count < Self.batchSize {
                break
            }
        }
        
        return (allLocationData, allPhotoURLs)
    }
    
    @MainActor
    private func fetchLabelsInBatches(
        modelContext: ModelContext
    ) async throws -> [LabelData] {
        var allLabelData: [LabelData] = []
        var offset = 0
        
        while true {
            var descriptor = FetchDescriptor<InventoryLabel>(
                sortBy: [SortDescriptor(\.name)]
            )
            descriptor.fetchLimit = Self.batchSize
            descriptor.fetchOffset = offset
            
            let batch = try modelContext.fetch(descriptor)
            
            if batch.isEmpty {
                break
            }
            
            for label in batch {
                let labelData = (
                    name: label.name,
                    desc: label.desc,
                    color: label.color,
                    emoji: label.emoji
                )
                allLabelData.append(labelData)
            }
            
            offset += batch.count
            
            if batch.count < Self.batchSize {
                break
            }
        }
        
        return allLabelData
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
                    
                    // Report progress every 5 photos or at the end
                    if completedCount % 5 == 0 || completedCount == totalCount {
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
            
            for failure in failedCopies {
                print("⚠️ Failed to copy photo \(failure.url.lastPathComponent): \(failure.error.localizedDescription)")
            }
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
            
            for failure in failedCopies {
                print("⚠️ Failed to copy photo \(failure.url.lastPathComponent): \(failure.error.localizedDescription)")
            }
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
    @MainActor
    func exportSpecificItems(items: [InventoryItem], modelContext: ModelContext, fileName: String? = nil) async throws -> URL {
        guard !items.isEmpty else { throw DataError.nothingToExport }
        
        // Get all locations and labels using batched fetching for efficiency
        let locationResult = try await fetchLocationsInBatches(modelContext: modelContext)
        let labelData = try await fetchLabelsInBatches(modelContext: modelContext)
        
        // Extract item data and collect photo URLs
        var itemData: [ItemData] = []
        var allPhotoURLs: [URL] = []
        
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
                allPhotoURLs.append(imageURL)
            }
        }
        
        let locationData = locationResult.locations
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

        // Create ZIP archive in background
        let archiveURL = try await Task.detached {
            let archiveURL = FileManager.default.temporaryDirectory.appendingPathComponent(archiveName)
            try? FileManager.default.removeItem(at: archiveURL)
            
            let archive = try Archive(url: archiveURL, accessMode: .create)
            
            let workingRootPath = workingRoot.path
            let enumerator = FileManager.default.enumerator(atPath: workingRootPath)
            
            while let relativePath = enumerator?.nextObject() as? String {
                let fullPath = workingRoot.appendingPathComponent(relativePath)
                var isDir: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: fullPath.path, isDirectory: &isDir),
                   !isDir.boolValue {
                    try archive.addEntry(with: relativePath, relativeTo: workingRoot)
                }
            }
            
            return archiveURL
        }.value

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
