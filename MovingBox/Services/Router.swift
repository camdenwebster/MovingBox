//
//  Router.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

final class Router: ObservableObject {
    
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
        case subscriptionSettingsView
        case syncDataSettingsView
        case importDataView
        case exportDataView
        case deleteDataView
        case aboutView
        case featureRequestView
    }
    
    @Published var navigationPath = NavigationPath()
    
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
