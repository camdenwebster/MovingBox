//
//  MovingBoxApp.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import SwiftData
import SwiftUI
import UIKit
import TelemetryDeck

@main
struct MovingBoxApp: App {
    @StateObject var locationsRouter = Router()
    @StateObject var allItemsRouter = Router()
    @StateObject var settingsRouter = Router()
    @StateObject private var settings = SettingsManager()
    @State private var selectedTab = 0
    
    static func registerTransformers() {
        UIColorValueTransformer.register()
    }
    
    let container: ModelContainer = {
        Self.registerTransformers()
        
        // Update schema to include all models in dependency order
        let schema = Schema([
            InventoryLabel.self,
            InventoryItem.self,
            InventoryLocation.self,
            InsurancePolicy.self,
            Home.self
        ])
        
        // Get UI testing argument
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-Testing")
        
        // Configure storage based on UI testing flag
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        // Initialize TelemetryDeck
        let config = TelemetryDeck.Config(appID: "763EF9C7-E47D-453D-A2CD-C0DA44BD3155")
        // Add a prefix to all signal names
        config.defaultSignalPrefix = "App."
        // Add a prefix to all parameter names
        config.defaultParameterPrefix = "MyApp."
        TelemetryDeck.initialize(config: config)
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
        case .editInventoryItemView(let item, let showSparklesButton):
            EditInventoryItemView(inventoryItemToDisplay: item, navigationPath: navigationPath, showSparklesButton: showSparklesButton)
        case .addInventoryItemView(let location):
            AddInventoryItemView(location: location)
        case .locationsSettingsView:
            LocationSettingsView()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Image(systemName: "gauge.with.dots.needle.33percent")
                        Text("Dashboard")
                    }
                    .tag(0)
                
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
                .tag(1)
                
                NavigationStack(path: $allItemsRouter.path) {
                    AddInventoryItemView(location: nil)
                        .navigationDestination(for: Router.Destination.self) { destination in
                            destinationView(for: destination, navigationPath: $allItemsRouter.path)
                        }
                }
                .environmentObject(allItemsRouter)
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Add Item")
                }
                .tag(2)
                
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
                .tag(3)
                             
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
                .tag(4)
            }
            .tint(Color.customPrimary)
            .onChange(of: selectedTab) { oldValue, newValue in
                let tabName: String = {
                switch newValue {
                case 0: return "dashboard"
                case 1: return "locations"
                case 2: return "add_item"
                case 3: return "all_items"
                case 4: return "settings"
                default: return "unknown"
                }
                }()
                TelemetryManager.shared.trackTabSelected(tab: tabName)
            }
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
                    // Load all test data for UI testing
                    Task {
                        await DefaultDataManager.populateTestData(modelContext: container.mainContext)
                        settings.hasLaunched = true
                    }
                } else if !settings.hasLaunched {
                    // Load default labels and create default home for production first launch
                    Task {
                        await DefaultDataManager.populateDefaultData(modelContext: container.mainContext)
                        settings.hasLaunched = true
                    }
                }
                
                // Send app launch signal
                TelemetryDeck.signal("appLaunched")
            }
        }
        .modelContainer(container)
    }
}
