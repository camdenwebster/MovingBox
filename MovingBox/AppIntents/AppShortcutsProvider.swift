//
//  AppShortcutsProvider.swift
//  MovingBox
//
//  Created by Claude on 8/23/25.
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct MovingBoxAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            // MARK: - Primary Actions (Most Common)
            
            AppShortcut(
                intent: CreateInventoryItemIntent(),
                phrases: [
                    "Add item to \(.applicationName)",
                    "Create inventory item in \(.applicationName)",
                    "Add new item",
                    "Create item"
                ],
                shortTitle: "Add Item",
                systemImageName: "plus.circle.fill"
            ),
            
            AppShortcut(
                intent: CreateItemFromPhotoIntent(),
                phrases: [
                    "Add item from photo in \(.applicationName)",
                    "Scan item with \(.applicationName)",
                    "Create item from picture",
                    "Photo inventory item"
                ],
                shortTitle: "Add from Photo",
                systemImageName: "camera.viewfinder"
            ),
            
            AppShortcut(
                intent: SearchInventoryItemsIntent(),
                phrases: [
                    "Search inventory in \(.applicationName)",
                    "Find item in \(.applicationName)",
                    "Search my items",
                    "Find inventory"
                ],
                shortTitle: "Search Items",
                systemImageName: "magnifyingglass"
            ),
            
            AppShortcut(
                intent: OpenCameraIntent(),
                phrases: [
                    "Open camera in \(.applicationName)",
                    "Take inventory photo",
                    "Scan new item",
                    "Add item with camera"
                ],
                shortTitle: "Open Camera",
                systemImageName: "camera.fill"
            ),
            
            // MARK: - AI-Powered Actions
            
            AppShortcut(
                intent: CreateItemFromDescriptionIntent(),
                phrases: [
                    "Describe item for \(.applicationName)",
                    "Add item by description",
                    "Tell \(.applicationName) about item",
                    "Create item from text"
                ],
                shortTitle: "Describe Item",
                systemImageName: "text.bubble.fill"
            ),
            
            // MARK: - Quick Camera Presets
            
            AppShortcut(
                intent: QuickCameraIntent(),
                phrases: [
                    "Quick camera for electronics",
                    "Scan electronics",
                    "Add electronic item"
                ],
                shortTitle: "Electronics Camera",
                systemImageName: "tv.fill",
                parameterSummary: ParameterSummary("Quick camera for \(\.$preset)") {
                    \QuickCameraIntent.$preset = .electronics
                }
            ),
            
            AppShortcut(
                intent: QuickCameraIntent(),
                phrases: [
                    "Quick camera for furniture",
                    "Scan furniture",
                    "Add furniture item"
                ],
                shortTitle: "Furniture Camera", 
                systemImageName: "sofa.fill",
                parameterSummary: ParameterSummary("Quick camera for \(\.$preset)") {
                    \QuickCameraIntent.$preset = .furniture
                }
            ),
            
            // MARK: - Data Management
            
            AppShortcut(
                intent: CreateCSVBackupIntent(),
                phrases: [
                    "Export inventory from \(.applicationName)",
                    "Create backup of inventory",
                    "Export my items",
                    "Backup inventory data"
                ],
                shortTitle: "Export Data",
                systemImageName: "square.and.arrow.up.fill"
            ),
            
            // MARK: - Item Management
            
            AppShortcut(
                intent: GetInventoryItemIntent(),
                phrases: [
                    "Get item details from \(.applicationName)",
                    "Show item information",
                    "Get inventory details",
                    "Item information"
                ],
                shortTitle: "Item Details",
                systemImageName: "info.circle.fill"
            ),
            
            AppShortcut(
                intent: UpdateInventoryItemIntent(),
                phrases: [
                    "Update item in \(.applicationName)",
                    "Change item details",
                    "Modify inventory item",
                    "Update item information"
                ],
                shortTitle: "Update Item",
                systemImageName: "pencil.circle.fill"
            ),
            
            // MARK: - Advanced Search
            
            AppShortcut(
                intent: SearchInventoryItemsIntent(),
                phrases: [
                    "Search kitchen items",
                    "Find items in kitchen",
                    "Kitchen inventory"
                ],
                shortTitle: "Search Kitchen",
                systemImageName: "fork.knife",
                parameterSummary: ParameterSummary("Search for \(\.$searchQuery)") {
                    \SearchInventoryItemsIntent.$searchQuery = "kitchen"
                }
            ),
            
            AppShortcut(
                intent: SearchInventoryItemsIntent(),
                phrases: [
                    "Search electronics",
                    "Find electronic items", 
                    "Electronics inventory"
                ],
                shortTitle: "Search Electronics",
                systemImageName: "tv.fill",
                parameterSummary: ParameterSummary("Search for \(\.$searchQuery)") {
                    \SearchInventoryItemsIntent.$searchQuery = "electronics"
                }
            )
        ]
    }
    
    static var shortcutTileColor: ShortcutTileColor {
        .blue
    }
}

