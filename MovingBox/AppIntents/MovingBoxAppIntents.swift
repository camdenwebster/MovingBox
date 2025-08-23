//
//  MovingBoxAppIntents.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents

// MARK: - App Intent Registration

/// Main registration point for all MovingBox App Intents
@available(iOS 16.0, *)
public struct MovingBoxAppIntents {
    
    /// Register all app intents with the system
    public static func register() {
        // Intents are automatically registered when the app runs
        // This method can be used for any additional setup if needed
        print("📱 MovingBox App Intents registered")
    }
}

// MARK: - Intent Export for Testing

@available(iOS 16.0, *)
extension MovingBoxAppIntents {
    
    /// All available inventory item intents
    public static var inventoryIntents: [any AppIntent.Type] {
        [
            CreateInventoryItemIntent.self,
            CreateItemFromPhotoIntent.self,
            CreateItemFromDescriptionIntent.self,
            GetInventoryItemIntent.self,
            UpdateInventoryItemIntent.self,
            DeleteInventoryItemIntent.self,
            SearchInventoryItemsIntent.self
        ]
    }
    
    /// All available utility intents
    public static var utilityIntents: [any AppIntent.Type] {
        [
            CreateCSVBackupIntent.self,
            OpenCameraIntent.self,
            QuickCameraIntent.self
        ]
    }
    
    /// All available intents combined
    public static var allIntents: [any AppIntent.Type] {
        inventoryIntents + utilityIntents
    }
}

// MARK: - Intent Metadata

@available(iOS 16.0, *)
extension MovingBoxAppIntents {
    
    /// Metadata about all implemented intents
    public static var intentMetadata: [String: IntentMetadata] {
        [
            // Inventory Items
            "CreateInventoryItemIntent": IntentMetadata(
                title: "Create Inventory Item",
                description: "Create a new inventory item manually",
                category: .inventory,
                complexity: .simple
            ),
            "CreateItemFromPhotoIntent": IntentMetadata(
                title: "Create Item from Photo",
                description: "Use AI to create inventory item from photo",
                category: .inventory,
                complexity: .advanced
            ),
            "CreateItemFromDescriptionIntent": IntentMetadata(
                title: "Create Item from Description", 
                description: "Use AI to create inventory item from text description",
                category: .inventory,
                complexity: .advanced
            ),
            "GetInventoryItemIntent": IntentMetadata(
                title: "Get Inventory Item",
                description: "Retrieve details for a specific inventory item",
                category: .inventory,
                complexity: .simple
            ),
            "UpdateInventoryItemIntent": IntentMetadata(
                title: "Update Inventory Item",
                description: "Update a specific field of an inventory item",
                category: .inventory,
                complexity: .simple
            ),
            "DeleteInventoryItemIntent": IntentMetadata(
                title: "Delete Inventory Item",
                description: "Permanently delete an inventory item",
                category: .inventory,
                complexity: .simple
            ),
            "SearchInventoryItemsIntent": IntentMetadata(
                title: "Search Inventory Items",
                description: "Find inventory items by various criteria",
                category: .inventory,
                complexity: .intermediate
            ),
            
            // Utilities
            "CreateCSVBackupIntent": IntentMetadata(
                title: "Create CSV Backup",
                description: "Export inventory data to CSV or ZIP file",
                category: .utility,
                complexity: .intermediate
            ),
            "OpenCameraIntent": IntentMetadata(
                title: "Open Camera",
                description: "Launch camera to add new inventory item",
                category: .utility,
                complexity: .simple
            ),
            "QuickCameraIntent": IntentMetadata(
                title: "Quick Camera",
                description: "Launch camera with preset configurations",
                category: .utility,
                complexity: .simple
            )
        ]
    }
}

// MARK: - Supporting Types

public struct IntentMetadata {
    let title: String
    let description: String
    let category: IntentCategory
    let complexity: IntentComplexity
}

public enum IntentCategory {
    case inventory
    case location
    case label
    case home
    case insurance
    case utility
}

public enum IntentComplexity {
    case simple      // Basic CRUD operations
    case intermediate // Search, filtering, exports
    case advanced    // AI integration, complex workflows
}