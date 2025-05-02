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
    static let shared = DataManager()
    private init() {}

    enum DataError: Error {
        case nothingToExport
        case failedCreateZip
        case invalidZipFile
        case invalidCSVFormat
        case photoNotFound
        case fileAccessDenied
    }

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

    @MainActor
    func importInventory(from zipURL: URL, modelContext: ModelContext) async throws -> Int {
        // Start security-scoped resource access
        guard zipURL.startAccessingSecurityScopedResource() else {
            throw DataError.fileAccessDenied
        }
        
        defer {
            zipURL.stopAccessingSecurityScopedResource()
        }
        
        let workingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-\(UUID().uuidString)", isDirectory: true)
        
        defer {
            try? FileManager.default.removeItem(at: workingDir)
        }
        
        // Create a local copy of the zip file first
        let localZipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(zipURL.lastPathComponent)
        try? FileManager.default.removeItem(at: localZipURL)
        try FileManager.default.copyItem(at: zipURL, to: localZipURL)
        
        // Unzip archive
        try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: localZipURL, to: workingDir)
        
        // Find and parse both CSV files
        let itemsCSVURL = workingDir.appendingPathComponent("inventory.csv")
        let locationsCSVURL = workingDir.appendingPathComponent("locations.csv")
        let photosDir = workingDir.appendingPathComponent("photos")
        
        // Import locations first
        if FileManager.default.fileExists(atPath: locationsCSVURL.path) {
            let csvString = try String(contentsOf: locationsCSVURL, encoding: .utf8)
            let rows = csvString.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
            
            if rows.count > 1 {
                for row in rows.dropFirst() {
                    let values = await parseCSVRow(row)
                    guard values.count >= 3 else { continue }
                    
                    let location = InventoryLocation(name: values[0])
                    location.desc = values[1]
                    
                    // Handle location photo
                    let photoFilename = values[2]
                    if !photoFilename.isEmpty {
                        let photoURL = photosDir.appendingPathComponent(photoFilename)
                        if FileManager.default.fileExists(atPath: photoURL.path) {
                            let destURL = try FileManager.default.url(
                                for: .documentDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true
                            ).appendingPathComponent(photoFilename)
                            
                            try? FileManager.default.removeItem(at: destURL)
                            try FileManager.default.copyItem(at: photoURL, to: destURL)
                            location.imageURL = destURL
                        }
                    }
                    
                    modelContext.insert(location)
                }
            }
        }
        
        // Import inventory
        guard FileManager.default.fileExists(atPath: itemsCSVURL.path) else {
            throw DataError.invalidCSVFormat
        }
        
        let csvString = try String(contentsOf: itemsCSVURL, encoding: .utf8)
        let rows = csvString.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        guard rows.count > 1 else { throw DataError.invalidCSVFormat }
        
        var importCount = 0
        for row in rows.dropFirst() {
            let values = await parseCSVRow(row)
            guard values.count >= 13 else { continue }
            
            // Get location or create new one
            let locationName = values[2]
            let location: InventoryLocation
            if let existing = try? modelContext.fetch(FetchDescriptor<InventoryLocation>(
                predicate: #Predicate<InventoryLocation> { $0.name == locationName }
            )).first {
                location = existing
            } else {
                location = InventoryLocation(name: locationName)
                modelContext.insert(location)
            }
            
            // Get label or create new one
            let labelName = values[3]
            let label: InventoryLabel?
            if !labelName.isEmpty {
                if let existing = try? modelContext.fetch(FetchDescriptor<InventoryLabel>(
                    predicate: #Predicate<InventoryLabel> { $0.name == labelName }
                )).first {
                    label = existing
                } else {
                    label = InventoryLabel(name: labelName)
                    modelContext.insert(label!)
                }
            } else {
                label = nil
            }
            
            // Create item with title and location - other properties set after initialization
            let item = InventoryItem()
            item.title = values[0]
            item.desc = values[1]
            item.location = location
            item.label = label
            item.quantityInt = Int(values[4]) ?? 1
            item.serial = values[5]
            item.model = values[6]
            item.make = values[7]
            item.price = Decimal(string: values[8]) ?? 0
            item.insured = values[9].lowercased() == "true"
            item.notes = values[10]
            item.hasUsedAI = values[12].lowercased() == "true"
            
            // Handle photo if exists
            let photoFilename = values[11]
            if !photoFilename.isEmpty {
                let photoURL = photosDir.appendingPathComponent(photoFilename)
                if FileManager.default.fileExists(atPath: photoURL.path) {
                    // Copy photo to app container
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
            importCount += 1
        }
        
        return importCount
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