// MARK: - App Shortcuts Donation Manager

@available(iOS 16.0, *)
@MainActor
class ShortcutDonationManager: ObservableObject {
    
    /// Donate a shortcut after user successfully completes an action
    static func donateCreateItemShortcut() {
        let intent = CreateInventoryItemIntent()
        intent.title = "Sample Item"
        intent.quantity = "1"
        
        let shortcut = AppShortcut(
            intent: intent,
            phrases: ["Add item to MovingBox"],
            shortTitle: "Add Item",
            systemImageName: "plus.circle.fill"
        )
        
        // In iOS 16+, shortcuts are automatically donated when intents are executed
        // Additional custom donation logic can be added here if needed
    }
    
    /// Donate photo-based shortcut after successful photo analysis
    static func donatePhotoShortcut() {
        let intent = CreateItemFromPhotoIntent()
        intent.takePhoto = false
        
        let shortcut = AppShortcut(
            intent: intent,
            phrases: ["Scan item with MovingBox"],
            shortTitle: "Scan Item",
            systemImageName: "camera.viewfinder"
        )
        
        // Auto-donated on execution
    }
    
    /// Donate search shortcut after user searches
    static func donateSearchShortcut(for query: String) {
        let intent = SearchInventoryItemsIntent()
        intent.searchQuery = query
        
        let shortcut = AppShortcut(
            intent: intent,
            phrases: ["Search \(query) in MovingBox"],
            shortTitle: "Search \(query)",
            systemImageName: "magnifyingglass"
        )
        
        // Auto-donated on execution
    }
    
    /// Donate export shortcut after successful export
    static func donateExportShortcut() {
        let intent = CreateCSVBackupIntent()
        intent.includePhotos = false
        
        let shortcut = AppShortcut(
            intent: intent,
            phrases: ["Export MovingBox inventory"],
            shortTitle: "Export Data",
            systemImageName: "square.and.arrow.up.fill"
        )
        
        // Auto-donated on execution
    }
    
    /// Donate camera shortcut for specific presets
    static func donateCameraShortcut(for preset: CameraPreset) {
        let intent = QuickCameraIntent()
        intent.preset = preset
        
        let shortcut = AppShortcut(
            intent: intent,
            phrases: ["Quick camera for \(preset.rawValue.lowercased())"],
            shortTitle: "\(preset.rawValue) Camera",
            systemImageName: preset.caseDisplayRepresentations[preset]?.image?.systemName ?? "camera.fill"
        )
        
        // Auto-donated on execution
    }
}

// MARK: - Intent Configuration Extensions

@available(iOS 16.0, *)
extension CreateInventoryItemIntent {
    /// Create a pre-configured intent for common scenarios
    static func withPreset(title: String, location: String? = nil, label: String? = nil) -> CreateInventoryItemIntent {
        let intent = CreateInventoryItemIntent()
        intent.title = title
        intent.quantity = "1"
        // Note: In full implementation, would need to resolve location/label entities
        return intent
    }
}

@available(iOS 16.0, *)
extension SearchInventoryItemsIntent {
    /// Create a pre-configured search intent
    static func forCategory(_ category: String) -> SearchInventoryItemsIntent {
        let intent = SearchInventoryItemsIntent()
        intent.searchQuery = category
        intent.maxResults = 10
        return intent
    }
}

@available(iOS 16.0, *)
extension CreateCSVBackupIntent {
    /// Create a pre-configured backup intent
    static func quickBackup(includePhotos: Bool = false) -> CreateCSVBackupIntent {
        let intent = CreateCSVBackupIntent()
        intent.includePhotos = includePhotos
        return intent
    }
}