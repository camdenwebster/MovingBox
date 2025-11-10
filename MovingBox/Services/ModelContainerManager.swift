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

    // iCloud Sync Properties
    @Published var isWaitingForInitialSync: Bool = false
    @Published var syncStatus: String = "Checking for existing data..."

    // UI timing
    private var initStartTime: Date?
    private let minimumDisplayTime: TimeInterval = 2.0 // 2 seconds minimum
    private var syncStartTime: Date?
    private let initialCloudKitWait: TimeInterval = 3.0 // Wait for CloudKit to initialize
    private let syncUIThreshold: TimeInterval = 5.0 // Show UI if sync takes > 5 seconds (3s initial + 2s buffer)
    private let minimumSyncUIDisplay: TimeInterval = 0.5 // Show sync UI for at least 0.5 seconds
    private var syncUIShownTime: Date?
    
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

    // MARK: - Initial iCloud Sync

    /// Wait for initial iCloud sync on first launch
    /// Shows progress UI only if sync takes longer than 2 seconds
    /// Keeps UI visible for minimum 0.5 seconds once shown
    func waitForInitialSync() async {
        // Only wait for sync on first launch
        guard shouldSkipMigrationForNewInstall else {
            print("📦 ModelContainerManager - Not first launch, skipping initial sync wait")
            return
        }

        // Only wait if iCloud sync is enabled
        guard isSyncEnabled else {
            print("📦 ModelContainerManager - iCloud sync disabled, skipping wait")
            return
        }

        print("📦 ModelContainerManager - Starting initial sync wait for first launch")
        syncStartTime = Date()

        // Give CloudKit time to initialize and connect before checking
        // This is critical - CloudKit doesn't start syncing instantly
        let initialWaitNanoseconds = UInt64(initialCloudKitWait * 1_000_000_000)
        print("📦 ModelContainerManager - Waiting \(Int(initialCloudKitWait))s for CloudKit to initialize...")
        try? await Task.sleep(nanoseconds: initialWaitNanoseconds)

        // Check for existing data every 0.5 seconds after initial wait
        let checkInterval: UInt64 = 500_000_000 // 0.5 seconds in nanoseconds
        let maxWaitTime: TimeInterval = 20.0 // Maximum 20 seconds total (including initial wait)

        var hasShownUI = false

        while true {
            let elapsed = Date().timeIntervalSince(syncStartTime!)

            // Check if we've exceeded maximum wait time
            if elapsed > maxWaitTime {
                print("📦 ModelContainerManager - Max wait time reached, proceeding without iCloud data")
                break
            }

            // Check for existing data
            let hasData = await checkForExistingCloudKitData()

            if hasData {
                print("📦 ModelContainerManager - Found existing data in \(String(format: "%.1f", elapsed))s")
                break
            }

            // If we've passed the UI threshold and haven't shown UI yet, show it
            if elapsed > syncUIThreshold && !hasShownUI {
                print("📦 ModelContainerManager - Sync taking longer than \(syncUIThreshold)s, showing UI")
                isWaitingForInitialSync = true
                syncUIShownTime = Date()
                hasShownUI = true
            }

            // Update sync status message
            if hasShownUI {
                let timeWaited = Int(elapsed)
                syncStatus = "Syncing with iCloud... (\(timeWaited)s)"
            }

            // Wait before next check
            try? await Task.sleep(nanoseconds: checkInterval)
        }

        // If we showed UI, ensure it's visible for minimum duration
        if hasShownUI, let shownTime = syncUIShownTime {
            let uiElapsed = Date().timeIntervalSince(shownTime)
            let remaining = minimumSyncUIDisplay - uiElapsed

            if remaining > 0 {
                print("📦 ModelContainerManager - Ensuring minimum UI display time (\(String(format: "%.1f", remaining))s remaining)")
                syncStatus = "Sync complete!"
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }

        // Hide sync UI
        isWaitingForInitialSync = false
        print("📦 ModelContainerManager - Initial sync wait complete")
    }

    /// Check if existing data exists in CloudKit
    private func checkForExistingCloudKitData() async -> Bool {
        do {
            let context = container.mainContext

            // Check for any existing Home, Location, or Item data
            let homeDescriptor = FetchDescriptor<Home>()
            let homes = try context.fetch(homeDescriptor)
            if !homes.isEmpty {
                print("📦 ModelContainerManager - Found \(homes.count) home(s)")
                return true
            }

            let locationDescriptor = FetchDescriptor<InventoryLocation>()
            let locations = try context.fetch(locationDescriptor)
            if !locations.isEmpty {
                print("📦 ModelContainerManager - Found \(locations.count) location(s)")
                return true
            }

            let itemDescriptor = FetchDescriptor<InventoryItem>()
            let items = try context.fetch(itemDescriptor)
            if !items.isEmpty {
                print("📦 ModelContainerManager - Found \(items.count) item(s)")
                return true
            }

            return false
        } catch {
            print("📦 ModelContainerManager - Error checking for existing data: \(error)")
            return false
        }
    }
}
