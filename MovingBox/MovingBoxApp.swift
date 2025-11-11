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
        telemetryConfig.defaultSignalPrefix = "MovingBox."
        telemetryConfig.defaultParameterPrefix = "MovingBox."
        TelemetryDeck.initialize(config: telemetryConfig)
        
        // Configure RevenueCat
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        
        let dsn = "https://\(AppConfig.sentryDsn)"
        guard dsn != "https://missing-sentry-dsn" else {
            #if DEBUG
            print("⚠️ Error: Missing Sentry DSN configuration")
            #endif
            return
        }
        
        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = AppConfig.shared.configuration == .debug
            options.tracesSampleRate = 0.2
            
            options.configureProfiling = {
                $0.lifecycle = .trace
                $0.sessionSampleRate = 1
            }
            
            // Record session replays for 100% of errors and 10% of sessions
            options.sessionReplay.onErrorSampleRate = 1.0
            options.sessionReplay.sessionSampleRate = 0.1

            // Enable logs to be sent to Sentry
            options.experimental.enableLogs = true

            // Automatic iOS Instrumentation (most features enabled by default in v8+)
            // Only configure non-default settings:
            options.enablePreWarmedAppStartTracing = true  // Disabled by default, enable for iOS 15+
            options.enableTimeToFullDisplayTracing = true  // Disabled by default

            // Network Tracking - limit to OpenAI API only for privacy
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


