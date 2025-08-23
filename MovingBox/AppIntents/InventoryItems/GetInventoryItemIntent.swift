//
//  GetInventoryItemIntent.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents
import SwiftData

@available(iOS 16.0, *)
struct GetInventoryItemIntent: AppIntent, MovingBoxIntent {
    static let title: LocalizedStringResource = "Get Inventory Item"
    static let description: IntentDescription = "Get details for a specific inventory item"
    
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true
    
    @Parameter(title: "Item", description: "The inventory item to retrieve")
    var item: InventoryItemEntity
    
    static let parameterSummary = ParameterSummary(
        "Get details for \(\.$item)"
    )
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let baseIntent = BaseDataIntent()
        baseIntent.logIntentExecution("GetInventoryItem", parameters: [
            "itemTitle": item.title
        ])
        
        let itemData = try await baseIntent.executeDataOperation { context in
            // Find the item by ID
            guard let itemURL = URL(string: item.id),
                  let modelID = context.model.persistentModelID(for: itemURL),
                  let inventoryItem = context.model.registeredModel(for: modelID) as? InventoryItem else {
                throw IntentError.itemNotFound
            }
            
            return ItemDetailsData(
                title: inventoryItem.title,
                quantity: inventoryItem.quantityString,
                description: inventoryItem.desc,
                serial: inventoryItem.serial,
                model: inventoryItem.model,
                make: inventoryItem.make,
                price: inventoryItem.price,
                insured: inventoryItem.insured,
                notes: inventoryItem.notes,
                location: inventoryItem.location?.name,
                label: inventoryItem.label?.name,
                hasImage: inventoryItem.imageURL != nil,
                secondaryPhotoCount: inventoryItem.secondaryPhotoURLs.count,
                createdAt: inventoryItem.createdAt
            )
        }
        
        // Create detailed response message
        var dialogParts: [String] = []
        dialogParts.append("Item: \(itemData.title)")
        dialogParts.append("Quantity: \(itemData.quantity)")
        
        if !itemData.description.isEmpty {
            dialogParts.append("Description: \(itemData.description)")
        }
        
        if let location = itemData.location, !location.isEmpty {
            dialogParts.append("Location: \(location)")
        }
        
        if let label = itemData.label, !label.isEmpty {
            dialogParts.append("Label: \(label)")
        }
        
        if itemData.price > 0 {
            dialogParts.append("Price: $\(itemData.price)")
        }
        
        if !itemData.make.isEmpty || !itemData.model.isEmpty {
            let makeModel = [itemData.make, itemData.model].filter { !$0.isEmpty }.joined(separator: " ")
            dialogParts.append("Make/Model: \(makeModel)")
        }
        
        if !itemData.serial.isEmpty {
            dialogParts.append("Serial: \(itemData.serial)")
        }
        
        if itemData.insured {
            dialogParts.append("This item is marked as insured")
        }
        
        let photoCount = (itemData.hasImage ? 1 : 0) + itemData.secondaryPhotoCount
        if photoCount > 0 {
            dialogParts.append("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
        }
        
        if !itemData.notes.isEmpty {
            dialogParts.append("Notes: \(itemData.notes)")
        }
        
        let dialog = IntentDialog(stringLiteral: dialogParts.joined(separator: ". "))
        
        // Create snippet view
        let snippetView = ItemDetailsSnippetView(itemData: itemData)
        
        return .result(dialog: dialog, view: snippetView)
    }
}

@available(iOS 16.0, *)
struct ItemDetailsData: Sendable {
    let title: String
    let quantity: String
    let description: String
    let serial: String
    let model: String
    let make: String
    let price: Decimal
    let insured: Bool
    let notes: String
    let location: String?
    let label: String?
    let hasImage: Bool
    let secondaryPhotoCount: Int
    let createdAt: Date
}

@available(iOS 16.0, *)
struct ItemDetailsSnippetView: View {
    let itemData: ItemDetailsData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "cube.box.fill")
                    .foregroundColor(.blue)
                Text("Item Details")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Title and quantity
                HStack {
                    Text(itemData.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Qty: \(itemData.quantity)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // Description
                if !itemData.description.isEmpty {
                    Text(itemData.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                // Location and Label row
                HStack {
                    if let location = itemData.location, !location.isEmpty {
                        Label(location, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let label = itemData.label, !label.isEmpty {
                        Label(label, systemImage: "tag.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Photo indicator
                    let photoCount = (itemData.hasImage ? 1 : 0) + itemData.secondaryPhotoCount
                    if photoCount > 0 {
                        Label("\(photoCount)", systemImage: "photo.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Make, Model, Serial
                if !itemData.make.isEmpty || !itemData.model.isEmpty || !itemData.serial.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        if !itemData.make.isEmpty || !itemData.model.isEmpty {
                            let makeModel = [itemData.make, itemData.model].filter { !$0.isEmpty }.joined(separator: " ")
                            Text("Make/Model: \(makeModel)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !itemData.serial.isEmpty {
                            Text("Serial: \(itemData.serial)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Price and insurance status
                HStack {
                    if itemData.price > 0 {
                        Text("$\(NSDecimalNumber(decimal: itemData.price).doubleValue, specifier: "%.2f")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    if itemData.insured {
                        Label("Insured", systemImage: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // Notes
                if !itemData.notes.isEmpty {
                    Text("Notes: \(itemData.notes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Created date
                Text("Created: \(itemData.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }
        }
        .padding()
    }
}