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
    @StateObject private var settings = SettingsManager()
    
    init() {
        ValueTransformer.setValueTransformer(UIColorValueTransformer(), forName: NSValueTransformerName("UIColorValueTransformer"))
    }
    
    @ViewBuilder
    private func destinationView(for destination: Router.Destination, navigationPath: Binding<NavigationPath>) -> some View {
        switch destination {
        case .dashboardView:
            DashboardView()
        case .locationsListView:
            LocationsListView()
        case .settingsView:
            SettingsView()
        case .aISettingsView:
            AISettingsView(settings: settings)
        case .inventoryListView(let location):
            InventoryListView(location: location)
        case .editLocationView(let location):
            EditLocationView(location: location)
        case .editLabelView(let label):
            EditLabelView(label: label)
        case .editInventoryItemView(let item):
            EditInventoryItemView(inventoryItemToDisplay: item, navigationPath: navigationPath)
        }
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
                            destinationView(for: destination, navigationPath: $allItemsRouter.path)
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
                            destinationView(for: destination, navigationPath: $settingsRouter.path)
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
