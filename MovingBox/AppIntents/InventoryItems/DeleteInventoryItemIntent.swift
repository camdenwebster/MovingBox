//
//  DeleteInventoryItemIntent.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents
import SwiftData

@available(iOS 16.0, *)
struct DeleteInventoryItemIntent: AppIntent, MovingBoxIntent {
    static let title: LocalizedStringResource = "Delete Inventory Item"
    static let description: IntentDescription = "Delete an inventory item from your collection"
    
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true
    
    @Parameter(title: "Item", description: "The inventory item to delete")
    var item: InventoryItemEntity
    
    @Parameter(title: "Confirm Deletion", default: false, description: "Confirm you want to permanently delete this item")
    var confirmDeletion: Bool
    
    static let parameterSummary = ParameterSummary(
        "Delete \(\.$item)"
    )
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let baseIntent = BaseDataIntent()
        baseIntent.logIntentExecution("DeleteInventoryItem", parameters: [
            "itemTitle": item.title,
            "confirmed": confirmDeletion
        ])
        
        // Require confirmation to prevent accidental deletions
        guard confirmDeletion else {
            let message = "Are you sure you want to delete '\(item.title)'? This action cannot be undone. Please confirm deletion to proceed."
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
        
        let deletedTitle = try await baseIntent.executeDataOperation { context in
            // Find the item by ID
            guard let itemURL = URL(string: item.id),
                  let modelID = context.model.persistentModelID(for: itemURL),
                  let inventoryItem = context.model.registeredModel(for: modelID) as? InventoryItem else {
                throw IntentError.itemNotFound
            }
            
            let title = inventoryItem.title
            
            // Clean up associated images before deletion
            if let imageURL = inventoryItem.imageURL {
                let imageId = imageURL.lastPathComponent.replacingOccurrences(of: ".jpg", with: "")
                try await OptimizedImageManager.shared.deleteImage(id: imageId)
            }
            
            // Clean up secondary photos
            for photoURL in inventoryItem.secondaryPhotoURLs {
                try await OptimizedImageManager.shared.deleteSecondaryImage(urlString: photoURL)
            }
            
            // Delete the item from the context
            context.delete(inventoryItem)
            
            return title
        }
        
        let message = "Successfully deleted '\(deletedTitle)' from your inventory."
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}