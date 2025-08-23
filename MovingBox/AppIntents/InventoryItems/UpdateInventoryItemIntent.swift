//
//  UpdateInventoryItemIntent.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents
import SwiftData

@available(iOS 16.0, *)
struct UpdateInventoryItemIntent: AppIntent, MovingBoxIntent {
    static let title: LocalizedStringResource = "Update Inventory Item"
    static let description: IntentDescription = "Update a specific field of an existing inventory item"
    
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true
    
    @Parameter(title: "Item", description: "The inventory item to update")
    var item: InventoryItemEntity
    
    @Parameter(title: "Field", description: "The field to update")
    var field: ItemField
    
    @Parameter(title: "New Value", description: "The new value for the field")
    var newValue: String
    
    static let parameterSummary = ParameterSummary(
        "Update \(\.$item) \(\.$field) to \(\.$newValue)"
    )
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let baseIntent = BaseDataIntent()
        baseIntent.logIntentExecution("UpdateInventoryItem", parameters: [
            "itemTitle": item.title,
            "field": field.rawValue,
            "newValueLength": newValue.count
        ])
        
        // Validate input
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            throw IntentError.invalidInput("New value cannot be empty")
        }
        
        let updatedItem = try await baseIntent.executeDataOperation { context in
            // Find the item by ID
            guard let itemURL = URL(string: item.id),
                  let modelID = context.model.persistentModelID(for: itemURL),
                  let inventoryItem = context.model.registeredModel(for: modelID) as? InventoryItem else {
                throw IntentError.itemNotFound
            }
            
            // Update the specified field
            switch field {
            case .title:
                inventoryItem.title = trimmedValue
            case .quantity:
                guard let quantityInt = Int(trimmedValue) else {
                    throw IntentError.invalidInput("Quantity must be a valid number")
                }
                inventoryItem.quantityString = trimmedValue
                inventoryItem.quantityInt = quantityInt
            case .description:
                inventoryItem.desc = trimmedValue
            case .serial:
                inventoryItem.serial = trimmedValue
            case .model:
                inventoryItem.model = trimmedValue
            case .make:
                inventoryItem.make = trimmedValue
            case .price:
                if let priceDouble = Double(trimmedValue), priceDouble >= 0 {
                    inventoryItem.price = Decimal(priceDouble)
                } else {
                    throw IntentError.invalidInput("Price must be a valid positive number")
                }
            case .insured:
                let boolValue = ["true", "yes", "1", "on"].contains(trimmedValue.lowercased())
                inventoryItem.insured = boolValue
            case .notes:
                inventoryItem.notes = trimmedValue
            }
            
            return inventoryItem
        }
        
        // Create response message
        let fieldName = field.caseDisplayRepresentations[field]?.title ?? field.rawValue
        let displayValue = field == .insured ? (updatedItem.insured ? "Yes" : "No") : trimmedValue
        let message = "Updated '\(updatedItem.title)' - \(fieldName): \(displayValue)"
        
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}