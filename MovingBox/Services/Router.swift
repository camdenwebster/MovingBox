//
//  Router.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftData
import SwiftUI

final class Router: ObservableObject {

    enum SidebarDestination: Hashable, Identifiable {
        case dashboard
        case home(PersistentIdentifier)
        case allInventory
        case label(PersistentIdentifier)
        case location(PersistentIdentifier)

        var id: String {
            switch self {
            case .dashboard:
                return "dashboard"
            case .home(let id):
                return "home-\(id.hashValue)"
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
        case locationsListView(showAllHomes: Bool = false)
        case labelsListView(showAllHomes: Bool = false)
        case settingsView
        case inventoryListView(location: InventoryLocation?, showAllHomes: Bool = false)
        case inventoryListViewForLabel(label: InventoryLabel)
        case editLocationView(location: InventoryLocation?, isEditing: Bool = false)
        case locationsSettingsView
        case editLabelView(label: InventoryLabel?, isEditing: Bool = false)
        case inventoryDetailView(
            item: InventoryItem, showSparklesButton: Bool = false, isEditing: Bool = false)
        case aISettingsView
        case subscriptionSettingsView
        case syncDataSettingsView
        case importDataView
        case exportDataView
        case deleteDataView
        case homeListView
        case addHomeView
        case aboutView
        case featureRequestView
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
