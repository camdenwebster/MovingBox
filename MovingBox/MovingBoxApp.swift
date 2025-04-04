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
import RevenueCat

@main
struct MovingBoxApp: App {
    @StateObject var router = Router()
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
        // Configure TelemetryDeck
        let telemetryConfig = TelemetryDeck.Config(appID: "763EF9C7-E47D-453D-A2CD-C0DA44BD3155")
        telemetryConfig.defaultSignalPrefix = "App."
        telemetryConfig.defaultParameterPrefix = "MyApp."
        TelemetryDeck.initialize(config: telemetryConfig)
        
        // Configure RevenueCat with API key from config
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
    }
    
    @ViewBuilder
    private func destinationView(for destination: Router.Destination, navigationPath: Binding<NavigationPath>) -> some View {
        switch destination {
        case .dashboardView:
            DashboardView()
                .presentPaywallIfNeeded(
                    requiredEntitlementIdentifier: "Pro",
                    purchaseCompleted: { customerInfo in
                        print("Purchase completed: \(customerInfo.entitlements)")
                    },
                    restoreCompleted: { customerInfo in
                        // Paywall will be dismissed automatically if "pro" is now active.
                        print("Purchases restored: \(customerInfo.entitlements)")
                    }
                )
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
        case .inventoryDetailView(let item, let showSparklesButton, let isEditing):
            InventoryDetailView(inventoryItemToDisplay: item, navigationPath: navigationPath, showSparklesButton: showSparklesButton, isEditing: isEditing)
        case .addInventoryItemView(let location):
            AddInventoryItemView(location: location)
        case .locationsSettingsView:
            LocationSettingsView()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $router.selectedTab) {
                NavigationStack(path: router.path(for: .dashboard)) {
                    DashboardView()
                        .navigationDestination(for: Router.Destination.self) { destination in
                            destinationView(for: destination, navigationPath: router.path(for: .dashboard))
                        }
                }
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.33percent")
                }
                .tag(Router.Tab.dashboard)
                
                NavigationStack(path: router.path(for: .locations)) {
                    LocationsListView()
                        .navigationDestination(for: Router.Destination.self) { destination in
                            destinationView(for: destination, navigationPath: router.path(for: .locations))
                        }
                }
                .tabItem {
                    Label("Locations", systemImage: "map")
                }
                .tag(Router.Tab.locations)
                
                NavigationStack(path: router.path(for: .addItem)) {
                    AddInventoryItemView(location: nil)
                        .navigationDestination(for: Router.Destination.self) { destination in
                            destinationView(for: destination, navigationPath: router.path(for: .addItem))
                        }
                }
                .tabItem {
                    Label("Add Item", systemImage: "camera.viewfinder")
                }
                .tag(Router.Tab.addItem)
                
                NavigationStack(path: router.path(for: .allItems)) {
                    InventoryListView(location: nil)
                        .navigationDestination(for: Router.Destination.self) { destination in
                            destinationView(for: destination, navigationPath: router.path(for: .allItems))
                        }
                }
                .tabItem {
                    Label("All Items", systemImage: "list.bullet")
                }
                .tag(Router.Tab.allItems)
                
                NavigationStack(path: router.path(for: .settings)) {
                    SettingsView()
                        .navigationDestination(for: Router.Destination.self) { destination in
                            destinationView(for: destination, navigationPath: router.path(for: .settings))
                        }
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Router.Tab.settings)
            }
            .tabViewStyle(.sidebarAdaptable)
            .tint(Color.customPrimary)
            .onChange(of: router.selectedTab) { oldValue, newValue in
                let tabName: String = {
                    switch newValue {
                    case .dashboard: return "dashboard"
                    case .locations: return "locations"
                    case .addItem: return "add_item"
                    case .allItems: return "all_items"
                    case .settings: return "settings"
                    }
                }()
                TelemetryManager.shared.trackTabSelected(tab: tabName)
            }
            .onAppear {
                // Reset paywall state if testing
                if ProcessInfo.processInfo.arguments.contains("reset-paywall-state") {
                    let defaults = UserDefaults.standard
                    defaults.removeObject(forKey: "hasSeenPaywall")
                    defaults.synchronize()
                }

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
        .environmentObject(router)
        .environmentObject(settings)
    }
}
