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

    /// Exports all `InventoryItem`s (and their photos) into a single **zip** file that also
    /// contains `inventory.csv`.  The returned `URL` points to the finished archive
    /// inside the temporary directory – caller is expected to share / move / delete.
    @MainActor
    func exportInventory(modelContext: ModelContext, fileName: String? = nil, config: ExportConfig = ExportConfig(includeItems: true, includeLocations: true, includeLabels: true)) async throws -> URL {
        var itemData: [(title: String, desc: String, locationName: String, labelName: String, quantity: Int, serial: String, model: String, make: String, price: Decimal, insured: Bool, notes: String, imageURL: URL?, hasUsedAI: Bool)] = []
        var locationData: [(name: String, desc: String, imageURL: URL?)] = []
        var labelData: [(name: String, desc: String, color: UIColor?, emoji: String)] = []
        
        // Only fetch data for enabled types
        if config.includeItems {
            let items = try modelContext.fetch(FetchDescriptor<InventoryItem>())
            guard !items.isEmpty else { throw DataError.nothingToExport }
            
            itemData = items.map { item in
                (
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
            }
        }
        
        if config.includeLocations {
            let locations = try modelContext.fetch(FetchDescriptor<InventoryLocation>())
            locationData = locations.map { location in
                (
                    name: location.name,
                    desc: location.desc,
                    imageURL: location.imageURL
                )
            }
        }
        
        if config.includeLabels {
            let labels = try modelContext.fetch(FetchDescriptor<InventoryLabel>())
            labelData = labels.map { label in
                (
                    name: label.name,
                    desc: label.desc,
                    color: label.color,
                    emoji: label.emoji
                )
            }
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

        // Copy photos only for enabled types
        if config.includeItems {
            for item in itemData {
                if let src = item.imageURL,
                   FileManager.default.fileExists(atPath: src.path) {
                    let dest = photosDir.appendingPathComponent(src.lastPathComponent)
                    try? FileManager.default.removeItem(at: dest)
                    try FileManager.default.copyItem(at: src, to: dest)
                }
            }
        }
        
        if config.includeLocations {
            for location in locationData {
                if let src = location.imageURL,
                   FileManager.default.fileExists(atPath: src.path) {
                    let dest = photosDir.appendingPathComponent(src.lastPathComponent)
                    try? FileManager.default.removeItem(at: dest)
                    try FileManager.default.copyItem(at: src, to: dest)
                }
            }
        }

        // Zip with proper permissions
        let archiveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(archiveName)
        try? FileManager.default.removeItem(at: archiveURL)         // overwrite if exists
        
        // Create archive with proper permissions
        try FileManager.default.zipItem(at: workingRoot,
                                      to: archiveURL,
                                      shouldKeepParent: false,
                                      compressionMethod: .deflate)
        
        // Set proper file permissions (read/write for user)
        try FileManager.default.setAttributes([
            .posixPermissions: 0o644
        ], ofItemAtPath: archiveURL.path)

        // Clean up working directory asynchronously – no await, fire-and-forget
        Task.detached { try? FileManager.default.removeItem(at: workingRoot) }

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
    
    // MARK: - Helpers
    private func writeCSV(items: [(
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
    )], to url: URL) async throws {
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
    
    private func writeLocationsCSV(locations: [(
        name: String,
        desc: String,
        imageURL: URL?
    )], to url: URL) async throws {
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
    
    private func writeLabelsCSV(labels: [(
        name: String,
        desc: String,
        color: UIColor?,
        emoji: String
    )], to url: URL) async throws {
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
        
        // Get all locations and labels (as requested)
        let allLocations = try modelContext.fetch(FetchDescriptor<InventoryLocation>())
        let allLabels = try modelContext.fetch(FetchDescriptor<InventoryLabel>())
        
        let itemData = items.map { item in
            (
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
        }
        
        let locationData = allLocations.map { location in
            (
                name: location.name,
                desc: location.desc,
                imageURL: location.imageURL
            )
        }
        
        let labelData = allLabels.map { label in
            (
                name: label.name,
                desc: label.desc,
                color: label.color,
                emoji: label.emoji
            )
        }

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

        // Copy photos from selected items
        var photoFileNames: Set<String> = []
        for item in itemData {
            if let imageURL = item.imageURL,
               FileManager.default.fileExists(atPath: imageURL.path) {
                let fileName = imageURL.lastPathComponent
                let destURL = photosDir.appendingPathComponent(fileName)
                
                // Avoid duplicate copies
                if !photoFileNames.contains(fileName) {
                    try FileManager.default.copyItem(at: imageURL, to: destURL)
                    photoFileNames.insert(fileName)
                }
            }
        }
        
        // Copy photos from all locations  
        for location in locationData {
            if let imageURL = location.imageURL,
               FileManager.default.fileExists(atPath: imageURL.path) {
                let fileName = imageURL.lastPathComponent
                let destURL = photosDir.appendingPathComponent(fileName)
                
                // Avoid duplicate copies
                if !photoFileNames.contains(fileName) {
                    try FileManager.default.copyItem(at: imageURL, to: destURL)
                    photoFileNames.insert(fileName)
                }
            }
        }

        // Create ZIP archive
        let archiveURL = FileManager.default.temporaryDirectory.appendingPathComponent(archiveName)
        
        // Remove existing file
        try? FileManager.default.removeItem(at: archiveURL)
        
        let archive = try Archive(url: archiveURL, accessMode: .create)

        // Add all files to ZIP
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

        // Clean up working directory
        try? FileManager.default.removeItem(at: workingRoot)
        
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
