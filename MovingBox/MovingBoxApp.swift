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
    @StateObject var allItemsRouter = Router()
    @StateObject var settingsRouter = Router()
    
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
                
                NavigationStack(path: $allItemsRouter.path) {
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
                                EditInventoryItemView(inventoryItemToDisplay: item, navigationPath: $allItemsRouter.path)
                            }
                        }
                }
                .environmentObject(allItemsRouter)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("All Items")
                }
                
                NavigationStack(path: $settingsRouter.path){
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
                                EditInventoryItemView(inventoryItemToDisplay: item, navigationPath: $settingsRouter.path)
                            }
                        }
                }
                .environmentObject(settingsRouter)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
            }
        }
        .modelContainer(for: InventoryItem.self)
    }
}
