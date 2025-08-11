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
        
        // Configure RevenueCat
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        
        // Configure Sentry with improved error handling
        do {
            let dsn = "https://\(AppConfig.sentryDsn)"
            guard dsn != "missing-sentry-dsn" else {
                #if DEBUG
                print("⚠️ Error: Missing Sentry DSN configuration")
                #endif
                return
            }
            
            SentrySDK.start { options in
                options.dsn = dsn
//                options.debug = AppConfig.shared.configuration == .debug
                options.tracesSampleRate = 0.2
                
                options.configureProfiling = {
                    $0.sessionSampleRate = 0.3
                    $0.lifecycle = .trace
                }
                
                options.sessionReplay.onErrorSampleRate = 0.8
                options.sessionReplay.sessionSampleRate = 0.1
            }
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
                case .addInventoryItemView(let location):
                    AddInventoryItemView(location: location)
                case .locationsSettingsView:
                    LocationSettingsView()
                case .subscriptionSettingsView:
                    SubscriptionSettingsView()
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
                await containerManager.initialize()
                
                // Check RevenueCat subscription status
                do {
                    try await revenueCatManager.updateCustomerInfo()
                } catch {
                    print("⚠️ MovingBoxApp - Error checking RevenueCat status: \(error)")
                }
                
                // Load Test Data if launch argument is set
                if ProcessInfo.processInfo.arguments.contains("Use-Test-Data") {
                    await DefaultDataManager.populateTestData(modelContext: containerManager.container.mainContext)
                    settings.hasLaunched = true
                    appState = .main
                } else {
                    // Determine if we should show the welcome screen
                    appState = OnboardingManager.shouldShowWelcome() ? .onboarding : .main
                }
                
                // Record that we've launched
                settings.hasLaunched = true

                // Send launched signal to TD
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
        colorScheme == .dark ? .splashTextDark : .splashTextLight
    }
    
    var body: some View {
        ZStack {
            Image(backgroundImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if let appIcon = Bundle.main.icon {
                    Image(uiImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                VStack {
                    Text("MovingBox")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                    Text("Home inventory, simplified")
                        .fontWeight(.light)
                        .foregroundColor(textColor)
                }
            }
        }
    }
}

extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
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
                Label("Home", systemImage: "house")
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
                AddInventoryItemView(location: nil)
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
