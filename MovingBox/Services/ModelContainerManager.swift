import SwiftData
import Foundation
import UIKit

@MainActor
class ModelContainerManager: ObservableObject {
    static let shared = ModelContainerManager()
    
    @Published private(set) var container: ModelContainer
    @Published private(set) var isLoading = false
    
    // Migration Progress Properties
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus: String = "Initializing..."
    @Published var migrationDetailMessage: String = "Preparing your data for the new version"
    @Published var isMigrationComplete: Bool = false
    
    // UI timing
    private var initStartTime: Date?
    private let minimumDisplayTime: TimeInterval = 2.0 // 2 seconds minimum
    
    // Track migration completion in UserDefaults
    private var migrationCompletedKey = "MovingBox_v2_MigrationCompleted"
    private var deviceIdKey = "MovingBox_DeviceId"
    private var migrationSchemaVersionKey = "MovingBox_SchemaVersion"
    private let multiHomeMigrationKey = "MovingBox_MultiHomeMigration_v1"
    private let orphanedItemsMigrationKey = "MovingBox_OrphanedItemsMigration_v1"
    private let schemaRecoveryPerformedKey = "MovingBox_SchemaRecoveryPerformed"

    // Current schema version - increment for future migrations
    private let currentSchemaVersion = 2

    /// Check if schema recovery (data backup and fresh start) was performed
    var didPerformSchemaRecovery: Bool {
        UserDefaults.standard.bool(forKey: schemaRecoveryPerformedKey)
    }
    
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
        // Always start with CloudKit disabled during initialization/migration
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("Disable-Persistence"),
            allowsSave: true,
            cloudKitDatabase: .none  // Disable CloudKit during migration
        )

        do {
            // Try to create container with automatic migration
            self.container = try ModelContainer(for: schema, configurations: [configuration])
            print("📦 ModelContainerManager - Created local container for migration")
        } catch let error as NSError {
            print("📦 ModelContainerManager - Error creating container: \(error)")
            print("📦 ModelContainerManager - Error domain: \(error.domain), code: \(error.code)")
            print("📦 ModelContainerManager - Error userInfo: \(error.userInfo)")

            // If this is a migration error, try to handle it
            if error.domain == "SwiftData.SwiftDataError" {
                print("📦 ModelContainerManager - SwiftData error detected, attempting recovery")

                // Attempt to create a fresh container by removing the old store
                do {
                    // Get the default store URL
                    let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    let storeURL = appSupportURL.appendingPathComponent("default.store")
                    let shmURL = appSupportURL.appendingPathComponent("default.store-shm")
                    let walURL = appSupportURL.appendingPathComponent("default.store-wal")

                    // Create backup directory
                    let backupURL = appSupportURL.appendingPathComponent("backup-\(Date().timeIntervalSince1970)")
                    try? FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)

                    // Move old database files to backup
                    if FileManager.default.fileExists(atPath: storeURL.path) {
                        let backupStoreURL = backupURL.appendingPathComponent("default.store")
                        try? FileManager.default.moveItem(at: storeURL, to: backupStoreURL)
                        print("📦 ModelContainerManager - Backed up old store to: \(backupURL.path)")
                    }
                    if FileManager.default.fileExists(atPath: shmURL.path) {
                        try? FileManager.default.removeItem(at: shmURL)
                    }
                    if FileManager.default.fileExists(atPath: walURL.path) {
                        try? FileManager.default.removeItem(at: walURL)
                    }

                    // Try to create fresh container
                    self.container = try ModelContainer(for: schema, configurations: [configuration])
                    print("📦 ModelContainerManager - Created fresh container after backup")

                    // Mark that we need to skip migration since we started fresh
                    UserDefaults.standard.set(true, forKey: self.migrationCompletedKey)
                    UserDefaults.standard.set(self.currentSchemaVersion, forKey: self.migrationSchemaVersionKey)
                    UserDefaults.standard.set(true, forKey: self.schemaRecoveryPerformedKey)

                    print("⚠️ ModelContainerManager - Schema recovery performed. Old data backed up to: \(backupURL.path)")
                    print("⚠️ ModelContainerManager - Users should be informed about the fresh start")

                    return
                } catch {
                    print("📦 ModelContainerManager - Recovery attempt failed: \(error)")
                    fatalError("Failed to create ModelContainer even after recovery attempt: \(error)")
                }
            }

            fatalError("Failed to create ModelContainer: \(error)")
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
                
                // Ensure at least one home exists
                await ensureHomeExists()
                
                // Run orphaned items migration if needed (silent, no UI)
                try? await performOrphanedItemsMigration()
                
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
                
                // Ensure at least one home exists for new installs
                await ensureHomeExists()
                
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
                
                // Force UI update
                self.objectWillChange.send()
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
        // Check user's CloudKit preference
        let isSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        
        // Set default for new installations
        if UserDefaults.standard.object(forKey: "iCloudSyncEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "iCloudSyncEnabled")
        }
        
        // Only recreate container if sync is enabled
        guard isSyncEnabled else {
            print("📦 ModelContainerManager - CloudKit sync disabled by user")
            return
        }
        
        // Create new container with CloudKit enabled
        let syncConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("Disable-Persistence"),
            allowsSave: true,
            cloudKitDatabase: .automatic
        )
        
        do {
            let newContainer = try ModelContainer(for: schema, configurations: [syncConfiguration])
            
            // Migrate data from local container to sync-enabled container
            try await migrateToSyncContainer(from: container, to: newContainer)
            
            await MainActor.run {
                self.container = newContainer
            }
            
            print("📦 ModelContainerManager - Successfully enabled CloudKit sync")
        } catch {
            print("📦 ModelContainerManager - Failed to enable CloudKit sync: \(error)")
            // Continue with local container if CloudKit fails
        }
    }
    
    private func migrateToSyncContainer(from localContainer: ModelContainer, to syncContainer: ModelContainer) async throws {
        // This is a placeholder for data migration logic
        // In a production app, you might need to copy data between containers
        // For now, we'll rely on SwiftData's automatic migration capabilities
        print("📦 ModelContainerManager - Data migration to sync container completed")
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

        await updateMigrationStatus("Setting up multi-home support...", progress: 0.7)
        try? await performMultiHomeMigration()

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
                print("📦 ModelContainerManager - Failed to migrate home \(home.displayName): \(error)")
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

    // MARK: - Home Management
    
    private func ensureHomeExists() async {
        // Skip if we're using test data (it will create its own home)
        guard !ProcessInfo.processInfo.arguments.contains("Use-Test-Data") else {
            print("📦 ModelContainerManager - Skipping home creation for test data")
            return
        }
        
        let context = container.mainContext
        let descriptor = FetchDescriptor<Home>()
        
        do {
            let homes = try context.fetch(descriptor)
            
            if homes.isEmpty {
                print("📦 ModelContainerManager - No homes found, creating initial home")
                let newHome = Home(name: "My Home")
                newHome.isPrimary = true
                context.insert(newHome)
                try context.save()
                
                UserDefaults.standard.set(newHome.id.uuidString, forKey: "activeHomeId")
                
                print("📦 ModelContainerManager - Created initial home")
            }
        } catch {
            print("📦 ModelContainerManager - Error ensuring home exists: \(error)")
        }
    }

    // MARK: - Multi-Home Migration

    private var isMultiHomeMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: multiHomeMigrationKey)
    }

    internal func performMultiHomeMigration() async throws {
        guard !isMultiHomeMigrationCompleted else {
            print("📦 ModelContainerManager - Multi-home migration already completed, skipping")
            return
        }

        let context = container.mainContext
        print("📦 ModelContainerManager - Starting multi-home migration")

        // 1. Get or create primary home
        let homeDescriptor = FetchDescriptor<Home>()
        let homes = try context.fetch(homeDescriptor)

        let primaryHome: Home
        if let existingHome = homes.first {
            primaryHome = existingHome
            print("📦 ModelContainerManager - Found existing home: \(primaryHome.name)")
        } else {
            primaryHome = Home(name: "My Home")
            context.insert(primaryHome)
            print("📦 ModelContainerManager - Created new primary home")
        }
        primaryHome.isPrimary = true

        // 2. Assign all orphaned locations to primary home
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        let locations = try context.fetch(locationDescriptor)
        var migratedLocationsCount = 0

        for location in locations where location.home == nil {
            location.home = primaryHome
            migratedLocationsCount += 1
        }
        print("📦 ModelContainerManager - Migrated \(migratedLocationsCount) locations to primary home")

        // 3. Assign all orphaned labels to primary home
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        let labels = try context.fetch(labelDescriptor)
        var migratedLabelsCount = 0

        for label in labels where label.home == nil {
            label.home = primaryHome
            migratedLabelsCount += 1
        }
        print("📦 ModelContainerManager - Migrated \(migratedLabelsCount) labels to primary home")

        // 4. Assign all items without an effective home to primary home
        let itemDescriptor = FetchDescriptor<InventoryItem>()
        let items = try context.fetch(itemDescriptor)
        var migratedItemsCount = 0

        for item in items {
            // Item needs migration if:
            // 1. Has no location and no direct home assignment, OR
            // 2. Has a location but that location has no home
            let needsMigration = (item.location == nil && item.home == nil) || 
                                 (item.location != nil && item.location?.home == nil)
            
            if needsMigration {
                item.home = primaryHome
                migratedItemsCount += 1
            }
        }
        print("📦 ModelContainerManager - Migrated \(migratedItemsCount) items without effective home to primary home")

        // 5. Save and mark complete
        try context.save()
        UserDefaults.standard.set(true, forKey: multiHomeMigrationKey)

        // 6. Store active home ID in SettingsManager format
        UserDefaults.standard.set(primaryHome.id.uuidString, forKey: "activeHomeId")
        print("📦 ModelContainerManager - Set active home ID: \(primaryHome.id.uuidString)")

        print("📦 ModelContainerManager - Multi-home migration completed successfully")
        print("📦 ModelContainerManager - Summary: \(migratedLocationsCount) locations, \(migratedLabelsCount) labels, \(migratedItemsCount) items")
    }

    // MARK: - Orphaned Items Migration

    private var isOrphanedItemsMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: orphanedItemsMigrationKey)
    }

    internal func performOrphanedItemsMigration(force: Bool = false) async throws {
        let context = container.mainContext

        // Get primary home first
        let homeDescriptor = FetchDescriptor<Home>(predicate: #Predicate { $0.isPrimary })
        guard let primaryHome = try context.fetch(homeDescriptor).first else {
            print("📦 ModelContainerManager - No primary home found, skipping orphaned items migration")
            UserDefaults.standard.set(true, forKey: orphanedItemsMigrationKey)
            return
        }

        // Check if there are actually any orphaned items that need migration
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        let locations = try context.fetch(locationDescriptor)
        let orphanedLocations = locations.filter { $0.home == nil }

        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        let labels = try context.fetch(labelDescriptor)
        let orphanedLabels = labels.filter { $0.home == nil }

        let itemDescriptor = FetchDescriptor<InventoryItem>()
        let items = try context.fetch(itemDescriptor)
        let orphanedItems = items.filter { item in
            (item.location?.home == nil) && (item.home == nil)
        }

        let hasOrphans = !orphanedLocations.isEmpty || !orphanedLabels.isEmpty || !orphanedItems.isEmpty

        // Skip if already completed AND no orphans found
        guard force || hasOrphans || !isOrphanedItemsMigrationCompleted else {
            print("📦 ModelContainerManager - Orphaned items migration already completed and no orphans found, skipping")
            return
        }

        if hasOrphans {
            print("📦 ModelContainerManager - Found \(orphanedLocations.count) orphaned locations, \(orphanedLabels.count) orphaned labels, \(orphanedItems.count) orphaned items - running migration")
        } else {
            print("📦 ModelContainerManager - No orphaned items found, but force=\(force), running migration anyway")
        }

        // Migrate orphaned locations
        var migratedLocationsCount = 0
        for location in orphanedLocations {
            location.home = primaryHome
            migratedLocationsCount += 1
            print("📦 ModelContainerManager - Assigned location '\(location.name)' to primary home")
        }

        // Migrate orphaned labels
        var migratedLabelsCount = 0
        for label in orphanedLabels {
            label.home = primaryHome
            migratedLabelsCount += 1
            print("📦 ModelContainerManager - Assigned label '\(label.name)' to primary home")
        }

        // Migrate orphaned items
        var migratedItemsCount = 0
        for item in orphanedItems {
            item.home = primaryHome
            migratedItemsCount += 1
            print("📦 ModelContainerManager - Assigned item '\(item.title)' to primary home")
        }

        // Save changes
        try context.save()
        
        // Only mark as completed if this wasn't a forced run
        if !force {
            UserDefaults.standard.set(true, forKey: orphanedItemsMigrationKey)
        }

        print("📦 ModelContainerManager - Orphaned items migration completed successfully\(force ? " (forced)" : "")")
        print("📦 ModelContainerManager - Migrated \(migratedLocationsCount) locations, \(migratedLabelsCount) labels, \(migratedItemsCount) items to primary home '\(primaryHome.name)'")
    }

    // MARK: - Sync Control Methods
    
    func setSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "iCloudSyncEnabled")
        print("📦 ModelContainerManager - Sync \(enabled ? "enabled" : "disabled"). App restart required for full effect.")
    }
    
    var isSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }
    
    func getCurrentSyncStatus() -> String {
        // This is a simplified sync status check
        // In practice, you would monitor NSPersistentCloudKitContainer notifications
        if !isSyncEnabled {
            return "Disabled"
        }
        
        // Check if we have network connectivity and return appropriate status
        return "Ready"
    }
}
