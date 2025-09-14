//
//  PDFGenerator.swift
//  MovingBox
//
//  Created by Claude Code on 9/14/25.
//

import Foundation
import SwiftUI
import PDFKit

/// Actor responsible for generating PDF reports in the background
actor PDFGenerator {
    static let shared = PDFGenerator()
    
    private init() {}
    
    // MARK: - PDF Generation
    
    /// Generates a complete PDF report from inventory items
    /// - Parameters:
    ///   - itemsByLocation: Items grouped by location
    ///   - homeName: Name of the home
    ///   - totalValue: Total value of all items
    ///   - progressCallback: Callback for progress updates
    /// - Returns: PDF data ready for saving
    func generatePDF(
        itemsByLocation: [String: [InventoryItem]],
        homeName: String,
        totalValue: Decimal,
        progressCallback: @escaping @Sendable (Double, String) async -> Void = { _, _ in }
    ) async throws -> Data {
        
        // Calculate total pages needed
        let itemCount = itemsByLocation.values.flatMap { $0 }.count
        let itemPages = Int(ceil(Double(itemCount) / 20.0)) // 20 items per page
        let totalPages = 3 + itemsByLocation.keys.count + itemPages // Cover + TOC + Summary + Location covers + Item pages
        
        await progressCallback(0.0, "Initializing PDF generation...")
        
        // Create PDF document
        let pdfDocument = PDFDocument()
        var currentPageIndex = 0
        
        // Generate cover page
        await progressCallback(0.1, "Creating cover page...")
        let coverPage = try await generateCoverPage(homeName: homeName, totalValue: totalValue, itemCount: itemCount)
        pdfDocument.insert(coverPage, at: currentPageIndex)
        currentPageIndex += 1
        
        // Generate table of contents
        await progressCallback(0.2, "Creating table of contents...")
        let tocPage = try await generateTableOfContents(itemsByLocation: itemsByLocation)
        pdfDocument.insert(tocPage, at: currentPageIndex)
        currentPageIndex += 1
        
        // Generate summary page
        await progressCallback(0.3, "Creating summary page...")
        let summaryPage = try await generateSummaryPage(itemsByLocation: itemsByLocation, totalValue: totalValue)
        pdfDocument.insert(summaryPage, at: currentPageIndex)
        currentPageIndex += 1
        
        // Generate location sections
        let sortedLocations = itemsByLocation.keys.sorted()
        let progressPerLocation = 0.6 / Double(sortedLocations.count)
        
        for (index, locationName) in sortedLocations.enumerated() {
            guard let items = itemsByLocation[locationName] else { continue }
            
            let baseProgress = 0.3 + (Double(index) * progressPerLocation)
            await progressCallback(baseProgress, "Processing \(locationName)...")
            
            // Location cover page
            let locationCoverPage = try await generateLocationCoverPage(locationName: locationName, items: items)
            pdfDocument.insert(locationCoverPage, at: currentPageIndex)
            currentPageIndex += 1
            
            // Item detail pages for this location
            let sortedItems = items.sorted { $0.title < $1.title }
            let itemPages = try await generateItemPages(items: sortedItems, locationName: locationName)
            
            for itemPage in itemPages {
                pdfDocument.insert(itemPage, at: currentPageIndex)
                currentPageIndex += 1
            }
        }
        
        await progressCallback(0.9, "Finalizing PDF...")
        
        // Add page numbers
        addPageNumbers(to: pdfDocument)
        
        // Convert to data
        guard let pdfData = pdfDocument.dataRepresentation() else {
            throw ReportError.pdfGenerationFailed("Failed to create PDF data")
        }
        
        await progressCallback(1.0, "PDF generation complete!")
        
        return pdfData
    }
    
    // MARK: - Page Generation Methods
    
    private func generateCoverPage(homeName: String, totalValue: Decimal, itemCount: Int) async throws -> PDFPage {
        let renderer = ImageRenderer(content: ReportCoverPageView(
            homeName: homeName,
            totalValue: totalValue,
            itemCount: itemCount,
            dateGenerated: Date()
        ))
        
        renderer.scale = 2.0
        
        guard let uiImage = renderer.uiImage else {
            throw ReportError.pdfGenerationFailed("Failed to render cover page")
        }
        
        return createPDFPage(from: uiImage)
    }
    
    private func generateTableOfContents(itemsByLocation: [String: [InventoryItem]]) async throws -> PDFPage {
        let renderer = ImageRenderer(content: ReportTableOfContentsView(
            itemsByLocation: itemsByLocation
        ))
        
        renderer.scale = 2.0
        
        guard let uiImage = renderer.uiImage else {
            throw ReportError.pdfGenerationFailed("Failed to render table of contents")
        }
        
        return createPDFPage(from: uiImage)
    }
    
    private func generateSummaryPage(itemsByLocation: [String: [InventoryItem]], totalValue: Decimal) async throws -> PDFPage {
        let renderer = ImageRenderer(content: ReportSummaryPageView(
            itemsByLocation: itemsByLocation,
            totalValue: totalValue
        ))
        
        renderer.scale = 2.0
        
        guard let uiImage = renderer.uiImage else {
            throw ReportError.pdfGenerationFailed("Failed to render summary page")
        }
        
        return createPDFPage(from: uiImage)
    }
    
    private func generateLocationCoverPage(locationName: String, items: [InventoryItem]) async throws -> PDFPage {
        let locationValue = items.reduce(Decimal.zero) { $0 + $1.price }
        
        let renderer = ImageRenderer(content: ReportLocationPageView(
            locationName: locationName,
            itemCount: items.count,
            locationValue: locationValue
        ))
        
        renderer.scale = 2.0
        
        guard let uiImage = renderer.uiImage else {
            throw ReportError.pdfGenerationFailed("Failed to render location cover page")
        }
        
        return createPDFPage(from: uiImage)
    }
    
    private func generateItemPages(items: [InventoryItem], locationName: String) async throws -> [PDFPage] {
        var pages: [PDFPage] = []
        let itemsPerPage = 20
        
        for i in stride(from: 0, to: items.count, by: itemsPerPage) {
            let endIndex = min(i + itemsPerPage, items.count)
            let pageItems = Array(items[i..<endIndex])
            
            let renderer = ImageRenderer(content: ReportItemDetailView(
                items: pageItems,
                locationName: locationName
            ))
            
            renderer.scale = 2.0
            
            guard let uiImage = renderer.uiImage else {
                throw ReportError.pdfGenerationFailed("Failed to render items page")
            }
            
            pages.append(createPDFPage(from: uiImage))
        }
        
        return pages
    }
    
    // MARK: - Helper Methods
    
    private func createPDFPage(from image: UIImage) -> PDFPage {
        let page = PDFPage(image: image)!
        
        // Set page bounds to letter size (612x792 points)
        let letterSize = CGRect(x: 0, y: 0, width: 612, height: 792)
        page.setBounds(letterSize, for: .mediaBox)
        
        return page
    }
    
    private func addPageNumbers(to document: PDFDocument) {
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            
            let pageNumber = i + 1
            let totalPages = document.pageCount
            
            // Create page number text
            let pageText = "Page \(pageNumber) of \(totalPages)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            let attributedString = NSAttributedString(string: pageText, attributes: attributes)
            
            // Position at bottom center
            let bounds = page.bounds(for: .mediaBox)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: (bounds.width - textSize.width) / 2,
                y: 20,
                width: textSize.width,
                height: textSize.height
            )
            
            // Add annotation with page number
            let textAnnotation = PDFAnnotation(bounds: textRect, forType: .freeText, withProperties: nil)
            textAnnotation.contents = pageText
            textAnnotation.font = UIFont.systemFont(ofSize: 10)
            textAnnotation.fontColor = .gray
            textAnnotation.alignment = .center
            
            page.addAnnotation(textAnnotation)
        }
    }
}

