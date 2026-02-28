//
//  Router.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import Foundation
import SwiftUI

final class Router: ObservableObject {

    enum SidebarDestination: Hashable, Identifiable {
        case dashboard
        case home(UUID)
        case allInventory
        case label(UUID)
        case location(UUID)

        var id: String {
            switch self {
            case .dashboard:
                return "dashboard"
            case .home(let id):
                return "home-\(id.uuidString)"
            case .allInventory:
                return "allInventory"
            case .label(let id):
                return "label-\(id.uuidString)"
            case .location(let id):
                return "location-\(id.uuidString)"
            }
        }
    }

    enum Destination: Hashable {
        case dashboardView
        case locationsListView(showAllHomes: Bool = false)
        case labelsListView(showAllHomes: Bool = false)
        case settingsView
        case inventoryListView(locationID: UUID?, showAllHomes: Bool = false)
        case inventoryListViewForLabel(labelID: UUID)
        case editLocationView(locationID: UUID?, isEditing: Bool = false)
        case locationsSettingsView
        case editLabelView(labelID: UUID?, isEditing: Bool = false)
        case inventoryDetailView(
            itemID: UUID, showSparklesButton: Bool = false, isEditing: Bool = false)
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
        case globalLabelSettingsView
        case insurancePolicyListView
        case insurancePolicyDetailView(policyID: UUID?)
        case familySharingSettingsView
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
