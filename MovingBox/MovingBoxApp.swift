//
//  MovingBoxApp.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import CloudKit
import Dependencies
import OSLog
import RevenueCat
import SQLiteData
import Sentry
import SwiftUI
import TelemetryDeck
import UIKit
import WhatsNewKit
import WishKit

private let logger = Logger(subsystem: "com.mothersound.movingbox", category: "App")

private func makeAppSyncEngine(
    for database: any DatabaseWriter,
    startImmediately: Bool
) throws -> SyncEngine {
    try SyncEngine(
        for: database,
        tables: SQLiteHousehold.self,
        SQLiteHouseholdMember.self,
        SQLiteHouseholdInvite.self,
        SQLiteHome.self,
        SQLiteInventoryLocation.self,
        SQLiteInventoryItem.self,
        SQLiteInventoryLabel.self,
        SQLiteInsurancePolicy.self,
        SQLiteInventoryItemLabel.self,
        SQLiteHomeInsurancePolicy.self,
        SQLiteInventoryItemPhoto.self,
        SQLiteHomePhoto.self,
        SQLiteInventoryLocationPhoto.self,
        startImmediately: startImmediately
    )
}

@main
struct MovingBoxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var router = Router()
    @StateObject private var settings = SettingsManager()
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @State private var appState: AppState = .loading
    @State private var splashShownAt: Date?
    @State private var showRecoveryAlert = false
    @State private var strandedItemCount = 0
    @State private var isRecovering = false
    @State private var recoveryActionTaken = false
    @State private var recoveryContinuation: CheckedContinuation<Void, Never>?
    @State private var migrationErrorMessage: String?

    private enum AppState {
        case loading
        case splash
        case onboarding
        case joiningShare(CKShare.Metadata)
        case acceptingShareExistingUser(CKShare.Metadata)
        case main
    }

    init() {
        // Prepare sqlite-data database (runs schema migrations)
        prepareDependencies {
            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("Use-Test-Data") {
                    $0.defaultDatabase = try! makeSeededTestDatabase()
                    return
                } else if ProcessInfo.processInfo.arguments.contains("Disable-Persistence") {
                    $0.defaultDatabase = try! makeInMemoryDatabase()
                    return
                }
            #endif

            do {
                $0.defaultDatabase = try appDatabase()
            } catch {
                logger.error("appDatabase() failed, falling back to in-memory: \(error.localizedDescription)")
                $0.defaultDatabase = try! makeInMemoryDatabase()
            }

            let configuredDatabase = $0.defaultDatabase
            do {
                let syncEngine = try makeAppSyncEngine(
                    for: configuredDatabase,
                    startImmediately: false
                )
                $0.defaultSyncEngine = syncEngine
            } catch {
                logger.error("SyncEngine initialization failed: \(error.localizedDescription)")
                do {
                    $0.defaultSyncEngine = try withDependencies {
                        $0.context = .preview
                    } operation: {
                        try makeAppSyncEngine(
                            for: configuredDatabase,
                            startImmediately: false
                        )
                    }
                    logger.warning("Configured preview-context fallback SyncEngine")
                } catch {
                    logger.fault("Failed to configure any SyncEngine fallback: \(error.localizedDescription)")
                }
            }
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
                            get: { if case .onboarding = appState { true } else { false } },
                            set: { _ in appState = .main }
                        )
                    )
                    .environment(\.disableAnimations, disableAnimations)
                case .joiningShare(let metadata):
                    JoiningShareView(
                        shareMetadata: metadata,
                        onComplete: { appState = .main }
                    )
                    .environment(\.disableAnimations, disableAnimations)
                case .acceptingShareExistingUser(let metadata):
                    ExistingUserShareAcceptanceView(
                        shareMetadata: metadata,
                        onComplete: { appState = .main }
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
                    if case .loading = appState {
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
                    logger.info("sqlite-data: Fresh install — no migration needed")
                    // Check for stranded CoreData records in CloudKit
                    if let count = await CloudKitRecoveryCoordinator.probeForStrandedRecords() {
                        strandedItemCount = count
                        showRecoveryAlert = true
                        await withCheckedContinuation { continuation in
                            recoveryContinuation = continuation
                        }
                    }
                case .alreadyCompleted:
                    // Skip the CloudKit probe if we already have local data (migration
                    // succeeded on a previous launch). Only probe when the local DB is
                    // empty, which means recovery may still be needed.
                    let localItemCount =
                        (try? await database.read { db in
                            try SQLiteInventoryItem.count().fetchOne(db)
                        }) ?? 0
                    if localItemCount == 0 {
                        if let count = await CloudKitRecoveryCoordinator.probeForStrandedRecords() {
                            strandedItemCount = count
                            showRecoveryAlert = true
                            await withCheckedContinuation { continuation in
                                recoveryContinuation = continuation
                            }
                        }
                    }
                case .success(let stats):
                    TelemetryDeck.signal("Migration.success", parameters: ["stats": "\(stats)"])
                    logger.info("sqlite-data: Migration succeeded — \(stats.description)")
                case .error(let message):
                    TelemetryDeck.signal("Migration.error", parameters: ["message": message])
                    logger.error("sqlite-data: Migration failed — \(message)")
                    migrationErrorMessage = message
                }

                // Migrate photo files to BLOB storage (runs once, after schema migration)
                let photoResult = await PhotoBlobMigrationCoordinator.migrateIfNeeded(database: database)
                switch photoResult {
                case .success(let stats):
                    TelemetryDeck.signal("PhotoMigration.success", parameters: ["stats": "\(stats)"])
                    logger.info("Photo BLOB migration succeeded — \(stats.description)")
                case .error(let message):
                    TelemetryDeck.signal("PhotoMigration.error", parameters: ["message": message])
                    logger.error("Photo BLOB migration failed — \(message)")
                case .noPhotos, .alreadyCompleted:
                    break
                }

                // Start SyncEngine after migration/recovery to prevent sync from
                // racing with data writes during migration.
                let syncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
                if syncEnabled {
                    do {
                        @Dependency(\.defaultSyncEngine) var syncEngine
                        try await syncEngine.start()
                    } catch {
                        logger.error("SyncEngine start failed: \(error.localizedDescription)")
                    }
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
                    if homeCount == 0 && ShareMetadataStore.shared.pendingShareMetadata == nil {
                        let newHomeID = DefaultSeedID.home
                        let defaultRooms = TestData.defaultRooms
                        try await database.write { db in
                            try SQLiteHome.insert {
                                SQLiteHome(
                                    id: newHomeID,
                                    name: "My Home",
                                    isPrimary: true,
                                    colorName: "green"
                                )
                            }.execute(db)

                            for (index, roomData) in defaultRooms.enumerated() {
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
                        logger.info("Created default home (no homes found in database)")
                    }
                } catch {
                    logger.warning("Error ensuring default home exists: \(error.localizedDescription)")
                }

                // Check RevenueCat subscription status
                do {
                    try await revenueCatManager.updateCustomerInfo()
                } catch {
                    logger.warning("Error checking RevenueCat status: \(error.localizedDescription)")
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
                logger.info("Startup complete, transitioning to app")

                // If launching from a share link on first launch, route to abbreviated joining flow
                if OnboardingManager.shouldShowWelcome(),
                    let shareMetadata = ShareMetadataStore.shared.consumeMetadata()
                {
                    appState = .joiningShare(shareMetadata)
                    settings.hasLaunched = true
                    TelemetryDeck.signal("appLaunched.joiningShare")
                    return
                }

                if let shareMetadata = ShareMetadataStore.shared.consumeExistingUserMetadata() {
                    appState = .acceptingShareExistingUser(shareMetadata)
                    TelemetryDeck.signal("appLaunched.acceptingShareExistingUser")
                    return
                }

                appState = OnboardingManager.shouldShowWelcome() ? .onboarding : .main

                // Record that we've launched
                settings.hasLaunched = true

                // Send launched signal to TD
                TelemetryDeck.signal("appLaunched")
            }
            .overlay {
                if isRecovering {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Recovering your data...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    }
                }
            }
            .alert("Recover Your Data?", isPresented: $showRecoveryAlert) {
                Button("Recover Data") {
                    recoveryActionTaken = true
                    Task {
                        isRecovering = true
                        @Dependency(\.defaultDatabase) var database
                        let result = await CloudKitRecoveryCoordinator.recoverAllRecords(
                            database: database)
                        switch result {
                        case .recovered(let stats):
                            TelemetryDeck.signal(
                                "CloudKitRecovery.success",
                                parameters: ["stats": "\(stats)"])
                            logger.info("CloudKit recovery succeeded — \(stats.description)")
                            await CloudKitRecoveryCoordinator.deleteOldCoreDataZone()
                        case .error(let message):
                            TelemetryDeck.signal(
                                "CloudKitRecovery.error",
                                parameters: ["message": message])
                            logger.error("CloudKit recovery failed — \(message)")
                        default:
                            break
                        }
                        isRecovering = false
                        recoveryContinuation?.resume()
                        recoveryContinuation = nil
                    }
                }
                Button("Start Fresh", role: .destructive) {
                    recoveryActionTaken = true
                    Task {
                        CloudKitRecoveryCoordinator.markComplete()
                        await CloudKitRecoveryCoordinator.deleteOldCoreDataZone()
                        TelemetryDeck.signal("CloudKitRecovery.skipped")
                        recoveryContinuation?.resume()
                        recoveryContinuation = nil
                    }
                }
            } message: {
                Text(
                    "Found \(strandedItemCount) item(s) from a previous installation in iCloud. Would you like to recover them?"
                )
            }
            .onChange(of: showRecoveryAlert) { _, isShowing in
                // Safety net: if alert is dismissed without a button tap (e.g. system
                // interruption), resume the continuation to prevent a deadlock.
                // Skip when a button action was taken — those handle their own cleanup.
                if !isShowing, !recoveryActionTaken, let continuation = recoveryContinuation {
                    CloudKitRecoveryCoordinator.markComplete()
                    continuation.resume()
                    recoveryContinuation = nil
                }
            }
            .alert(
                "Data Migration Issue",
                isPresented: Binding(
                    get: { migrationErrorMessage != nil },
                    set: { if !$0 { migrationErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(migrationErrorMessage ?? "")
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: ShareMetadataStore.existingUserShareMetadataDidChange
                )
            ) { _ in
                guard !OnboardingManager.shouldShowWelcome(),
                    let shareMetadata = ShareMetadataStore.shared.consumeExistingUserMetadata()
                else { return }

                appState = .acceptingShareExistingUser(shareMetadata)
                TelemetryDeck.signal("shareInvite.acceptingShareExistingUser")
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
