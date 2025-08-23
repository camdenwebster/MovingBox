//
//  CreateItemFromDescriptionIntent.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents
import SwiftData
import SwiftUI

@available(iOS 16.0, *)
struct CreateItemFromDescriptionIntent: AppIntent, MovingBoxIntent {
    static let title: LocalizedStringResource = "Create Inventory Item from Description"
    static let description: IntentDescription = "Describe an item in text and use AI to automatically create structured inventory data"
    
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true
    
    @Parameter(title: "Item Description", description: "Describe the item you want to add to your inventory")
    var itemDescription: String
    
    @Parameter(title: "Open in App", default: false, description: "Open the created item in the app after creation")
    var openInApp: Bool
    
    static let parameterSummary = ParameterSummary(
        "Create inventory item from description: \(\.$itemDescription)"
    )
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let baseIntent = BaseDataIntent()
        baseIntent.logIntentExecution("CreateItemFromDescription", parameters: [
            "descriptionLength": itemDescription.count,
            "openInApp": openInApp
        ])
        
        // Validate input
        let trimmedDescription = itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            throw IntentError.invalidInput("Description cannot be empty")
        }
        
        guard trimmedDescription.count >= 3 else {
            throw IntentError.invalidInput("Description must be at least 3 characters long")
        }
        
        // Perform AI analysis of the description
        let analysisResult = try await performTextAnalysis(description: trimmedDescription)
        
        // Create inventory item from analysis
        let createdItem = try await baseIntent.executeDataOperation { context in
            let newItem = InventoryItem()
            newItem.title = analysisResult.title
            newItem.quantityString = analysisResult.quantity.isEmpty ? "1" : analysisResult.quantity
            newItem.quantityInt = Int(newItem.quantityString) ?? 1
            newItem.desc = analysisResult.description
            newItem.make = analysisResult.make
            newItem.model = analysisResult.model
            newItem.serial = analysisResult.serial
            newItem.notes = analysisResult.confidenceNotes
            newItem.insured = false
            newItem.hasUsedAI = true // Mark as AI-created
            newItem.createdAt = Date()
            
            // Set estimated price if provided
            if let price = analysisResult.estimatedPrice, price > 0 {
                newItem.price = Decimal(price)
            }
            
            // Try to match or create suggested location
            if !analysisResult.suggestedLocation.isEmpty {
                let locationPredicate = #Predicate<InventoryLocation> { location in
                    location.name.localizedCaseInsensitiveContains(analysisResult.suggestedLocation)
                }
                let locationDescriptor = FetchDescriptor<InventoryLocation>(predicate: locationPredicate)
                
                if let matchingLocation = try context.fetch(locationDescriptor).first {
                    newItem.location = matchingLocation
                } else if analysisResult.suggestedLocation.count <= 50 { // Reasonable length check
                    // Create new location if suggestion is reasonable
                    let newLocation = InventoryLocation(name: analysisResult.suggestedLocation)
                    context.insert(newLocation)
                    newItem.location = newLocation
                }
            }
            
            // Try to match or create suggested label/category
            if !analysisResult.suggestedCategory.isEmpty {
                let labelPredicate = #Predicate<InventoryLabel> { label in
                    label.name.localizedCaseInsensitiveContains(analysisResult.suggestedCategory)
                }
                let labelDescriptor = FetchDescriptor<InventoryLabel>(predicate: labelPredicate)
                
                if let matchingLabel = try context.fetch(labelDescriptor).first {
                    newItem.label = matchingLabel
                } else if analysisResult.suggestedCategory.count <= 30 { // Reasonable length check
                    // Create new label if suggestion is reasonable
                    let newLabel = InventoryLabel(name: analysisResult.suggestedCategory, colorHex: "#007AFF")
                    context.insert(newLabel)
                    newItem.label = newLabel
                }
            }
            
            context.insert(newItem)
            return newItem
        }
        
        // Create response message
        let locationText = createdItem.location?.name ?? "no specific location"
        let categoryText = createdItem.label?.name ?? "general category"
        let message = "Created '\(createdItem.title)' in \(locationText) under \(categoryText). AI extracted details from your description."
        
        let dialog = IntentDialog(stringLiteral: message)
        
        // Create snippet view
        let snippetView = DescriptionAnalysisSnippetView(
            title: createdItem.title,
            quantity: createdItem.quantityString,
            description: analysisResult.description,
            make: analysisResult.make,
            model: analysisResult.model,
            suggestedLocation: analysisResult.suggestedLocation,
            suggestedCategory: analysisResult.suggestedCategory,
            estimatedPrice: analysisResult.estimatedPrice,
            confidenceNotes: analysisResult.confidenceNotes
        )
        
        return .result(dialog: dialog, view: snippetView)
    }
    
    private func performTextAnalysis(description: String) async throws -> TextAnalysisResult {
        // Create a temporary model context for the analysis service
        let context = BaseDataIntent.sharedContainer.mainContext
        
        // Create settings manager instance (simplified for intent context)
        let settings = SettingsManager()
        
        // Use the new text analysis service
        let textAnalysisService = OpenAITextAnalysisService(settings: settings, modelContext: context)
        
        do {
            let result = try await textAnalysisService.analyzeDescription(description)
            return result
        } catch {
            throw IntentError.aiServiceError("Failed to analyze description: \(error.localizedDescription)")
        }
    }
}

@available(iOS 16.0, *)
struct DescriptionAnalysisSnippetView: View {
    let title: String
    let quantity: String
    let description: String
    let make: String
    let model: String
    let suggestedLocation: String
    let suggestedCategory: String
    let estimatedPrice: Double?
    let confidenceNotes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.purple)
                Text("AI Description Analysis")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                    .font(.caption)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Title and quantity
                HStack {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Qty: \(quantity)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // Description
                if !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Make and Model
                if !make.isEmpty || !model.isEmpty {
                    let makeModel = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
                    if !makeModel.isEmpty {
                        Text("Make/Model: \(makeModel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Suggested location and category
                HStack {
                    if !suggestedLocation.isEmpty {
                        Label(suggestedLocation, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !suggestedCategory.isEmpty {
                        Label(suggestedCategory, systemImage: "tag.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Price estimate
                    if let price = estimatedPrice, price > 0 {
                        Text("~$\(String(format: "%.0f", price))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                // Confidence notes (if provided)
                if !confidenceNotes.isEmpty {
                    Text(confidenceNotes)
                        .font(.caption2)
                        .foregroundColor(.tertiary)
                        .italic()
                        .lineLimit(2)
                }
                
                // Success indicator
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Item created from description")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
    }
}