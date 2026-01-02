import SwiftData
import Foundation
import UIKit
import CoreData

@Observable
@MainActor
class ModelContainerManager {
    static let shared = ModelContainerManager()

    private(set) var container: ModelContainer
    private(set) var isLoading = false

    // Migration Progress Properties
    var migrationProgress: Double = 0.0
    var migrationStatus: String = "Initializing..."
    var migrationDetailMessage: String = "Preparing your data for the new version"
    var isMigrationComplete: Bool = false

    // CloudKit Sync Progress Properties
    var isCloudKitSyncing: Bool = false
    var cloudKitSyncMessage: String = ""
    private(set) var isCloudKitImportActive: Bool = false

    // CloudKit event tracking
    private var cloudKitEventObserver: NSObjectProtocol?
    private var activeImportEvents: Set<UUID> = []
    private var syncStartTime: Date?
    private let initialSyncGracePeriod: TimeInterval = 2.0 // Wait for import events to start

    // Last sync time tracking (persisted in UserDefaults, key defined in SettingsManager)
    private var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: SettingsManager.lastSyncDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: SettingsManager.lastSyncDateKey) }
    }

    // UI timing
    private var initStartTime: Date?
    private let minimumDisplayTime: TimeInterval = 2.0 // 2 seconds minimum
    
    // Track migration completion in UserDefaults
    private var migrationCompletedKey = "MovingBox_v2_MigrationCompleted"
    private var deviceIdKey = "MovingBox_DeviceId"
    private var migrationSchemaVersionKey = "MovingBox_SchemaVersion"
    
    // Current schema version - increment for future migrations
    private let currentSchemaVersion = 2
    
    private var isMigrationAlreadyCompleted: Bool {
        let completed = UserDefaults.standard.bool(forKey: migrationCompletedKey)
        let schemaVersion = UserDefaults.standard.integer(forKey: migrationSchemaVersionKey)
        let isCompleted = completed && schemaVersion >= currentSchemaVersion
        
        print("📦 ModelContainerManager - Migration check: completed=\(completed), schema=\(schemaVersion), current=\(currentSchemaVersion), result=\(isCompleted)")
        
        return isCompleted
    }
    
    private var shouldSkipMigrationForNewInstall: Bool {
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunched")
        print("📦 ModelContainerManager - hasLaunched check: \(hasLaunched)")
        return !hasLaunched
    }
    
    private var deviceId: String {
        if let existingId = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existingId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        return newId
    }
    
    private func markMigrationCompleted() {
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        UserDefaults.standard.set(currentSchemaVersion, forKey: migrationSchemaVersionKey)
        print("📦 ModelContainerManager - Migration completed for device: \(deviceId)")
        print("📦 ModelContainerManager - Migration key set: \(migrationCompletedKey) = true")
        print("📦 ModelContainerManager - Schema version set: \(migrationSchemaVersionKey) = \(currentSchemaVersion)")
    }
    
    // For testing purposes - reset migration status
    func resetMigrationStatus() {
        UserDefaults.standard.removeObject(forKey: migrationCompletedKey)
        UserDefaults.standard.removeObject(forKey: migrationSchemaVersionKey)
        print("📦 ModelContainerManager - Migration status reset")
    }
    
    // For testing - force complete migration (skip migration UI)
    func forceCompleteMigration() {
        markMigrationCompleted()
        print("📦 ModelContainerManager - Migration force completed")
    }
    
    private let schema = Schema([
        InventoryLabel.self,
        InventoryItem.self,
        InventoryLocation.self,
        InsurancePolicy.self,
        Home.self
    ])
    
    private init() {
        // Register value transformers before creating ModelContainer
        // This must happen before any SwiftData operations
        UIColorValueTransformer.register()

        // Determine CloudKit configuration upfront - NEVER replace the container later
        // to avoid CloudKit mirroring delegate teardown blocking (50+ seconds)
        let isInMemory = ProcessInfo.processInfo.arguments.contains("Disable-Persistence")
        let isSyncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") == nil
            ? true  // Default to enabled for new installs
            : UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        // Create container with final CloudKit configuration from the start
        let cloudKitSetting: ModelConfiguration.CloudKitDatabase = (isSyncEnabled && !isInMemory) ? .automatic : .none

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isInMemory,
            allowsSave: true,
            cloudKitDatabase: cloudKitSetting
        )

        let isCloudKitEnabled = isSyncEnabled && !isInMemory

        do {
            self.container = try ModelContainer(for: schema, configurations: [configuration])
            print("📦 ModelContainerManager - Created container with CloudKit: \(isCloudKitEnabled ? "enabled" : "disabled")")
        } catch {
            print("📦 ModelContainerManager - Fatal error creating container: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Start CloudKit event monitoring immediately if sync is enabled
        if isCloudKitEnabled {
            startCloudKitEventMonitoring()
        }
    }
    
    init(testContainer: ModelContainer) {
        self.container = testContainer
        self.isLoading = false
    }
    
    func initialize() async {
        do {
            print("📦 ModelContainerManager - Starting initialization")
            
            // Check if migration was already completed
            if isMigrationAlreadyCompleted {
                print("📦 ModelContainerManager - Migration already completed, skipping")
                // Skip migration and go straight to CloudKit setup - no UI needed
                try await enableCloudKitSync()
                
                await MainActor.run {
                    self.isMigrationComplete = true
                    // isLoading already false, so no UI shows
                }
                print("📦 ModelContainerManager - Initialization complete, no migration UI shown")
                return
            }
            
            // Skip migration for new installs (app has never launched before)
            if shouldSkipMigrationForNewInstall {
                print("📦 ModelContainerManager - New install detected, skipping migration")
                // Mark as completed to avoid showing migration on next launch
                markMigrationCompleted()
                
                // Setup CloudKit for new install
                try await enableCloudKitSync()
                
                await MainActor.run {
                    self.isMigrationComplete = true
                    // isLoading already false, so no UI shows
                }
                print("📦 ModelContainerManager - New install initialization complete, no migration UI shown")
                return
            }
            
            print("📦 ModelContainerManager - Migration needed, showing UI and starting migration")
            
            // Show migration UI and record start time
            await MainActor.run {
                self.isLoading = true
                self.initStartTime = Date()
            }
            
            // Perform migration for first-time v2.0 users
            await performLocalMigration()
            
            // Ensure minimum display time before hiding
            await ensureMinimumDisplayTime()
            
            await MainActor.run {
                print("📦 ModelContainerManager - Hiding migration UI")
                self.isMigrationComplete = true
                self.isLoading = false
            }
        } catch {
            print("📦 ModelContainerManager - Error during initialization: \(error)")
            
            // Show error in migration UI
            await MainActor.run {
                self.isLoading = true
                self.initStartTime = Date()
            }
            
            // Still ensure minimum display time even on error
            await ensureMinimumDisplayTime()
            
            await MainActor.run {
                self.migrationStatus = "Migration failed"
                self.migrationDetailMessage = "Please restart the app. If the problem persists, contact support."
                self.isLoading = false
            }
        }
    }
    
    private func ensureMinimumDisplayTime() async {
        guard let startTime = initStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = minimumDisplayTime - elapsed
        
        if remaining > 0 {
            print("📦 ModelContainerManager - Waiting \(String(format: "%.1f", remaining))s to meet minimum display time")
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        } else {
            print("📦 ModelContainerManager - Minimum display time already met (\(String(format: "%.1f", elapsed))s)")
        }
    }
    
    private func updateMigrationStatus(_ status: String, progress: Double, detail: String? = nil) async {
        await MainActor.run {
            self.migrationStatus = status
            self.migrationProgress = progress
            if let detail = detail {
                self.migrationDetailMessage = detail
            } else {
                // Provide helpful context based on progress
                switch progress {
                case 0.0...0.3:
                    self.migrationDetailMessage = "Preparing your data for enhanced features"
                case 0.3...0.7:
                    self.migrationDetailMessage = "Optimizing photo storage and organization"
                case 0.7...0.9:
                    self.migrationDetailMessage = "Finalizing data structure improvements"
                default:
                    self.migrationDetailMessage = "Your inventory is ready with new capabilities!"
                }
            }
        }
    }
    
    private func enableCloudKitSync() async throws {
        // Check if CloudKit is enabled (determined at init time)
        let isSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        guard isSyncEnabled else {
            print("📦 ModelContainerManager - CloudKit sync disabled by user")
            return
        }

        // CloudKit is already configured in init() - just show sync progress UI
        // and wait for initial sync to complete
        await MainActor.run {
            self.isCloudKitSyncing = true
            self.cloudKitSyncMessage = "Downloading your items from iCloud..."
        }

        print("📦 ModelContainerManager - Waiting for CloudKit initial sync")

        // Record sync start time
        syncStartTime = Date()

        // Wait for initial sync to complete or grace period to expire
        await waitForInitialSync()

        await MainActor.run {
            self.isCloudKitSyncing = false
            self.cloudKitSyncMessage = ""
        }

        print("📦 ModelContainerManager - CloudKit initial sync completed")
    }

    // MARK: - CloudKit Event Monitoring

    private func startCloudKitEventMonitoring() {
        // Remove existing observer if any
        if let observer = cloudKitEventObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Listen to CloudKit sync events from NSPersistentCloudKitContainer
        cloudKitEventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }

        print("📦 ModelContainerManager - Started CloudKit event monitoring")
    }

    private nonisolated func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        Task { @MainActor in
            let eventType: String
            switch event.type {
            case .setup:
                eventType = "setup"
            case .import:
                eventType = "import"
            case .export:
                eventType = "export"
            @unknown default:
                eventType = "unknown"
            }

            if event.endDate == nil {
                // Event started
                print("📦 CloudKit event started: \(eventType) (id: \(event.identifier))")

                if event.type == .import {
                    self.activeImportEvents.insert(event.identifier)
                    self.isCloudKitImportActive = true
                    self.cloudKitSyncMessage = "Downloading your items from iCloud..."
                }
            } else {
                // Event ended
                let succeeded = event.succeeded
                print("📦 CloudKit event ended: \(eventType) (id: \(event.identifier), succeeded: \(succeeded))")

                if event.type == .import {
                    self.activeImportEvents.remove(event.identifier)

                    if self.activeImportEvents.isEmpty {
                        self.isCloudKitImportActive = false
                        print("📦 ModelContainerManager - All CloudKit imports completed")
                    }
                }

                // Update last sync time on successful import or export
                if succeeded && (event.type == .import || event.type == .export) {
                    self.lastSyncDate = Date()
                    print("📦 ModelContainerManager - Updated last sync time: \(self.lastSyncDate?.description ?? "nil")")
                }

                if let error = event.error {
                    print("📦 CloudKit event error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func waitForInitialSync() async {
        // Wait for grace period to allow import events to start
        try? await Task.sleep(nanoseconds: UInt64(initialSyncGracePeriod * 1_000_000_000))

        // If imports are active, wait for them to complete (with timeout)
        let maxWaitTime: TimeInterval = 30.0 // Maximum 30 seconds wait
        let startTime = Date()

        while isCloudKitImportActive {
            let elapsed = Date().timeIntervalSince(startTime)

            if elapsed >= maxWaitTime {
                print("📦 ModelContainerManager - Initial sync timeout after \(Int(elapsed))s, proceeding anyway")
                break
            }

            // Update message with progress indication
            await MainActor.run {
                self.cloudKitSyncMessage = "Downloading your items from iCloud..."
            }

            try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5 seconds
        }

        let totalWait = Date().timeIntervalSince(syncStartTime ?? Date())
        print("📦 ModelContainerManager - Initial sync wait completed after \(String(format: "%.1f", totalWait))s")
    }

    func stopCloudKitEventMonitoring() {
        if let observer = cloudKitEventObserver {
            NotificationCenter.default.removeObserver(observer)
            cloudKitEventObserver = nil
            print("📦 ModelContainerManager - Stopped CloudKit event monitoring")
        }
    }
    
    
    // MARK: - Multi-Device Migration Coordination
    
    private func checkForCloudKitData() async -> Bool {
        // Check if CloudKit sync is enabled
        let isSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        guard isSyncEnabled else { return false }
        
        // For the initial release, assume we need local migration first
        // In future versions, this could check CloudKit for existing records
        // For now, always do local migration first, then enable CloudKit
        return false
    }
    
    private func handleCloudKitDataMerge() async {
        await updateMigrationStatus("Syncing with other devices...", progress: 0.1)
        
        // First enable CloudKit to receive any existing data
        do {
            try await enableCloudKitSync()
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds for CloudKit sync
        } catch {
            print("📦 ModelContainerManager - Failed to enable CloudKit during merge: \(error)")
        }
        
        await updateMigrationStatus("Checking for conflicts...", progress: 0.3)
        
        // Check if we have local data that needs migration vs CloudKit data
        let hasLocalDataToMigrate = await checkForLocalDataRequiringMigration()
        
        if hasLocalDataToMigrate {
            await updateMigrationStatus("Merging device data...", progress: 0.5)
            try? await performSelectiveMigration()
        }
        
        await updateMigrationStatus("Finalizing sync...", progress: 0.8)
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await updateMigrationStatus("Ready!", progress: 1.0)
        markMigrationCompleted()
    }
    
    private func performLocalMigration() async {
        // Original migration logic for first device or when CloudKit is disabled
        await updateMigrationStatus("Checking data compatibility...", progress: 0.1)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Migrate all models before enabling CloudKit
        await updateMigrationStatus("Migrating home data...", progress: 0.2)
        try? await migrateHomes()
        
        await updateMigrationStatus("Migrating locations...", progress: 0.4)
        try? await migrateLocations()
        
        await updateMigrationStatus("Migrating inventory items...", progress: 0.6)
        try? await migrateInventoryItems()
        
        await updateMigrationStatus("Completing migration...", progress: 0.8)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Phase 2: Enable CloudKit after successful migration
        await updateMigrationStatus("Enabling iCloud sync...", progress: 0.9)
        try? await enableCloudKitSync()
        
        await updateMigrationStatus("Ready!", progress: 1.0)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        markMigrationCompleted()
    }
    
    private func checkForLocalDataRequiringMigration() async -> Bool {
        do {
            let context = container.mainContext
            
            // Check for items with legacy data that need migration
            let itemDescriptor = FetchDescriptor<InventoryItem>()
            let items = try context.fetch(itemDescriptor)
            
            for item in items {
                if item.data != nil && item.imageURL == nil {
                    return true // Found legacy data requiring migration
                }
            }
            
            return false
        } catch {
            print("📦 ModelContainerManager - Error checking local data: \(error)")
            return false
        }
    }
    
    private func performSelectiveMigration() async throws {
        // Only migrate items that haven't been migrated by another device
        let context = container.mainContext
        
        let itemDescriptor = FetchDescriptor<InventoryItem>()
        let items = try context.fetch(itemDescriptor)
        
        var migratedCount = 0
        let totalItems = items.count
        
        for (index, item) in items.enumerated() {
            // Only migrate if this item still has legacy data
            if item.data != nil && item.imageURL == nil {
                try await item.migrateImageIfNeeded()
                migratedCount += 1
            }
            
            // Update progress
            let progress = 0.5 + (Double(index) / Double(totalItems)) * 0.3
            await updateMigrationStatus("Migrating device-specific data...", progress: progress)
            
            try context.save()
        }
        
        print("📦 ModelContainerManager - Selectively migrated \(migratedCount) items")
    }
    
    internal func migrateHomes() async throws {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Home>()
        
        let homes = try context.fetch(descriptor)
        print("📦 ModelContainerManager - Beginning migration for \(homes.count) homes")
        
        for home in homes {
            do {
                try await home.migrateImageIfNeeded()
                try context.save()
            } catch {
                print("📦 ModelContainerManager - Failed to migrate home \(home.name): \(error)")
            }
        }
        
        print("📦 ModelContainerManager - Completed home migrations")
    }
    
    internal func migrateLocations() async throws {
        let context = container.mainContext
        let descriptor = FetchDescriptor<InventoryLocation>()
        
        let locations = try context.fetch(descriptor)
        print("📦 ModelContainerManager - Beginning migration for \(locations.count) locations")
        
        for location in locations {
            do {
                try await location.migrateImageIfNeeded()
                try context.save()
            } catch {
                print("📦 ModelContainerManager - Failed to migrate location \(location.name): \(error)")
            }
        }
        
        print("📦 ModelContainerManager - Completed location migrations")
    }
    
    internal func migrateInventoryItems() async throws {
        let context = container.mainContext
        let descriptor = FetchDescriptor<InventoryItem>()
        
        let items = try context.fetch(descriptor)
        print("📦 ModelContainerManager - Beginning migration for \(items.count) inventory items")
        
        for item in items {
            do {
                try await item.migrateImageIfNeeded()
                try context.save()
            } catch {
                print("📦 ModelContainerManager - Failed to migrate inventory item \(item.title): \(error)")
            }
        }
        
        print("📦 ModelContainerManager - Completed inventory item migrations")
    }
    
    // MARK: - Sync Control Methods

    /// Sets iCloud sync preference. Requires app restart to take effect.
    /// The container's CloudKit configuration is determined at app launch and cannot be changed mid-flight
    /// to avoid CloudKit mirroring delegate teardown blocking.
    func setSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "iCloudSyncEnabled")
        print("📦 ModelContainerManager - Sync preference set to \(enabled ? "enabled" : "disabled"). App restart required.")
    }

    var isSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }

    func getCurrentSyncStatus() -> String {
        if !isSyncEnabled {
            return "Disabled"
        }

        if isCloudKitImportActive {
            return "Syncing"
        }

        return "Ready"
    }

    /// Triggers a refresh by saving the context, which prompts CloudKit to sync
    /// Returns when any resulting import operations complete (or timeout)
    func refreshData() async {
        guard isSyncEnabled else {
            print("📦 ModelContainerManager - Refresh skipped: sync is disabled")
            return
        }

        print("📦 ModelContainerManager - Manual refresh triggered")

        // Save context to trigger CloudKit export/import cycle
        do {
            try container.mainContext.save()
            print("📦 ModelContainerManager - Context saved, waiting for sync")
        } catch {
            print("📦 ModelContainerManager - Error saving context during refresh: \(error)")
        }

        // Wait briefly for import events to start
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // If imports started, wait for them to complete (with shorter timeout for manual refresh)
        let maxWaitTime: TimeInterval = 10.0
        let startTime = Date()

        while isCloudKitImportActive {
            let elapsed = Date().timeIntervalSince(startTime)

            if elapsed >= maxWaitTime {
                print("📦 ModelContainerManager - Refresh timeout after \(Int(elapsed))s")
                break
            }

            try? await Task.sleep(nanoseconds: 250_000_000) // Check every 0.25 seconds
        }

        print("📦 ModelContainerManager - Refresh completed")
    }
}
