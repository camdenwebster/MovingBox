//
//  Router.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

final class Router: ObservableObject {
    
    public enum Destination: Hashable {
        case dashboardView
        case locationsListView
        case settingsView
        case inventoryListView(location: InventoryLocation)
        case editLocationView(location: InventoryLocation)
        case editLabelView(label: InventoryLabel)
        case editInventoryItemView(item: InventoryItem)
    }
    
    @Published var path = NavigationPath()
    
    func navigate(to destination: Destination) {
        print("Navigating to a new destination")
        path.append(destination)
    }
    
    func navigateBack() {
        path.removeLast()
    }
    
    func navigateToRoot() {
        path.removeLast(path.count)
    }
}
