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
import WhatsNewKit
import WishKit

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
        telemetryConfig.defaultSignalPrefix = "MovingBox."
        telemetryConfig.defaultParameterPrefix = "MovingBox."
        TelemetryDeck.initialize(config: telemetryConfig)
        
        // Configure RevenueCat
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        
        // Configure WishKit
        WishKit.configure(with: AppConfig.wishKitAPIKey)
        
        let dsn = "https://\(AppConfig.sentryDsn)"
        guard dsn != "https://missing-sentry-dsn" else {
            #if DEBUG
            print("⚠️ Error: Missing Sentry DSN configuration")
            #endif
            return
        }
        
        SentrySDK.start { options in
            options.dsn = dsn

            // Debug mode configuration
            let isDebug = AppConfig.shared.configuration == .debug
            options.debug = isDebug
            
            // Detect if running in test environment
            let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

            // PERFORMANCE OPTIMIZATION: Reduce overhead in debug builds
            if isDebug {
                // Minimal tracing in debug mode to reduce overhead
                options.tracesSampleRate = 0.0
                options.profilesSampleRate = 0.0

                // Disable session replay in debug mode (high overhead)
                options.sessionReplay.onErrorSampleRate = 0.0
                options.sessionReplay.sessionSampleRate = 0.0

                // Disable experimental logs in debug (verbose)
                options.experimental.enableLogs = false

                // Disable automatic instrumentation in debug mode
                options.enableAutoPerformanceTracing = false
                options.enableCoreDataTracing = false
                options.enableFileIOTracing = false
                options.enableNetworkTracking = false
                options.enableSwizzling = false
                
                // Disable app hang tracking in debug
                options.enableAppHangTracking = false

                print("🐛 Sentry Debug Mode: Minimal tracking enabled to reduce overhead")
            } else {
                // Production/Beta configuration - full feature set
                options.tracesSampleRate = 0.2

                // Profiling configuration
                options.configureProfiling = {
                    $0.lifecycle = .trace
                    $0.sessionSampleRate = 0.2
                }

                // Session replays for errors and sampled sessions
                options.sessionReplay.onErrorSampleRate = 1.0
                options.sessionReplay.sessionSampleRate = 0.1

                // Enable logs in production
                options.experimental.enableLogs = true

                // Automatic iOS Instrumentation
                options.enableAutoPerformanceTracing = true
                options.enableCoreDataTracing = false
                options.enableFileIOTracing = false
                options.enableNetworkTracking = true
                options.enablePreWarmedAppStartTracing = true
                options.enableTimeToFullDisplayTracing = true
                
                // Disable app hang tracking during test execution to prevent false positives
                options.enableAppHangTracking = !isRunningTests
            }

            // Network Tracking - limit to OpenAI API only for privacy (all configs)
            options.tracePropagationTargets = ["api.aiproxy.com"]

            #if DEBUG
            options.environment = "debug"
            #else
            options.environment = AppConfig.shared.buildType == .beta ? "beta" : "production"
            #endif
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
                    AISettingsView()
                case .inventoryListView(let location):
                    InventoryListView(location: location)
                case .editLocationView(let location, let isEditing):
                    EditLocationView(location: location, isEditing: isEditing)
                case .editLabelView(let label, let isEditing):
                    EditLabelView(label: label, isEditing: isEditing)
                case .inventoryDetailView(let item, let showSparklesButton, let isEditing):
                    InventoryDetailView(inventoryItemToDisplay: item, navigationPath: navigationPath, showSparklesButton: showSparklesButton, isEditing: isEditing)
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
                case .aboutView:
                    AboutView()
                case .featureRequestView:
                    FeatureRequestView()
                case .homeListView:
                    HomeListView()
                case .addHomeView:
                    AddHomeView()
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
                    MainSplitView(navigationPath: $router.navigationPath)
                        .environment(\.disableAnimations, disableAnimations)
                }
            }
            #if os(macOS)
            .toolbar(removing: .title)
            #endif
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
                    print("📱 MovingBoxApp - Loading test data...")
                    await TestData.loadTestData(modelContext: containerManager.container.mainContext)
                    print("📱 MovingBoxApp - Test data loaded")
                    
                    // Run orphaned items migration after test data loads
                    // This ensures test data items/locations/labels are assigned to homes
                    // Force=true allows it to run even if already completed (for test data scenarios)
                    print("📱 MovingBoxApp - Running post-test-data migration...")
                    try? await containerManager.performOrphanedItemsMigration(force: true)
                    print("📱 MovingBoxApp - Post-test-data migration complete")
                    
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
            .environment(\.featureFlags, FeatureFlags(distribution: .current))
            .environment(\.whatsNew, .forMovingBox())
            .environmentObject(router)
            .environmentObject(settings)
            .environmentObject(containerManager)
            .environmentObject(onboardingManager)
            .environmentObject(revenueCatManager)
        }
    }
}


