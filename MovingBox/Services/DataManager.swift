//
//  DataManager.swift
//  MovingBox
//
//  Created by Alex (AI) on 6/10/25.
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
    }

    static let shared = DataManager()
    private init() {}

    /// Exports all `InventoryItem`s (and their photos) into a single **zip** file that also
    /// contains `inventory.csv`.  The returned `URL` points to the finished archive
    /// inside the temporary directory – caller is expected to share / move / delete.
    @MainActor
    func exportInventory(modelContext: ModelContext) async throws -> URL {
        // Fetch both inventory and location data
        let items = try modelContext.fetch(FetchDescriptor<InventoryItem>())
        let locations = try modelContext.fetch(FetchDescriptor<InventoryLocation>())
        guard !items.isEmpty else { throw DataError.nothingToExport }
                
        // Capture all required data
        let itemData: [(
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
        )] = items.map { item in
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
        
        // Capture location data
        let locationData: [(
            name: String,
            desc: String,
            imageURL: URL?
        )] = locations.map { location in
            (
                name: location.name,
                desc: location.desc,
                imageURL: location.imageURL
            )
        }
        
        let dateString = DateFormatter.exportDateFormatter.string(from: .init())
        let suggestedName = "MovingBox-export-\(dateString).zip"

        // Working directory in tmp
        let workingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        let photosDir = workingRoot.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photosDir,
                                             withIntermediateDirectories: true)

        // Write both CSV files
        let itemsCSVURL = workingRoot.appendingPathComponent("inventory.csv")
        try await writeCSV(items: itemData, to: itemsCSVURL)
        
        let locationsCSVURL = workingRoot.appendingPathComponent("locations.csv")
        try await writeLocationsCSV(locations: locationData, to: locationsCSVURL)

        // Copy photos from both items and locations
        for item in itemData {
            if let src = item.imageURL,
               FileManager.default.fileExists(atPath: src.path) {
                let dest = photosDir.appendingPathComponent(src.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: src, to: dest)
            }
        }
        
        for location in locationData {
            if let src = location.imageURL,
               FileManager.default.fileExists(atPath: src.path) {
                let dest = photosDir.appendingPathComponent(src.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: src, to: dest)
            }
        }

        // Zip
        let archiveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(suggestedName)
        try? FileManager.default.removeItem(at: archiveURL)         // overwrite if exists
        try FileManager.default.zipItem(at: workingRoot,
                                      to: archiveURL,
                                      shouldKeepParent: false,
                                      compressionMethod: .deflate)

        // Clean up working directory asynchronously – no await, fire-and-forget
        Task.detached { try? FileManager.default.removeItem(at: workingRoot) }

        guard FileManager.default.fileExists(atPath: archiveURL.path)
        else { throw DataError.failedCreateZip }

        return archiveURL
    }

    enum ImportProgress {
        case progress(Double)
        case completed(ImportResult)
        case error(Error)
    }

    struct ImportResult {
        let itemCount: Int
        let locationCount: Int
    }

    /// Exports inventory from a zip file and reports progress through an async sequence
    func importInventory(
        from zipURL: URL,
        modelContext: ModelContext
    ) -> AsyncStream<ImportProgress> {
        AsyncStream { continuation in
            Task { @MainActor in
                do {
                    print("📦 Starting import from: \(zipURL.lastPathComponent)")
                    
                    // Create working directory
                    let workingDir = FileManager.default.temporaryDirectory
                        .appendingPathComponent("import-\(UUID().uuidString)", isDirectory: true)
                    
                    defer {
                        try? FileManager.default.removeItem(at: workingDir)
                    }
                    
                    // Create local copy and unzip
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
                    
                    try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
                    try FileManager.default.unzipItem(at: localZipURL, to: workingDir)
                    
                    // Get CSV files
                    let itemsCSVURL = workingDir.appendingPathComponent("inventory.csv")
                    let locationsCSVURL = workingDir.appendingPathComponent("locations.csv")
                    let photosDir = workingDir.appendingPathComponent("photos")
                    
                    // Calculate total rows
                    var totalRows = 0
                    var processedRows = 0
                    
                    if FileManager.default.fileExists(atPath: locationsCSVURL.path) {
                        let locationCSV = try String(contentsOf: locationsCSVURL, encoding: .utf8)
                        let locationCount = locationCSV.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                            .count - 1
                        totalRows += locationCount
                        print("📦 Found \(locationCount) locations to import")
                    }
                    
                    if FileManager.default.fileExists(atPath: itemsCSVURL.path) {
                        let itemsCSV = try String(contentsOf: itemsCSVURL, encoding: .utf8)
                        let itemCount = itemsCSV.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                            .count - 1
                        totalRows += itemCount
                        print("📦 Found \(itemCount) items to import")
                    }
                    
                    guard totalRows > 0 else {
                        print("❌ No data found to import")
                        continuation.yield(.error(DataError.invalidCSVFormat))
                        continuation.finish()
                        throw DataError.invalidCSVFormat
                    }
                    
                    print("📦 Starting location import...")
                    // Import locations first
                    var locationCount = 0
                    if FileManager.default.fileExists(atPath: locationsCSVURL.path) {
                        let csvString = try String(contentsOf: locationsCSVURL, encoding: .utf8)
                        let rows = csvString.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                        
                        if rows.count > 1 {
                            for row in rows.dropFirst() {
                                let values = await parseCSVRow(row)
                                guard values.count >= 3 else { continue }
                                
                                print("📍 Importing location: \(values[0])")
                                let location = createAndConfigureLocation(
                                    name: values[0],
                                    desc: values[1]
                                )
                                
                                // Handle photo if exists
                                if !values[2].isEmpty {
                                    let photoURL = photosDir.appendingPathComponent(values[2])
                                    if FileManager.default.fileExists(atPath: photoURL.path) {
                                        print("🏞️ Found photo for location: \(values[0])")
                                        let destURL = try FileManager.default.url(
                                            for: .documentDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true
                                        ).appendingPathComponent(values[2])
                                        
                                        try? FileManager.default.removeItem(at: destURL)
                                        try FileManager.default.copyItem(at: photoURL, to: destURL)
                                        location.imageURL = destURL
                                    }
                                }
                                
                                modelContext.insert(location)
                                locationCount += 1
                                processedRows += 1
                                let progress = Double(processedRows) / Double(totalRows)
                                print("📊 Import progress: \(Int(progress * 100))% (\(processedRows)/\(totalRows))")
                                continuation.yield(.progress(progress))
                            }
                        }
                    }
                    
                    print("📦 Starting item import...")
                    // Import inventory items
                    var itemCount = 0
                    if FileManager.default.fileExists(atPath: itemsCSVURL.path) {
                        let csvString = try String(contentsOf: itemsCSVURL, encoding: .utf8)
                        let rows = csvString.components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                        
                        if rows.count > 1 {
                            for row in rows.dropFirst() {
                                let values = await parseCSVRow(row)
                                guard values.count >= 13 else { continue }
                                
                                print("📝 Importing item: \(values[0])")
                                let item = createAndConfigureItem(
                                    title: values[0],
                                    desc: values[1]
                                )
                                
                                // Get or create location
                                print("🔍 Finding location for item: \(values[2])")
                                let location = findOrCreateLocation(
                                    name: values[2],
                                    modelContext: modelContext
                                )
                                item.location = location
                                
                                // Handle photo if exists
                                let photoFilename = values[11]
                                if !photoFilename.isEmpty {
                                    let photoURL = photosDir.appendingPathComponent(photoFilename)
                                    if FileManager.default.fileExists(atPath: photoURL.path) {
                                        print("🏞️ Found photo for item: \(values[0])")
                                        let destURL = try FileManager.default.url(
                                            for: .documentDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true
                                        ).appendingPathComponent(photoFilename)
                                        
                                        try? FileManager.default.removeItem(at: destURL)
                                        try FileManager.default.copyItem(at: photoURL, to: destURL)
                                        item.imageURL = destURL
                                    }
                                }
                                
                                modelContext.insert(item)
                                itemCount += 1
                                processedRows += 1
                                let progress = Double(processedRows) / Double(totalRows)
                                print("📊 Import progress: \(Int(progress * 100))% (\(processedRows)/\(totalRows))")
                                continuation.yield(.progress(progress))
                            }
                        }
                    }
                    
                    print("✅ Import complete! Imported \(itemCount) items and \(locationCount) locations")
                    continuation.yield(.completed(ImportResult(
                        itemCount: itemCount,
                        locationCount: locationCount
                    )))
                    continuation.finish()
                    
                } catch {
                    print("❌ Import failed: \(error.localizedDescription)")
                    continuation.yield(.error(error))
                    continuation.finish()
                    throw error
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
}

private extension DateFormatter {
    static let exportDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
