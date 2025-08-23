//
//  CreateInventoryItemIntent.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents
import SwiftData

@available(iOS 16.0, *)
struct CreateInventoryItemIntent: AppIntent, MovingBoxIntent {
    static let title: LocalizedStringResource = "Create Inventory Item"
    static let description: IntentDescription = "Create a new inventory item with the specified details"
    
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true
    
    @Parameter(title: "Title", description: "The name of the inventory item")
    var title: String
    
    @Parameter(title: "Quantity", default: "1", description: "The quantity of this item")
    var quantity: String
    
    @Parameter(title: "Description", description: "Optional description of the item")
    var itemDescription: String?
    
    @Parameter(title: "Location", description: "Optional location where the item is stored")
    var location: LocationEntity?
    
    @Parameter(title: "Label", description: "Optional label/category for the item")
    var label: LabelEntity?
    
    @Parameter(title: "Price", description: "Optional price of the item")
    var price: Double?
    
    @Parameter(title: "Serial Number", description: "Optional serial number")
    var serial: String?
    
    @Parameter(title: "Model", description: "Optional model information")
    var model: String?
    
    @Parameter(title: "Make", description: "Optional make/brand information")
    var make: String?
    
    @Parameter(title: "Notes", description: "Optional additional notes")
    var notes: String?
    
    @Parameter(title: "Open in App", default: false, description: "Open the created item in the app")
    var openInApp: Bool
    
    static let parameterSummary = ParameterSummary(
        "Create inventory item \(\.$title) with quantity \(\.$quantity)"
    )
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let baseIntent = BaseDataIntent()
        baseIntent.logIntentExecution("CreateInventoryItem", parameters: [
            "title": title,
            "quantity": quantity,
            "hasLocation": location != nil,
            "hasLabel": label != nil,
            "openInApp": openInApp
        ])
        
        // Validate required fields
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IntentError.invalidInput("Title cannot be empty")
        }
        
        // Validate quantity
        let trimmedQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuantity.isEmpty, Int(trimmedQuantity) != nil else {
            throw IntentError.invalidInput("Quantity must be a valid number")
        }
        
        let result = try await baseIntent.executeDataOperation { context in
            // Create new inventory item
            let newItem = InventoryItem()
            newItem.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            newItem.quantityString = trimmedQuantity
            newItem.quantityInt = Int(trimmedQuantity) ?? 1
            newItem.desc = itemDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            newItem.serial = serial?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            newItem.model = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            newItem.make = make?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            newItem.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            newItem.insured = false // Default value
            newItem.hasUsedAI = false // Manual creation
            newItem.createdAt = Date()
            
            // Set price if provided
            if let priceValue = price, priceValue >= 0 {
                newItem.price = Decimal(priceValue)
            }
            
            // Set location if provided
            if let locationEntity = location {
                let locationPredicate = #Predicate<InventoryLocation> { loc in
                    loc.name == locationEntity.name
                }
                let locationDescriptor = FetchDescriptor<InventoryLocation>(predicate: locationPredicate)
                if let existingLocation = try context.fetch(locationDescriptor).first {
                    newItem.location = existingLocation
                }
            }
            
            // Set label if provided
            if let labelEntity = label {
                let labelPredicate = #Predicate<InventoryLabel> { lbl in
                    lbl.name == labelEntity.name
                }
                let labelDescriptor = FetchDescriptor<InventoryLabel>(predicate: labelPredicate)
                if let existingLabel = try context.fetch(labelDescriptor).first {
                    newItem.label = existingLabel
                }
            }
            
            // Insert into context
            context.insert(newItem)
            
            return newItem
        }
        
        // Create response message
        let locationText = location?.name ?? "No location"
        let labelText = label?.name ?? "No label"
        let message = "Created '\(result.title)' (qty: \(result.quantityString)) in \(locationText) with \(labelText)"
        
        let dialog = IntentDialog(stringLiteral: message)
        
        // Create snippet view data
        let snippetView = CreateItemSnippetView(
            title: result.title,
            quantity: result.quantityString,
            location: location?.name,
            label: label?.name,
            price: price
        )
        
        if openInApp {
            // TODO: Implement deep linking to created item
            return .result(dialog: dialog, view: snippetView)
        } else {
            return .result(dialog: dialog, view: snippetView)
        }
    }
}

@available(iOS 16.0, *)
struct CreateItemSnippetView: View {
    let title: String
    let quantity: String
    let location: String?
    let label: String?
    let price: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                Text("Item Created")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Quantity: \(quantity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let location = location {
                    Text("📍 \(location)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let label = label {
                    Text("🏷️ \(label)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let price = price, price > 0 {
                    Text("💰 $\(String(format: "%.2f", price))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}