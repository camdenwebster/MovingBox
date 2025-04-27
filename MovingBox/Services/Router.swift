//
//  Router.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

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
        case addInventoryItemView(location: InventoryLocation?)
        case subscriptionSettingsView
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