// MARK: - PDF Report Views

/// Cover page view for PDF reports
struct ReportCoverPageView: View {
    let homeName: String
    let totalValue: Decimal
    let itemCount: Int
    let dateGenerated: Date
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Title
            VStack(spacing: 10) {
                Text("Home Inventory Report")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(homeName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Statistics
            VStack(spacing: 20) {
                HStack(spacing: 40) {
                    StatView(title: "Total Items", value: "\(itemCount)")
                    StatView(title: "Total Value", value: CurrencyFormatter.format(totalValue))
                }
                
                StatView(title: "Generated", value: DateFormatter.reportDate.string(from: dateGenerated))
            }
            
            Spacer()
            
            // Footer
            Text("Generated by MovingBox")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 612, height: 792)
        .background(Color.white)
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

/// Table of contents view for PDF reports
struct ReportTableOfContentsView: View {
    let itemsByLocation: [String: [InventoryItem]]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Table of Contents")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 12) {
                TOCEntry(title: "Summary", page: 3)
                
                let sortedLocations = itemsByLocation.keys.sorted()
                for (index, location) in sortedLocations.enumerated() {
                    let pageNumber = 4 + index
                    TOCEntry(title: location, page: pageNumber)
                }
            }
            
            Spacer()
        }
        .padding(40)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(Color.white)
    }
}

