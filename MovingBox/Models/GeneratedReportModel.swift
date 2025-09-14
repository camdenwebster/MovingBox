//
//  GeneratedReportModel.swift
//  MovingBox
//
//  Created by Claude Code on 9/14/25.
//

import Foundation
import SwiftData
import SwiftUI

/// Represents the status of a PDF report generation
enum ReportStatus: String, CaseIterable, Codable {
    case generating = "generating"
    case completed = "completed" 
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .generating:
            return "Generating..."
        case .completed:
            return "Ready"
        case .failed:
            return "Failed"
        }
    }
    
    var icon: String {
        switch self {
        case .generating:
            return "arrow.clockwise"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .generating:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

/// SwiftData model for tracking generated PDF reports with metadata and file management
@Model
class GeneratedReport {
    var id: UUID
    var title: String
    var dateCreated: Date
    var itemCount: Int
    var status: ReportStatus
    var fileURL: URL?
    var fileSize: Int
    var errorMessage: String?
    var homeName: String
    var locationCount: Int
    var totalValue: Decimal
    
    /// Creates a new GeneratedReport with the specified parameters
    /// - Parameters:
    ///   - title: Display title for the report
    ///   - itemCount: Number of items included in the report
    ///   - homeName: Name of the home the report is for
    ///   - locationCount: Number of locations included
    ///   - totalValue: Total value of items in the report
    init(
        title: String,
        itemCount: Int,
        homeName: String = "",
        locationCount: Int = 0,
        totalValue: Decimal = 0
    ) {
        self.id = UUID()
        self.title = title
        self.dateCreated = Date()
        self.itemCount = itemCount
        self.status = .generating
        self.fileURL = nil
        self.fileSize = 0
        self.errorMessage = nil
        self.homeName = homeName
        self.locationCount = locationCount
        self.totalValue = totalValue
    }
    
    /// Marks the report as successfully completed with file information
    /// - Parameters:
    ///   - fileURL: URL where the PDF file is stored
    ///   - fileSize: Size of the generated PDF file in bytes
    func markCompleted(fileURL: URL, fileSize: Int) {
        self.status = .completed
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.errorMessage = nil
    }
    
    /// Marks the report as failed with an error message
    /// - Parameter error: The error that caused the failure
    func markFailed(error: Error) {
        self.status = .failed
        self.errorMessage = error.localizedDescription
        self.fileURL = nil
        self.fileSize = 0
    }
    
    /// Returns the file size in a human-readable format
    var formattedFileSize: String {
        guard fileSize > 0 else { return "0 KB" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
    
    /// Returns the date created in a user-friendly format
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateCreated)
    }
    
    /// Returns whether the PDF file exists on disk
    var fileExists: Bool {
        guard let fileURL = fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Calculates the age of the report in days
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: dateCreated, to: Date()).day ?? 0
    }
    
    /// Returns whether the report is ready for sharing
    var isShareable: Bool {
        return status == .completed && fileExists
    }
    
    /// Returns a subtitle with report details for UI display
    var subtitle: String {
        let itemText = itemCount == 1 ? "item" : "items"
        let locationText = locationCount == 1 ? "location" : "locations"
        return "\(itemCount) \(itemText) • \(locationCount) \(locationText) • \(CurrencyFormatter.format(totalValue))"
    }
    
    /// Returns the estimated file path where the PDF should be stored
    /// This is used for file management operations
    var expectedFilePath: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsDir = documentsPath.appendingPathComponent("Reports", isDirectory: true)
        return reportsDir.appendingPathComponent("\(id.uuidString).pdf")
    }
    
    /// Cleans up associated files when the report is deleted
    func cleanup() throws {
        if let fileURL = fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            print("📄 GeneratedReport - Cleaned up file for report: \(title)")
        }
    }
}

// MARK: - Convenience Extensions

extension GeneratedReport {
    
    /// Returns all reports sorted by creation date (newest first)
    static func allReportsSortedByDate() -> FetchDescriptor<GeneratedReport> {
        let descriptor = FetchDescriptor<GeneratedReport>(
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return descriptor
    }
    
    /// Returns only completed reports
    static func completedReports() -> FetchDescriptor<GeneratedReport> {
        let descriptor = FetchDescriptor<GeneratedReport>(
            predicate: #Predicate { $0.status.rawValue == "completed" },
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return descriptor
    }
    
    /// Returns reports that are currently generating
    static func generatingReports() -> FetchDescriptor<GeneratedReport> {
        let descriptor = FetchDescriptor<GeneratedReport>(
            predicate: #Predicate { $0.status.rawValue == "generating" },
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return descriptor
    }
    
    /// Returns failed reports that might need cleanup
    static func failedReports() -> FetchDescriptor<GeneratedReport> {
        let descriptor = FetchDescriptor<GeneratedReport>(
            predicate: #Predicate { $0.status.rawValue == "failed" },
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return descriptor
    }
}

// MARK: - Builder Pattern

extension GeneratedReport {
    
    /// Builder for creating GeneratedReport with optional properties
    @MainActor
    final class Builder {
        private let report: GeneratedReport
        
        init(title: String, itemCount: Int) {
            self.report = GeneratedReport(title: title, itemCount: itemCount)
        }
        
        @discardableResult
        func homeName(_ homeName: String) -> Builder {
            report.homeName = homeName
            return self
        }
        
        @discardableResult
        func locationCount(_ locationCount: Int) -> Builder {
            report.locationCount = locationCount
            return self
        }
        
        @discardableResult
        func totalValue(_ totalValue: Decimal) -> Builder {
            report.totalValue = totalValue
            return self
        }
        
        func build() -> GeneratedReport {
            return report
        }
    }
    
    /// Create a new GeneratedReport with builder pattern
    @MainActor
    static func builder(title: String, itemCount: Int) -> Builder {
        return Builder(title: title, itemCount: itemCount)
    }
}