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
    @Query(sort: [SortDescriptor(\InventoryLocation.name)]) private var locations: [InventoryLocation]
    
    enum TabDestination: Hashable {
        case dashboard
        case locations
        case addItem
        case allItems
        case settings
        case location(PersistentIdentifier)
        
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .locations: return "Locations"
            case .addItem: return "Add Item"
            case .allItems: return "All Items"
            case .settings: return "Settings"
            case .location: return "Location"
            }
        }
    }
    
    @State private var selectedTab = 0
    
    static func registerTransformers() {
        UIColorValueTransformer.register()
    }
    
    let container: ModelContainer = {
        Self.registerTransformers()
        
        let schema = Schema([
            InventoryLabel.self,
            InventoryItem.self,
            InventoryLocation.self,
            InsurancePolicy.self,
            Home.self
        ])
        
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-Testing")
        
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
        let config = TelemetryDeck.Config(appID: "763EF9C7-E47D-453D-A2CD-C0DA44BD3155")
        config.defaultSignalPrefix = "App."
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
        case .editInventoryItemView(let item, let showSparklesButton, let isEditing):
            EditInventoryItemView(inventoryItemToDisplay: item, navigationPath: navigationPath, showSparklesButton: showSparklesButton, isEditing: isEditing)
        case .addInventoryItemView(let location):
            AddInventoryItemView(location: location)
        case .locationsSettingsView:
            LocationSettingsView()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                Tab("Dashboard", systemImage: "gauge.with.dots.needle.33percent", value: 0) {
                    NavigationStack(path: $allItemsRouter.path) {
                        DashboardView()
                            .navigationDestination(for: Router.Destination.self) { destination in
                                destinationView(for: destination, navigationPath: $allItemsRouter.path)
                            }
                    }
                    .environmentObject(allItemsRouter)
                }
                
                Tab("Locations", systemImage: "map", value: 1) {
                    NavigationStack(path: $locationsRouter.path) {
                        LocationsListView()
                            .navigationDestination(for: Router.Destination.self) { destination in
                                destinationView(for: destination, navigationPath: $locationsRouter.path)
                            }
                    }
                    .environmentObject(locationsRouter)
                }
                
                Tab("Add Item", systemImage: "camera.viewfinder", value: 2) {
                    NavigationStack(path: $allItemsRouter.path) {
                        AddInventoryItemView(location: nil)
                            .navigationDestination(for: Router.Destination.self) { destination in
                                destinationView(for: destination, navigationPath: $allItemsRouter.path)
                            }
                    }
                    .environmentObject(allItemsRouter)
                }
                
                Tab("All Items", systemImage: "list.bullet", value: 3) {
                    NavigationStack(path: $allItemsRouter.path) {
                        InventoryListView(location: nil)
                            .navigationDestination(for: Router.Destination.self) { destination in
                                destinationView(for: destination, navigationPath: $allItemsRouter.path)
                            }
                    }
                    .environmentObject(allItemsRouter)
                }
                
                Tab("Settings", systemImage: "gearshape", value: 4) {
                    NavigationStack(path: $settingsRouter.path) {
                        SettingsView()
                            .navigationDestination(for: Router.Destination.self) { destination in
                                destinationView(for: destination, navigationPath: $settingsRouter.path)
                            }
                    }
                    .environmentObject(settingsRouter)
                }
            }
            .tabViewStyle(.sidebarAdaptable)
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
                    Task {
                        await DefaultDataManager.populateTestData(modelContext: container.mainContext)
                        settings.hasLaunched = true
                    }
                } else if !settings.hasLaunched {
                    Task {
                        await DefaultDataManager.populateDefaultData(modelContext: container.mainContext)
                        settings.hasLaunched = true
                    }
                }
                
                TelemetryDeck.signal("appLaunched")
            }
        }
        .modelContainer(container)
    }
}
