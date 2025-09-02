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
        // TODO: Fix Sentry SDK API compatibility issue
        /*
        let dsn = "https://\(AppConfig.sentryDsn)"
        guard dsn != "missing-sentry-dsn" else {
            #if DEBUG
            print("⚠️ Error: Missing Sentry DSN configuration")
            #endif
            return
        }
        
        SentrySDK.start(options: { options in
            options.dsn = dsn
//            options.debug = AppConfig.shared.configuration == .debug
            options.tracesSampleRate = 0.2
            
            #if canImport(SentryProfilingConditional)
            options.profilesSampleRate = 0.3
            #endif
            
            options.experimental.sessionReplay.onErrorSampleRate = 0.8
            options.experimental.sessionReplay.sessionSampleRate = 0.1
        })
        */
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
                    AISettingsView()
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
                case .syncDataSettingsView:
                    SyncDataSettingsView()
                case .importDataView:
                    ImportDataView()
                case .exportDataView:
                    ExportDataView()
                case .deleteDataView:
                    DataDeletionView()
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
                    NavigationStack(path: $router.navigationPath) {
                        DashboardView()
                            .navigationDestination(for: Router.Destination.self) { destination in
                                destinationView(for: destination, navigationPath: $router.navigationPath)
                            }
                            .navigationDestination(for: String.self) { destination in
                                Group {
                                    switch destination {
                                    case "appearance":
                                        AppearanceSettingsView()
                                    case "notifications":
                                        NotificationSettingsView()
                                    case "ai":
                                        AISettingsView()
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
                    }
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
                    await TestData.loadTestData(modelContext: containerManager.container.mainContext)
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

