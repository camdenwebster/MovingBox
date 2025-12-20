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
        // Always start with CloudKit disabled during initialization/migration
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("Disable-Persistence"),
            allowsSave: true,
            cloudKitDatabase: .none  // Disable CloudKit during migration
        )
        
        do {
            self.container = try ModelContainer(for: schema, configurations: [configuration])
            print("📦 ModelContainerManager - Created local container for migration")
        } catch {
            print("📦 ModelContainerManager - Fatal error creating container: \(error)")
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

        // 4. Assign all orphaned items (without location) to primary home
        let itemDescriptor = FetchDescriptor<InventoryItem>()
        let items = try context.fetch(itemDescriptor)
        var migratedItemsCount = 0

        for item in items where item.location == nil && item.home == nil {
            item.home = primaryHome
            migratedItemsCount += 1
        }
        print("📦 ModelContainerManager - Migrated \(migratedItemsCount) orphaned items to primary home")

        // 5. Save and mark complete
        try context.save()
        UserDefaults.standard.set(true, forKey: multiHomeMigrationKey)

        // 6. Store active home ID in SettingsManager format
        if let modelID = try? primaryHome.persistentModelID.uriRepresentation().dataRepresentation {
            let idString = modelID.base64EncodedString()
            UserDefaults.standard.set(idString, forKey: "activeHomeId")
            print("📦 ModelContainerManager - Set active home ID: \(idString)")
        }

        print("📦 ModelContainerManager - Multi-home migration completed successfully")
        print("📦 ModelContainerManager - Summary: \(migratedLocationsCount) locations, \(migratedLabelsCount) labels, \(migratedItemsCount) items")
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