struct TOCEntry: View {
    let title: String
    let page: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
            
            Spacer()
            
            Text("\(page)")
                .font(.system(size: 16))
        }
    }
}

/// Summary page view for PDF reports
struct ReportSummaryPageView: View {
    let itemsByLocation: [String: [InventoryItem]]
    let totalValue: Decimal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Inventory Summary")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 10)
            
            // Overall statistics
            VStack(alignment: .leading, spacing: 15) {
                SummaryRow(label: "Total Items", value: "\(itemsByLocation.values.flatMap { $0 }.count)")
                SummaryRow(label: "Total Locations", value: "\(itemsByLocation.keys.count)")
                SummaryRow(label: "Total Value", value: CurrencyFormatter.format(totalValue))
            }
            .padding(.bottom, 20)
            
            // By location breakdown
            Text("By Location")
                .font(.system(size: 18, weight: .semibold))
                .padding(.bottom, 10)
            
            ForEach(itemsByLocation.keys.sorted(), id: \.self) { location in
                let items = itemsByLocation[location] ?? []
                let locationValue = items.reduce(Decimal.zero) { $0 + $1.price }
                
                HStack {
                    Text(location)
                        .font(.system(size: 14))
                    
                    Spacer()
                    
                    Text("\(items.count) items")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(CurrencyFormatter.format(locationValue))
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
            
            Spacer()
        }
        .padding(40)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(Color.white)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
        }
    }
}

/// Location cover page view for PDF reports
struct ReportLocationPageView: View {
    let locationName: String
    let itemCount: Int
    let locationValue: Decimal
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text(locationName)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            HStack(spacing: 40) {
                StatView(title: "Items", value: "\(itemCount)")
                StatView(title: "Total Value", value: CurrencyFormatter.format(locationValue))
            }
            
            Spacer()
        }
        .padding(40)
        .frame(width: 612, height: 792)
        .background(Color.white)
    }
}

/// Item detail view for PDF reports  
struct ReportItemDetailView: View {
    let items: [InventoryItem]
    let locationName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("\(locationName) - Items")
                .font(.system(size: 18, weight: .bold))
                .padding(.bottom, 10)
            
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                ItemRow(item: item)
                
                if index < items.count - 1 {
                    Divider()
                }
            }
            
            Spacer()
        }
        .padding(40)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(Color.white)
    }
}

struct ItemRow: View {
    let item: InventoryItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Item image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                
                if !item.desc.isEmpty {
                    Text(item.desc)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    if !item.make.isEmpty {
                        Text(item.make)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if !item.model.isEmpty {
                        Text(item.model)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.format(item.price))
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Qty: \(item.quantityInt)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Date Formatter Extension

private extension DateFormatter {
    static let reportDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
}