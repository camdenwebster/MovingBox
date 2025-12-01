//
//  Router.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI
import SwiftData

final class Router: ObservableObject {

    enum SidebarDestination: Hashable, Identifiable {
        case dashboard
        case allInventory
        case label(PersistentIdentifier)
        case location(PersistentIdentifier)

        var id: String {
            switch self {
            case .dashboard:
                return "dashboard"
            case .allInventory:
                return "allInventory"
            case .label(let id):
                return "label-\(id.hashValue)"
            case .location(let id):
                return "location-\(id.hashValue)"
            }
        }
    }

    enum Destination: Hashable {
        case dashboardView
        case locationsListView
        case settingsView
        case inventoryListView(location: InventoryLocation?)
        case editLocationView(location: InventoryLocation?, isEditing: Bool = false)
        case locationsSettingsView
        case editLabelView(label: InventoryLabel?, isEditing: Bool = false)
        case inventoryDetailView(item: InventoryItem, showSparklesButton: Bool = false, isEditing: Bool = false)
        case aISettingsView
        case addInventoryItemView(location: InventoryLocation?)
        case subscriptionSettingsView
        case syncDataSettingsView
        case importDataView
        case exportDataView
        case deleteDataView
    }

    @Published var navigationPath = NavigationPath()
    @Published var sidebarSelection: SidebarDestination? = .dashboard
    
    func navigate(to destination: Destination) {
        navigationPath.append(destination)
    }
    
    func navigate(to destination: String) {
        navigationPath.append(destination)
    }
    
    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func navigateToRoot() {
        navigationPath = NavigationPath()
    }
}
