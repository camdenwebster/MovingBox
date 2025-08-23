//
//  SearchInventoryItemsIntent.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents
import SwiftData

@available(iOS 16.0, *)
struct SearchInventoryItemsIntent: AppIntent, MovingBoxIntent {
    static let title: LocalizedStringResource = "Search Inventory Items"
    static let description: IntentDescription = "Find inventory items by title, description, or other criteria"
    
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true
    
    @Parameter(title: "Search Query", description: "What to search for (item name, description, make, model, etc.)")
    var searchQuery: String
    
    @Parameter(title: "Location Filter", description: "Optional: Only search items in this location")
    var locationFilter: LocationEntity?
    
    @Parameter(title: "Label Filter", description: "Optional: Only search items with this label")
    var labelFilter: LabelEntity?
    
    @Parameter(title: "Maximum Results", default: 10, description: "Maximum number of results to return")
    var maxResults: Int
    
    static let parameterSummary = ParameterSummary(
        "Search for \(\.$searchQuery) in inventory"
    )
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let baseIntent = BaseDataIntent()
        baseIntent.logIntentExecution("SearchInventoryItems", parameters: [
            "queryLength": searchQuery.count,
            "hasLocationFilter": locationFilter != nil,
            "hasLabelFilter": labelFilter != nil,
            "maxResults": maxResults
        ])
        
        // Validate input
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw IntentError.invalidInput("Search query cannot be empty")
        }
        
        guard trimmedQuery.count >= 2 else {
            throw IntentError.invalidInput("Search query must be at least 2 characters long")
        }
        
        // Ensure reasonable max results
        let limitedMaxResults = min(max(1, maxResults), 50)
        
        let searchResults = try await baseIntent.executeDataOperation { context in
            var predicates: [Predicate<InventoryItem>] = []
            
            // Text search predicate
            let textPredicate = #Predicate<InventoryItem> { item in
                item.title.localizedStandardContains(trimmedQuery) ||
                item.desc.localizedStandardContains(trimmedQuery) ||
                item.make.localizedStandardContains(trimmedQuery) ||
                item.model.localizedStandardContains(trimmedQuery) ||
                item.serial.localizedStandardContains(trimmedQuery) ||
                item.notes.localizedStandardContains(trimmedQuery)
            }
            predicates.append(textPredicate)
            
            // Location filter
            if let locationEntity = locationFilter {
                let locationPredicate = #Predicate<InventoryItem> { item in
                    item.location?.name == locationEntity.name
                }
                predicates.append(locationPredicate)
            }
            
            // Label filter  
            if let labelEntity = labelFilter {
                let labelPredicate = #Predicate<InventoryItem> { item in
                    item.label?.name == labelEntity.name
                }
                predicates.append(labelPredicate)
            }
            
            // Combine predicates
            let combinedPredicate = predicates.reduce(predicates[0]) { result, predicate in
                #Predicate<InventoryItem> { item in
                    result.evaluate(item) && predicate.evaluate(item)
                }
            }
            
            var descriptor = FetchDescriptor<InventoryItem>(
                predicate: combinedPredicate,
                sortBy: [SortDescriptor(\.title)]
            )
            descriptor.fetchLimit = limitedMaxResults
            
            let items = try context.fetch(descriptor)
            
            return items.map { item in
                SearchResultItem(
                    id: item.persistentModelID.uriRepresentation().absoluteString,
                    title: item.title,
                    quantity: item.quantityString,
                    description: item.desc,
                    location: item.location?.name,
                    label: item.label?.name,
                    make: item.make,
                    model: item.model,
                    price: item.price,
                    hasImage: item.imageURL != nil
                )
            }
        }
        
        // Create response message
        let resultsCount = searchResults.count
        let locationText = locationFilter?.name ?? "all locations"
        let labelText = labelFilter?.name ?? "all categories"
        
        let message: String
        if resultsCount == 0 {
            message = "No items found matching '\(trimmedQuery)' in \(locationText) with \(labelText)."
        } else if resultsCount == 1 {
            message = "Found 1 item matching '\(trimmedQuery)': \(searchResults[0].title)"
        } else {
            let itemTitles = searchResults.prefix(3).map(\.title).joined(separator: ", ")
            let remaining = resultsCount > 3 ? " and \(resultsCount - 3) more" : ""
            message = "Found \(resultsCount) items matching '\(trimmedQuery)': \(itemTitles)\(remaining)"
        }
        
        let dialog = IntentDialog(stringLiteral: message)
        
        // Create snippet view
        let snippetView = SearchResultsSnippetView(
            query: trimmedQuery,
            results: searchResults,
            locationFilter: locationFilter?.name,
            labelFilter: labelFilter?.name
        )
        
        return .result(dialog: dialog, view: snippetView)
    }
}

@available(iOS 16.0, *)
struct SearchResultItem: Sendable {
    let id: String
    let title: String
    let quantity: String
    let description: String
    let location: String?
    let label: String?
    let make: String
    let model: String
    let price: Decimal
    let hasImage: Bool
}

@available(iOS 16.0, *)
struct SearchResultsSnippetView: View {
    let query: String
    let results: [SearchResultItem]
    let locationFilter: String?
    let labelFilter: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                Text("Search Results")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(results.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Query and filters
            VStack(alignment: .leading, spacing: 4) {
                Text("Query: \"\(query)\"")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
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
            
            // Results list (show first few)
            if results.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    Text("No items found")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(results.prefix(5).enumerated()), id: \.offset) { index, result in
                        HStack {
                            if result.hasImage {
                                Image(systemName: "photo.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption2)
                            } else {
                                Image(systemName: "cube.box")
                                    .foregroundColor(.gray)
                                    .font(.caption2)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                HStack {
                                    Text("Qty: \(result.quantity)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    if let location = result.location, !location.isEmpty {
                                        Text("• \(location)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let label = result.label, !label.isEmpty {
                                        Text("• \(label)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if result.price > 0 {
                                Text("$\(NSDecimalNumber(decimal: result.price).doubleValue, specifier: "%.0f")")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 2)
                        
                        if index < min(4, results.count - 1) {
                            Divider()
                        }
                    }
                    
                    // Show count if more results available
                    if results.count > 5 {
                        Text("and \(results.count - 5) more results...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
        }
        .padding()
    }
}