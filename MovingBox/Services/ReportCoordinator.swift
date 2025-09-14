//
//  ReportCoordinator.swift
//  MovingBox
//
//  Created by Claude Code on 9/14/25.
//

import Foundation
import SwiftData
import SwiftUI
import UserNotifications

/// Main coordinator for PDF report generation workflow
@MainActor
@Observable
class ReportCoordinator {
    
    // MARK: - Properties
    
    /// Current generation progress (0.0 to 1.0)
    var generationProgress: Double = 0.0
    
    /// Current generation status message
    var statusMessage: String = ""
    
    /// Currently generating report ID (for progress tracking)
    var currentlyGenerating: UUID? = nil
    
    /// Whether a generation is in progress
    var isGenerating: Bool {
        return currentlyGenerating != nil
    }
    
    /// Model context for SwiftData operations
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    init() {
        setupNotificationCategories()
    }
    
    /// Sets the model context for database operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Report Generation
    
    /// Starts PDF report generation for inventory items
    /// - Parameters:
    ///   - items: Array of inventory items to include
    ///   - homeName: Name of the home for the report
    /// - Returns: The created report record
    func generateReport(
        for items: [InventoryItem],
        homeName: String = "Home Inventory"
    ) async throws -> GeneratedReport {
        guard let modelContext = modelContext else {
            throw ReportError.noModelContext
        }
        
        // Prevent concurrent generations
        guard currentlyGenerating == nil else {
            throw ReportError.generationInProgress
        }
        
        // Calculate statistics
        let locations = Set(items.compactMap { $0.location }).count
        let totalValue = items.reduce(Decimal.zero) { $0 + $1.price }
        
        // Create report record immediately so user sees it
        let report = GeneratedReport.builder(
            title: "Home Inventory Report - \(DateFormatter.reportTitle.string(from: Date()))",
            itemCount: items.count
        )
        .homeName(homeName)
        .locationCount(locations)
        .totalValue(totalValue)
        .build()
        
        modelContext.insert(report)
        try modelContext.save()
        
        // Track generation
        currentlyGenerating = report.id
        generationProgress = 0.0
        statusMessage = "Preparing report..."
        
        // Generate in background
        Task.detached { [weak self] in
            await self?.performGeneration(report: report, items: items, homeName: homeName)
        }
        
        return report
    }
    
