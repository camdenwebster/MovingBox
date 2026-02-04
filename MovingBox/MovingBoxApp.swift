//
//  MovingBoxApp.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import Dependencies
import RevenueCat
import SQLiteData
import Sentry
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
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var appState: AppState = .loading
    @State private var splashShownAt: Date?

    private enum AppState {
        case loading
        case splash
        case onboarding
        case main
    }

    init() {
        // Prepare sqlite-data database (runs schema migrations)
        prepareDependencies {
            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("Use-Test-Data") {
                    $0.defaultDatabase = try! makeSeededTestDatabase()
                } else if ProcessInfo.processInfo.arguments.contains("Disable-Persistence") {
                    $0.defaultDatabase = try! makeInMemoryDatabase()
                } else {
                    $0.defaultDatabase = try! appDatabase()
                }
            #else
                $0.defaultDatabase = try! appDatabase()
            #endif
        }

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

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState {
                case .loading:
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                case .splash:
                    SplashView()
                case .onboarding:
                    OnboardingView(
                        isPresented: .init(
                            get: { appState == .onboarding },
                            set: { _ in appState = .main }
                        )
                    )
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
                #if DEBUG
                    // When test data is pre-seeded in init(), skip migration & RevenueCat
                    if ProcessInfo.processInfo.arguments.contains("Use-Test-Data") {
                        settings.hasLaunched = true
                        appState = .main
                        return
                    }
                #endif

                // Show the splash screen only if startup takes longer than 1s
                let splashTimer = Task {
                    try? await Task.sleep(for: .seconds(1))
                    if appState == .loading {
                        appState = .splash
                        splashShownAt = Date()
                    }
                }

                // Migrate SwiftData store to sqlite-data (runs once, silently)
                @Dependency(\.defaultDatabase) var database
                let migrationResult = SQLiteMigrationCoordinator.migrateIfNeeded(database: database)
                switch migrationResult {
                case .freshInstall:
                    TelemetryDeck.signal("Migration.freshInstall")
                    print("📦 sqlite-data: Fresh install — no migration needed")
                case .alreadyCompleted:
                    break
                case .success(let stats):
                    TelemetryDeck.signal("Migration.success", parameters: ["stats": "\(stats)"])
                    print("📦 sqlite-data: Migration succeeded — \(stats)")
                case .error(let message):
                    TelemetryDeck.signal("Migration.error", parameters: ["message": message])
                    print("📦 sqlite-data: Migration failed — \(message)")
                }

                // Cull empty phantom homes from pre-2.2.0 onboarding re-runs (one-time).
                // Pre-2.2.0 used `homes.last` so extra homes were invisible; with multi-home
                // they'd suddenly appear in the sidebar.
                if let replacementId = await HomeCullingManager.cullIfNeeded(
                    database: database,
                    activeHomeId: settings.activeHomeId
                ) {
                    settings.activeHomeId = replacementId
                }

                // Ensure at least one home exists (safety net for users who
                // deleted all data without re-onboarding).
                // Uses deterministic IDs so CloudKit sync won't create duplicates
                // when a user reinstalls or sets up a new device.
                do {
                    let homeCount = try await database.read { db in
                        try SQLiteHome.count().fetchOne(db)
                    }
                    if homeCount == 0 {
                        let newHomeID = DefaultSeedID.home
                        try await database.write { db in
                            try SQLiteHome.insert {
                                SQLiteHome(
                                    id: newHomeID,
                                    name: "My Home",
                                    isPrimary: true,
                                    colorName: "green"
                                )
                            }.execute(db)

                            for (index, roomData) in TestData.defaultRooms.enumerated() {
                                try SQLiteInventoryLocation.insert {
                                    SQLiteInventoryLocation(
                                        id: DefaultSeedID.roomIDs[index],
                                        name: roomData.name,
                                        desc: roomData.desc,
                                        sfSymbolName: roomData.sfSymbol,
                                        homeID: newHomeID
                                    )
                                }.execute(db)
                            }
                        }
                        settings.activeHomeId = newHomeID.uuidString
                        print("🏠 MovingBoxApp - Created default home (no homes found in database)")
                    }
                } catch {
                    print("⚠️ MovingBoxApp - Error ensuring default home exists: \(error)")
                }

                // Check RevenueCat subscription status
                do {
                    try await revenueCatManager.updateCustomerInfo()
                } catch {
                    print("⚠️ MovingBoxApp - Error checking RevenueCat status: \(error)")
                }

                // If splash was shown, ensure it stays visible for at least 1s
                if let shownAt = splashShownAt {
                    let elapsed = Date().timeIntervalSince(shownAt)
                    if elapsed < 1.0 {
                        try? await Task.sleep(for: .seconds(1.0 - elapsed))
                    }
                }
                splashTimer.cancel()

                // Determine if we should show the welcome screen
                print("📱 MovingBoxApp - Startup complete, transitioning to app")
                appState = OnboardingManager.shouldShowWelcome() ? .onboarding : .main

                // Record that we've launched
                settings.hasLaunched = true

                // Send launched signal to TD
                TelemetryDeck.signal("appLaunched")
            }
            .environment(\.featureFlags, FeatureFlags(distribution: .current))
            .environment(\.whatsNew, .forMovingBox())
            .environmentObject(router)
            .environmentObject(settings)
            .environmentObject(onboardingManager)
            .environmentObject(revenueCatManager)
        }
    }
}
