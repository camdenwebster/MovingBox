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
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var containerManager = ModelContainerManager.shared
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var showOnboarding = false
    
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
    
    init() {
        Self.registerTransformers()
        
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
    
    private var disableAnimations: Bool {
        ProcessInfo.processInfo.arguments.contains("Disable-Animations")
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
            .environment(\.disableAnimations, disableAnimations)
            .task {
                // Initialize container
                await containerManager.initialize()
                
                // Check RevenueCat subscription status
                do {
                    try await revenueCatManager.updateCustomerInfo()
                } catch {
                    print("⚠️ MovingBoxApp - Error checking RevenueCat status: \(error)")
                }
                
                // Load Test Data if launch argument is set
                if ProcessInfo.processInfo.arguments.contains("Use-Test-Data") {
                    Task {
                        await DefaultDataManager.populateTestData(modelContext: containerManager.container.mainContext)
                        settings.hasLaunched = true
                    }
                }

                // Reset paywall state if launch agrument is set
                if ProcessInfo.processInfo.arguments.contains("reset-paywall-state") {
                    settings.hasSeenPaywall = false
                }

                // Determine if we should show the welcome screen
                let shouldShowWelcome = OnboardingManager.shouldShowWelcome()
                if shouldShowWelcome {
                    showOnboarding = true
                }
                
                // Record that we've launched
                settings.hasLaunched = true

                // Send launched signal to TD
                TelemetryDeck.signal("appLaunched")
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
                    .environment(\.disableAnimations, disableAnimations)
            }
            .modelContainer(containerManager.container)
            .environmentObject(router)
            .environmentObject(settings)
            .environmentObject(containerManager)
            .environmentObject(onboardingManager)
            .environmentObject(revenueCatManager)
        }
    }
}