    /// Cancels current report generation
    func cancelGeneration() async {
        guard let reportId = currentlyGenerating else { return }
        
        currentlyGenerating = nil
        generationProgress = 0.0
        statusMessage = ""
        
        // Mark report as failed in database
        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<GeneratedReport>(
                predicate: #Predicate { $0.id == reportId }
            )
            
            if let reports = try? modelContext.fetch(descriptor),
               let report = reports.first {
                report.markFailed(error: ReportError.cancelled)
                try? modelContext.save()
            }
        }
    }
    
    // MARK: - Private Generation Logic
    
    private func performGeneration(
        report: GeneratedReport, 
        items: [InventoryItem], 
        homeName: String
    ) async {
        do {
            await updateProgress(0.1, "Organizing items...")
            
            // Group items by location
            let itemsByLocation = Dictionary(grouping: items) { item in
                item.location?.name ?? "Unassigned"
            }
            
            await updateProgress(0.2, "Creating PDF structure...")
            
            // Generate PDF using PDFGenerator
            let pdfData = try await PDFGenerator.shared.generatePDF(
                itemsByLocation: itemsByLocation,
                homeName: homeName,
                totalValue: report.totalValue,
                progressCallback: { progress, message in
                    Task { @MainActor in
                        await self.updateProgress(0.2 + (progress * 0.7), message)
                    }
                }
            )
            
            await updateProgress(0.9, "Saving PDF file...")
            
            // Save PDF file
            let fileURL = try await ReportFileManager.shared.savePDF(
                data: pdfData, 
                reportId: report.id
            )
            
            let fileSize = await ReportFileManager.shared.getFileSize(at: fileURL)
            
            await updateProgress(1.0, "Report complete!")
            
            // Update report in database
            await MainActor.run {
                report.markCompleted(fileURL: fileURL, fileSize: fileSize)
                try? modelContext?.save()
                
                // Clear generation state
                currentlyGenerating = nil
                generationProgress = 0.0
                statusMessage = ""
            }
            
            // Send completion notification
            await sendCompletionNotification(for: report)
            
            // Track success in telemetry
            TelemetryManager.shared.trackReportGenerated(
                itemCount: items.count,
                locationCount: report.locationCount,
                fileSize: fileSize,
                success: true
            )
            
        } catch {
            print("📄 ReportCoordinator - Generation failed: \(error)")
            
            // Update report as failed
            await MainActor.run {
                report.markFailed(error: error)
                try? modelContext?.save()
                
                // Clear generation state
                currentlyGenerating = nil
                generationProgress = 0.0
                statusMessage = ""
            }
            
            // Send failure notification
            await sendFailureNotification(for: report, error: error)
            
            // Track failure in telemetry
            TelemetryManager.shared.trackReportGenerated(
                itemCount: items.count,
                locationCount: report.locationCount,
                fileSize: 0,
                success: false,
                error: error.localizedDescription
            )
        }
    }
    
    private func updateProgress(_ progress: Double, _ message: String) async {
        await MainActor.run {
            self.generationProgress = progress
            self.statusMessage = message
        }
    }
    
    // MARK: - Report Management
    
    /// Deletes a generated report and its associated file
    /// - Parameter report: The report to delete
    func deleteReport(_ report: GeneratedReport) async throws {
        guard let modelContext = modelContext else {
            throw ReportError.noModelContext
        }
        
        // Delete file if it exists
        if let fileURL = report.fileURL {
            try await ReportFileManager.shared.deletePDF(at: fileURL)
        }
        
        // Delete from database
        modelContext.delete(report)
        try modelContext.save()
        
        // Track deletion
        TelemetryManager.shared.trackReportDeleted(
            reportId: report.id.uuidString,
            itemCount: report.itemCount
        )
    }
    
    /// Shares a completed report
    /// - Parameter report: The report to share
    /// - Returns: URL for sharing
    func shareReport(_ report: GeneratedReport) async throws -> URL {
        guard report.isShareable, let fileURL = report.fileURL else {
            throw ReportError.reportNotShareable
        }
        
        guard await ReportFileManager.shared.fileExists(at: fileURL) else {
            throw ReportError.fileNotFound
        }
        
        // Track share action
        TelemetryManager.shared.trackReportShared(
            reportId: report.id.uuidString,
            itemCount: report.itemCount,
            fileSize: report.fileSize
        )
        
        return fileURL
    }
    
    // MARK: - Cleanup Operations
    
    /// Performs maintenance on report files and database records
    func performMaintenance() async throws {
        guard let modelContext = modelContext else { return }
        
        // Get all report IDs from database
        let descriptor = FetchDescriptor<GeneratedReport>()
        let reports = try modelContext.fetch(descriptor)
        let validReportIds = Set(reports.map { $0.id })
        
        // Clean up orphaned files
        try await ReportFileManager.shared.cleanupOrphanedFiles(validReportIds: validReportIds)
        
        // Clean up old reports (keep last 50)
        try await ReportFileManager.shared.cleanupOldReports(maxReports: 50)
        
        // Remove database records for missing files
        for report in reports where report.status == .completed {
            if let fileURL = report.fileURL,
               !await ReportFileManager.shared.fileExists(at: fileURL) {
                modelContext.delete(report)
            }
        }
        
        try modelContext.save()
    }
    
    // MARK: - Notifications
    
    private func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        let viewAction = UNNotificationAction(
            identifier: "VIEW_REPORT",
            title: "View Report",
            options: [.foreground]
        )
        
        let shareAction = UNNotificationAction(
            identifier: "SHARE_REPORT", 
            title: "Share",
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: "REPORT_COMPLETED",
            actions: [viewAction, shareAction],
            intentIdentifiers: []
        )
        
        center.setNotificationCategories([category])
    }
    
    private func sendCompletionNotification(for report: GeneratedReport) async {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "PDF Report Ready"
        content.body = "Your \(report.itemCount)-item inventory report has been generated successfully."
        content.categoryIdentifier = "REPORT_COMPLETED"
        content.userInfo = ["reportId": report.id.uuidString]
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "report-completed-\(report.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        try? await center.add(request)
    }
    
    private func sendFailureNotification(for report: GeneratedReport, error: Error) async {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Report Generation Failed"
        content.body = "Unable to generate your inventory report. Please try again."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "report-failed-\(report.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        try? await center.add(request)
    }
}

// MARK: - Report Errors

enum ReportError: LocalizedError {
    case noModelContext
    case generationInProgress
    case cancelled
    case reportNotShareable
    case fileNotFound
    case pdfGenerationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noModelContext:
            return "Database context not available"
        case .generationInProgress:
            return "A report generation is already in progress"
        case .cancelled:
            return "Report generation was cancelled"
        case .reportNotShareable:
            return "Report is not ready for sharing"
        case .fileNotFound:
            return "Report file not found"
        case .pdfGenerationFailed(let message):
            return "PDF generation failed: \(message)"
        }
    }
}

// MARK: - Date Formatter Extension

private extension DateFormatter {
    static let reportTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}