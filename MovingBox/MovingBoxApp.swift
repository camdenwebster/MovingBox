//
//  MovingBoxApp.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import SwiftData
import SwiftUI
import UIKit

@main
struct MovingBoxApp: App {
    @StateObject var locationsRouter = Router()
    @StateObject var allItemsRouter = Router()
    @StateObject var settingsRouter = Router()
    @StateObject private var settings = SettingsManager()
    
    static func registerTransformers() {
        UIColorValueTransformer.register()
    }
    
    let container: ModelContainer = {
        Self.registerTransformers()
        
        let schema = Schema([InventoryItem.self, InventoryLabel.self])
        let modelConfiguration = ModelConfiguration(schema: schema)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

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
        case .editInventoryItemView(let item, let showSparklesButton):
            EditInventoryItemView(inventoryItemToDisplay: item, navigationPath: navigationPath, showSparklesButton: showSparklesButton)
        case .addInventoryItemView:
            AddInventoryItemView()
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
                
                NavigationStack(path: $locationsRouter.path) {
                    LocationsListView()
                        .navigationDestination(for: Router.Destination.self) { destination in
                            destinationView(for: destination, navigationPath: $locationsRouter.path)
                        }
                }
                .environmentObject(locationsRouter)
                .tabItem {
                    Image(systemName: "map")
                    Text("Locations")
                }
                
                NavigationStack(path: $allItemsRouter.path) {
                    AddInventoryItemView()
                        .navigationDestination(for: Router.Destination.self) { destination in
                            destinationView(for: destination, navigationPath: $allItemsRouter.path)
                        }
                }
                .environmentObject(allItemsRouter)
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Item")
                }
                
                NavigationStack(path: $allItemsRouter.path) {
                    InventoryListView(location: nil)
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
            // Move onAppear here
            .onAppear {
                DefaultDataManager.populateInitialData(modelContext: container.mainContext)
            }
        }
        .modelContainer(container)
    }
}
