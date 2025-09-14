//
//  ReportFileManager.swift
//  MovingBox
//
//  Created by Claude Code on 9/14/25.
//

import Foundation
import SwiftUI

/// Service for managing PDF report files with iCloud document sync integration
actor ReportFileManager {
    static let shared = ReportFileManager()
    
    private init() {}
    
    /// The directory where PDF reports are stored
    private var reportsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("Reports", isDirectory: true)
    }
    
    // MARK: - Directory Management
    
    /// Ensures the Reports directory exists, creating it if necessary
    func ensureReportsDirectoryExists() throws {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: reportsDirectory.path) {
            try fileManager.createDirectory(
                at: reportsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("📄 ReportFileManager - Created Reports directory at: \(reportsDirectory.path)")
        }
    }
    
    // MARK: - File Operations
    
    /// Saves PDF data to a file and returns the URL
    /// - Parameters:
    ///   - data: The PDF data to save
    ///   - reportId: Unique identifier for the report
    /// - Returns: URL where the file was saved
    func savePDF(data: Data, reportId: UUID) throws -> URL {
        try ensureReportsDirectoryExists()
        
        let fileURL = reportsDirectory.appendingPathComponent("\(reportId.uuidString).pdf")
        
        try data.write(to: fileURL)
        
        // Set file attributes for iCloud sync optimization
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false // Allow iCloud backup
        try fileURL.setResourceValues(resourceValues)
        
        print("📄 ReportFileManager - Saved PDF report to: \(fileURL.path)")
        return fileURL
    }
    
    /// Deletes a PDF file
    /// - Parameter fileURL: URL of the file to delete
    func deletePDF(at fileURL: URL) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("📄 ReportFileManager - File does not exist: \(fileURL.path)")
            return
        }
        
        try fileManager.removeItem(at: fileURL)
        print("📄 ReportFileManager - Deleted PDF report: \(fileURL.path)")
    }
    
    /// Checks if a PDF file exists
    /// - Parameter fileURL: URL of the file to check
    /// - Returns: True if the file exists
    func fileExists(at fileURL: URL) -> Bool {
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Gets the size of a PDF file in bytes
    /// - Parameter fileURL: URL of the file to measure
    /// - Returns: File size in bytes, or 0 if file doesn't exist
    func getFileSize(at fileURL: URL) -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int ?? 0
        } catch {
            print("📄 ReportFileManager - Error getting file size: \(error)")
            return 0
        }
    }
    
    // MARK: - Cleanup Operations
    
    /// Cleans up orphaned PDF files that don't have corresponding database records
    /// - Parameter validReportIds: Set of report IDs that should have files
    func cleanupOrphanedFiles(validReportIds: Set<UUID>) throws {
        try ensureReportsDirectoryExists()
        
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: reportsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: []
        )
        
        for fileURL in contents {
            guard fileURL.pathExtension == "pdf" else { continue }
            
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            guard let reportId = UUID(uuidString: fileName) else { continue }
            
            if !validReportIds.contains(reportId) {
                try fileManager.removeItem(at: fileURL)
                print("📄 ReportFileManager - Cleaned up orphaned file: \(fileName).pdf")
            }
        }
    }
    
    /// Removes old reports beyond a specified count limit
    /// - Parameter maxReports: Maximum number of reports to keep
    func cleanupOldReports(maxReports: Int = 50) throws {
        try ensureReportsDirectoryExists()
        
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: reportsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: []
        )
        
        let pdfFiles = contents.filter { $0.pathExtension == "pdf" }
        
        if pdfFiles.count <= maxReports {
            return
        }
        
        // Sort by creation date (oldest first)
        let sortedFiles = try pdfFiles.sorted { file1, file2 in
            let date1 = try file1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            let date2 = try file2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            return date1 < date2
        }
        
        // Delete oldest files beyond the limit
        let filesToDelete = sortedFiles.prefix(pdfFiles.count - maxReports)
        
        for fileURL in filesToDelete {
            try fileManager.removeItem(at: fileURL)
            print("📄 ReportFileManager - Cleaned up old report: \(fileURL.lastPathComponent)")
        }
    }
    
    // MARK: - Storage Statistics
    
    /// Gets statistics about report storage usage
    /// - Returns: Dictionary with storage statistics
    func getStorageStatistics() throws -> [String: Any] {
        try ensureReportsDirectoryExists()
        
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: reportsDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: []
        )
        
        let pdfFiles = contents.filter { $0.pathExtension == "pdf" }
        
        var totalSize: Int64 = 0
        var fileCount = pdfFiles.count
        var oldestDate: Date?
        var newestDate: Date?
        
        for fileURL in pdfFiles {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            
            if let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
            
            if let creationDate = resourceValues.creationDate {
                if oldestDate == nil || creationDate < oldestDate! {
                    oldestDate = creationDate
                }
                if newestDate == nil || creationDate > newestDate! {
                    newestDate = creationDate
                }
            }
        }
        
        return [
            "totalSizeBytes": totalSize,
            "totalSizeFormatted": ByteCountFormatter().string(fromByteCount: totalSize),
            "fileCount": fileCount,
            "oldestReportDate": oldestDate as Any,
            "newestReportDate": newestDate as Any,
            "averageFileSize": fileCount > 0 ? totalSize / Int64(fileCount) : 0
        ]
    }
    
    /// Gets the URL for a report file
    /// - Parameter reportId: The report ID
    /// - Returns: URL where the file should be located
    func getReportURL(for reportId: UUID) -> URL {
        return reportsDirectory.appendingPathComponent("\(reportId.uuidString).pdf")
    }
    
    /// Lists all PDF report files in the directory
    /// - Returns: Array of file URLs for all PDF reports
    func listAllReportFiles() throws -> [URL] {
        try ensureReportsDirectoryExists()
        
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: reportsDirectory,
            includingPropertiesForKeys: nil,
            options: []
        )
        
        return contents.filter { $0.pathExtension == "pdf" }
    }
}

// MARK: - MainActor Interface

extension ReportFileManager {
    
    /// MainActor version of savePDF for use in UI contexts
    @MainActor
    func savePDFFromMain(data: Data, reportId: UUID) async throws -> URL {
        return try await savePDF(data: data, reportId: reportId)
    }
    
    /// MainActor version of deletePDF for use in UI contexts
    @MainActor
    func deletePDFFromMain(at fileURL: URL) async throws {
        try await deletePDF(at: fileURL)
    }
    
    /// MainActor version of getStorageStatistics for use in UI contexts
    @MainActor
    func getStorageStatisticsFromMain() async throws -> [String: Any] {
        return try await getStorageStatistics()
    }
}