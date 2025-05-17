//
//  Router.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI
import SwiftData
import UIKit

final class Router: ObservableObject {

    enum Tab: Int {
        case dashboard = 0
        case locations = 1
        case addItem = 2
        case allItems = 3
        case settings = 4
        
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .locations: return "Locations"
            case .addItem: return "Add Item"
            case .allItems: return "All Items"
            case .settings: return "Settings"
            }
        }
        
        var iconName: String {
            switch self {
            case .dashboard: return "gauge.with.dots.needle.33percent"
            case .locations: return "map"
            case .addItem: return "camera.viewfinder"
            case .allItems: return "list.bullet"
            case .settings: return "gearshape"
            }
        }
    }
    
    enum Destination: Hashable {
        case dashboardView
        case locationsListView
        case settingsView
        case inventoryListView(location: InventoryLocation)
        case editLocationView(location: InventoryLocation?, isEditing: Bool = false)
        case locationsSettingsView
        case editLabelView(label: InventoryLabel?, isEditing: Bool = false)
        case inventoryDetailView(item: InventoryItem, showSparklesButton: Bool = false, isEditing: Bool = false)
        case aISettingsView
        case addItemView(location: InventoryLocation?)
        case subscriptionSettingsView
        case itemCreationFlow(location: InventoryLocation?, initialImages: [UIImage])
        
        // Note: Passing large data like images directly in NavigationPath is not ideal.
        // A better approach would be to save images first and pass URLs/IDs,
        // but for this step, we'll pass UIImage array for simplicity with existing flow structure.
        // Let's create a wrapper struct for [UIImage] to make it Hashable.
        private struct ImageArrayWrapper: Hashable {
            let images: [UIImage]
            
            // Simple hash implementation for images (based on count, not content)
            // WARNING: This is not a robust hash for image content.
            // For robust hashing, you'd need to hash image data, which is complex.
            // This is sufficient for NavigationPath's needs in this context.
            func hash(into hasher: inout Hasher) {
                hasher.combine(images.count)
                // Optionally combine hashes of image sizes or data snippets if needed
                // for a more unique hash, but can be slow for large arrays.
            }
            
            static func == (lhs: ImageArrayWrapper, rhs: ImageArrayWrapper) -> Bool {
                // Simple equality check based on count and maybe sizes
                guard lhs.images.count == rhs.images.count else { return false }
                // For a real app, a deeper comparison might be needed based on image data/content.
                // For NavigationPath, this might be sufficient.
                return true // Assuming same count is "equal enough" for navigation state
            }
        }
    }
    
    @Published var selectedTab: Tab = .dashboard
    @Published var navigationPaths: [Tab: NavigationPath] = [
        .dashboard: NavigationPath(),
        .locations: NavigationPath(),
        .addItem: NavigationPath(),
        .allItems: NavigationPath(),
        .settings: NavigationPath()
    ]
    
    func navigate(to destination: Destination) {
        navigationPaths[selectedTab]?.append(destination)
    }
    
    func navigateBack() {
        navigationPaths[selectedTab]?.removeLast()
    }
    
    func navigateToRoot() {
        navigationPaths[selectedTab] = NavigationPath()
    }
    
    func path(for tab: Tab) -> Binding<NavigationPath> {
        Binding(
            get: { self.navigationPaths[tab] ?? NavigationPath() },
            set: { self.navigationPaths[tab] = $0 }
        )
    }
}
