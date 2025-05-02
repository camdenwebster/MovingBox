//
//  ExportManager.swift
//  MovingBox
//
//  Created by Alex (AI) on 6/10/25.
//

import Foundation
import ZIPFoundation
import SwiftData
import SwiftUI

actor ExportManager {
    static let shared = ExportManager()
    private init() {}

    enum ExportError: Error {
        case nothingToExport
        case failedCreateZip
    }

    /// Exports all `InventoryItem`s (and their photos) into a single **zip** file that also
    /// contains `inventory.csv`.  The returned `URL` points to the finished archive
    /// inside the temporary directory – caller is expected to share / move / delete.
    @MainActor
    func exportInventory(modelContext: ModelContext) async throws -> URL {
        // Fetch data on MainActor
        let items = try modelContext.fetch(FetchDescriptor<InventoryItem>())
        guard !items.isEmpty else { throw ExportError.nothingToExport }
        
        let home = try? modelContext.fetch(FetchDescriptor<Home>()).first
        
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
        
        let homeName = home?.name ?? "Home"
        let dateString = DateFormatter.exportDateFormatter.string(from: .init())
        let suggestedName = "\(homeName)-export-\(dateString).zip"

        // Working directory in tmp
        let workingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        let photosDir = workingRoot.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photosDir,
                                             withIntermediateDirectories: true)

        // 1. Write CSV
        let csvURL = workingRoot.appendingPathComponent("inventory.csv")
        try await writeCSV(items: itemData, to: csvURL)

        // 2. Copy photos
        for item in itemData {
            if let src = item.imageURL,
               FileManager.default.fileExists(atPath: src.path) {
                let dest = photosDir.appendingPathComponent(src.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: src, to: dest)
            }
        }

        // 3. Zip
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
        else { throw ExportError.failedCreateZip }

        return archiveURL
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
}

private extension DateFormatter {
    static let exportDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
