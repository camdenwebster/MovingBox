//
//  MovingBoxApp.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import SwiftData
import SwiftUI

@main
struct MovingBoxApp: App {
    @ObservedObject var router = Router()
    
    init() {
        ValueTransformer.setValueTransformer(UIColorValueTransformer(), forName: NSValueTransformerName("UIColorValueTransformer"))
    }
    
    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        Text("Dashboard")
                    }
                
                NavigationStack(path: $router.path) {
                    LocationsListView()
                        .navigationDestination(for: Router.Destination.self) { destination in
                            switch destination {
                            case .dashboardView:
                                DashboardView()
                            case .locationsListView:
                                LocationsListView()
                            case .settingsView:
                                SettingsView()
                            case .inventoryListView(let location):
                                InventoryListView(location: location)
                            case .editLocationView(let location):
                                EditLocationView(location: location)
                            case .editLabelView(let label):
                                EditLabelView(label: label)
                            case .editInventoryItemView(let item):
                                EditInventoryItemView(inventoryItemToDisplay: item, navigationPath: $router.path)
                            }
                        }
                }
                .environmentObject(router)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("All Items")
                }
                NavigationStack(path: $router.path){
                    SettingsView()
                        .navigationDestination(for: Router.Destination.self) { destination in
                            switch destination {
                            case .dashboardView:
                                DashboardView()
                            case .locationsListView:
                                LocationsListView()
                            case .settingsView:
                                SettingsView()
                            case .inventoryListView(let location):
                                InventoryListView(location: location)
                            case .editLocationView(let location):
                                EditLocationView(location: location)
                            case .editLabelView(let label):
                                EditLabelView(label: label)
                            case .editInventoryItemView(let item):
                                EditInventoryItemView(inventoryItemToDisplay: item, navigationPath: $router.path)
                            }
                        }
                }
                .environmentObject(router)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
            }
        }
        .modelContainer(for: InventoryItem.self)
    }
}
