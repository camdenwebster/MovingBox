//
//  CreateCSVBackupIntent.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents
import SwiftData
import SwiftUI

@available(iOS 16.0, *)
struct CreateCSVBackupIntent: AppIntent, MovingBoxIntent {
    static let title: LocalizedStringResource = "Create CSV Backup"
    static let description: IntentDescription = "Export your inventory data to a CSV file"
    
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true
    
    @Parameter(title: "Location Filter", description: "Optional: Only export items from this location")
    var locationFilter: LocationEntity?
    
    @Parameter(title: "Label Filter", description: "Optional: Only export items with this label")
    var labelFilter: LabelEntity?
    
    @Parameter(title: "Include Photos", default: false, description: "Include photos in the backup (creates ZIP file)")
    var includePhotos: Bool
    
    static let parameterSummary = ParameterSummary(
        "Create CSV backup of inventory data"
    )
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView & ReturnsValue<IntentFile> {
        let baseIntent = BaseDataIntent()
        baseIntent.logIntentExecution("CreateCSVBackup", parameters: [
            "hasLocationFilter": locationFilter != nil,
            "hasLabelFilter": labelFilter != nil,
            "includePhotos": includePhotos
        ])
        
        // Get items based on filters
        let items = try await baseIntent.executeDataOperation { context in
            var predicate: Predicate<InventoryItem>?
            
            if let locationEntity = locationFilter, let labelEntity = labelFilter {
                // Both filters
                predicate = #Predicate<InventoryItem> { item in
                    item.location?.name == locationEntity.name && item.label?.name == labelEntity.name
                }
            } else if let locationEntity = locationFilter {
                // Location filter only
                predicate = #Predicate<InventoryItem> { item in
                    item.location?.name == locationEntity.name
                }
            } else if let labelEntity = labelFilter {
                // Label filter only
                predicate = #Predicate<InventoryItem> { item in
                    item.label?.name == labelEntity.name
                }
            }
            
            let descriptor = FetchDescriptor<InventoryItem>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.title)]
            )
            
            return try context.fetch(descriptor)
        }
        
        // Create export using existing DataManager
        let dataManager = DataManager()
        
        let exportResult: (data: Data, filename: String, itemCount: Int)
        
        if includePhotos {
            // Create ZIP export with photos
            let zipData = try await dataManager.createZIPExport(items: items)
            let timestamp = DateFormatter.filenameFriendly.string(from: Date())
            let filename = "MovingBox-Backup-\(timestamp).zip"
            exportResult = (zipData, filename, items.count)
        } else {
            // Create CSV export only
            let csvData = try await dataManager.createCSVExport(items: items)
            let timestamp = DateFormatter.filenameFriendly.string(from: Date())
            let filename = "MovingBox-Export-\(timestamp).csv"
            exportResult = (csvData, filename, items.count)
        }
        
        // Create IntentFile for return
        let intentFile = IntentFile(
            data: exportResult.data,
            filename: exportResult.filename,
            type: includePhotos ? .zip : .commaSeparatedValues
        )
        
        // Create response message
        let filterText = createFilterDescription()
        let fileType = includePhotos ? "ZIP backup" : "CSV export"
        let message = "Created \(fileType) with \(exportResult.itemCount) items\(filterText). File: \(exportResult.filename)"
        
        let dialog = IntentDialog(stringLiteral: message)
        
        // Create snippet view
        let snippetView = ExportSnippetView(
            filename: exportResult.filename,
            itemCount: exportResult.itemCount,
            fileSize: exportResult.data.count,
            includePhotos: includePhotos,
            locationFilter: locationFilter?.name,
            labelFilter: labelFilter?.name
        )
        
        return .result(value: intentFile, dialog: dialog, view: snippetView)
    }
    
    private func createFilterDescription() -> String {
        if let location = locationFilter?.name, let label = labelFilter?.name {
            return " from \(location) with \(label)"
        } else if let location = locationFilter?.name {
            return " from \(location)"
        } else if let label = labelFilter?.name {
            return " with \(label)"
        } else {
            return ""
        }
    }
}

@available(iOS 16.0, *)
struct ExportSnippetView: View {
    let filename: String
    let itemCount: Int
    let fileSize: Int
    let includePhotos: Bool
    let locationFilter: String?
    let labelFilter: String?
    
    private var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: includePhotos ? "archivebox.fill" : "doc.text.fill")
                    .foregroundColor(.green)
                Text("Export Complete")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // File info
                HStack {
                    Text(filename)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    Text(fileSizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Content details
                HStack {
                    Text("\(itemCount) items")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if includePhotos {
                        Text("• with photos")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Filters applied
                if locationFilter != nil || labelFilter != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Filters applied:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            if let location = locationFilter {
                                Label(location, systemImage: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let label = labelFilter {
                                Label(label, systemImage: "tag.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Export type
                HStack {
                    Image(systemName: includePhotos ? "photo.fill.on.rectangle.fill" : "tablecells.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(includePhotos ? "ZIP archive with photos" : "CSV spreadsheet")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
    }
}

// Extension for filename-friendly date formatting
private extension DateFormatter {
    static let filenameFriendly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}