//
//  MovingBoxApp.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import RevenueCat
import Sentry
import SwiftData
import SwiftUI
import TelemetryDeck
import UIKit
import os.log

@main
struct MovingBoxApp: App {
    @StateObject var router = Router()
    @StateObject private var settings = SettingsManager()
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var containerManager = ModelContainerManager.shared
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var appState: AppState = .splash
    
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
    
    private enum AppState {
        case splash
        case onboarding
        case main
    }
    
    static func registerTransformers() {
        UIColorValueTransformer.register()
    }
    
    init() {
        Self.registerTransformers()
        
        // Configure TelemetryDeck
        let appId = AppConfig.telemetryDeckAppId
        let telemetryConfig = TelemetryDeck.Config(appID: appId)
        telemetryConfig.defaultSignalPrefix = "App."
        telemetryConfig.defaultParameterPrefix = "MyApp."
        TelemetryDeck.initialize(config: telemetryConfig)
        Logger.info("TelemetryDeck initialized with app ID: \(appId)", category: .analytics)
        
        // Configure RevenueCat
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        Logger.info("RevenueCat configured with API key", category: .subscription)
        
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        
        // Configure Sentry with improved error handling
        do {
            let dsn = "https://\(AppConfig.sentryDsn)"
            guard dsn != "missing-sentry-dsn" else {
                Logger.warning("Missing Sentry DSN configuration", category: .app)
                return
            }
            
            SentrySDK.start { options in
                options.dsn = dsn
                options.tracesSampleRate = 0.2
                
                options.configureProfiling = {
                    $0.sessionSampleRate = 0.3
                    $0.lifecycle = .trace
                }
                
                options.sessionReplay.onErrorSampleRate = 0.8
                options.sessionReplay.sessionSampleRate = 0.1
            }
            Logger.info("Sentry initialized successfully", category: .app)
        }
    }
    
    private var disableAnimations: Bool {
        ProcessInfo.processInfo.arguments.contains("Disable-Animations")
    }
    
    private func destinationView(for destination: Router.Destination, navigationPath: Binding<NavigationPath>) -> AnyView {
        AnyView(
            Group {
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
                case .editLocationView(let location, let isEditing):
                    EditLocationView(location: location, isEditing: isEditing)
                case .editLabelView(let label, let isEditing):
                    EditLabelView(label: label, isEditing: isEditing)
                case .inventoryDetailView(let item, let showSparklesButton, let isEditing):
                    InventoryDetailView(inventoryItemToDisplay: item, navigationPath: navigationPath, showSparklesButton: showSparklesButton, isEditing: isEditing)
                case .addItemView(let location):
                    NewItemPhotoPickerView(location: location)
                case .subscriptionSettingsView:
                    SubscriptionSettingsView()
                case .locationsSettingsView:
                    Text("Locations Settings View Placeholder")
                        .navigationTitle("Location Settings")
                case .itemCreationFlow(let location, let initialImages):
                    ItemCreationFlowView(location: location, initialImages: initialImages) {
                        print("Item creation flow completed in MovingBoxApp")
                    }
                }
            }
        )
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch appState {
                case .splash:
                    SplashView()
                case .onboarding:
                    OnboardingView(isPresented: .init(
                        get: { appState == .onboarding },
                        set: { _ in appState = .main }
                    ))
                    .environment(\.disableAnimations, disableAnimations)
                case .main:
                    MainTabView(destinationView: destinationView)
                        .environment(\.disableAnimations, disableAnimations)
                }
            }
            .task {
                // Initialize container
                Logger.info("Initializing model container", category: .database)
                await containerManager.initialize()
                
                // Check RevenueCat subscription status
                do {
                    Logger.info("Checking RevenueCat subscription status", category: .subscription)
                    try await revenueCatManager.updateCustomerInfo()
                } catch {
                    Logger.error("Error checking RevenueCat status: \(error)", category: .subscription)
                }
                
                // Load Test Data if launch argument is set
                if ProcessInfo.processInfo.arguments.contains("Use-Test-Data") {
                    Logger.info("Loading test data due to launch argument", category: .database)
                    await DefaultDataManager.populateTestData(modelContext: containerManager.container.mainContext)
                    settings.hasLaunched = true
                    appState = .main
                } else {
                    // Determine if we should show the welcome screen
                    let shouldShowWelcome = OnboardingManager.shouldShowWelcome()
                    Logger.info("Should show welcome screen: \(shouldShowWelcome)", category: .ui)
                    appState = shouldShowWelcome ? .onboarding : .main
                }
                
                // Record that we've launched
                settings.hasLaunched = true

                // Send launched signal to TD
                Logger.info("Sending app launched telemetry signal", category: .analytics)
                TelemetryDeck.signal("appLaunched")
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

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundImage: String {
        colorScheme == .dark ? "background-dark" : "background-light"
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        ZStack {
            Image(backgroundImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            VStack {
                Image("MovingBox")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                ProgressView()
                    .tint(textColor)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var router: Router
    let destinationView: (Router.Destination, Binding<NavigationPath>) -> AnyView
    
    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: router.path(for: .dashboard)) {
                DashboardView()
                    .navigationDestination(for: Router.Destination.self) { destination in
                        destinationView(destination, router.path(for: .dashboard))
                    }
            }
            .tabItem {
                Label("Dashboard", systemImage: "gauge.with.dots.needle.33percent")
            }
            .tag(Router.Tab.dashboard)
            
            NavigationStack(path: router.path(for: .locations)) {
                LocationsListView()
                    .navigationDestination(for: Router.Destination.self) { destination in
                        destinationView(destination, router.path(for: .locations))
                    }
            }
            .tabItem {
                Label("Locations", systemImage: "map")
            }
            .tag(Router.Tab.locations)
            
            NavigationStack(path: router.path(for: .addItem)) {
                NewItemPhotoPickerView(location: nil)
                    .navigationDestination(for: Router.Destination.self) { destination in
                        destinationView(destination, router.path(for: .addItem))
                    }
            }
            .tabItem {
                Label("Add Item", systemImage: "camera.viewfinder")
            }
            .tag(Router.Tab.addItem)
            
            NavigationStack(path: router.path(for: .allItems)) {
                InventoryListView(location: nil)
                    .navigationDestination(for: Router.Destination.self) { destination in
                        destinationView(destination, router.path(for: .allItems))
                    }
            }
            .tabItem {
                Label("All Items", systemImage: "list.bullet")
            }
            .tag(Router.Tab.allItems)
            
            NavigationStack(path: router.path(for: .settings)) {
                SettingsView()
                    .navigationDestination(for: Router.Destination.self) { destination in
                        destinationView(destination, router.path(for: .settings))
                            .tint(Color.customPrimary)
                    }
                    .navigationDestination(for: String.self) { destination in
                        Group {
                            switch destination {
                            case "appearance":
                                AppearanceSettingsView()
                            case "notifications":
                                NotificationSettingsView()
                            case "ai":
                                AISettingsView(settings: SettingsManager())
                            case "locations":
                                LocationSettingsView()
                            case "labels":
                                LabelSettingsView()
                            case "home":
                                EditHomeView()
                            default:
                                EmptyView()
                            }
                        }
                        .tint(Color.customPrimary)
                    }
                    .tint(Color.customPrimary)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(Router.Tab.settings)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Color.customPrimary)
    }
}
