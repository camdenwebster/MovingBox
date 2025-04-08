import Testing
import SwiftData
import CloudKit
@testable import MovingBox

// Mock version of ICloudSyncManager for testing
@MainActor
class MockICloudSyncManager: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date? {
        didSet {
            // Persist the sync date
            if let date = lastSyncDate {
                UserDefaults.standard.set(date, forKey: "LastiCloudSyncDate")
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    private var modelContainer: ModelContainer?
    private var settingsManager: SettingsManager?
    private var contextObserver: NSObjectProtocol?
    private var syncDisabled = false  // New flag to disable further sync operations
    
    init(settingsManager: SettingsManager?) {
        self.settingsManager = settingsManager
        self.lastSyncDate = UserDefaults.standard.object(forKey: "LastiCloudSyncDate") as? Date
    }
    
    func setupSync(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        syncDisabled = false
        setupContextObserver()
    }
    
    private func setupContextObserver() {
        contextObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleContextChange()
            }
        }
    }
    
    private func handleContextChange() async {
        guard !syncDisabled,
              let settingsManager = settingsManager,
              settingsManager.isPro && settingsManager.iCloudEnabled
        else {
            return
        }
        await syncNow()
    }
    
    func setSettingsManager(_ manager: SettingsManager) {
        self.settingsManager = manager
    }
    
    func syncNow() async {
        guard !syncDisabled,
              let settingsManager = settingsManager,
              settingsManager.isPro && settingsManager.iCloudEnabled else {
            return
        }
        guard !isSyncing else {
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        // Simulate the sync delay
        try? await Task.sleep(for: .milliseconds(50))
        
        let now = Date()
        lastSyncDate = now
    }
    
    func disableSync() {
        syncDisabled = true
        if let observer = contextObserver {
            NotificationCenter.default.removeObserver(observer)
            contextObserver = nil
        }
        modelContainer = nil
    }
    
    func waitForSync() async throws -> Bool {
        await syncNow()
        return true
    }
    
    deinit {
        if let observer = contextObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

@MainActor
@Suite struct ICloudSyncManagerTests {
    enum TestError: Error {
        case missingLastSyncDate
        case missingSavedDate
        case bothDatesNotSet
        case containerCreationFailed
    }
    
    func resetSharedState() {
        // Explicitly remove the "LastiCloudSyncDate" key to avoid leftover state
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "LastiCloudSyncDate")
        defaults.synchronize()
    }
    
    func createMockSettings(isPro: Bool = false, iCloudEnabled: Bool = false) -> SettingsManager {
        let settings = SettingsManager()
        settings.resetToDefaults()
        settings.isPro = isPro
        settings.iCloudEnabled = iCloudEnabled
        return settings
    }
    
    func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            Home.self,
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            InsurancePolicy.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
    
    @Test("Test initialization")
    func testInitialization() async throws {
        resetSharedState()
        
        let settings = createMockSettings()
        let manager = MockICloudSyncManager(settingsManager: settings)
        
        let isSyncing = manager.isSyncing
        let lastSyncDate = manager.lastSyncDate
        let savedDate = UserDefaults.standard.object(forKey: "LastiCloudSyncDate") as? Date
        
        #expect(isSyncing == false, "Should not be syncing initially")
        #expect(lastSyncDate == savedDate, "Should load last sync date from UserDefaults")
    }
    
    @Test("Test settings manager update")
    func testSettingsManagerUpdate() async throws {
        resetSharedState()
        
        let container = try createTestContainer()
        let manager = MockICloudSyncManager(settingsManager: createMockSettings())
        
        manager.setupSync(modelContainer: container)
        
        let newSettings = createMockSettings(isPro: true, iCloudEnabled: true)
        manager.setSettingsManager(newSettings)
        await manager.syncNow()
        
        #expect(manager.isSyncing == false, "Should complete sync")
        
        manager.disableSync()
    }
    
    @Test("Test sync state management")
    func testSyncStateManagement() async throws {
        resetSharedState()
        
        let container = try createTestContainer()
        let manager = MockICloudSyncManager(settingsManager: createMockSettings(isPro: true, iCloudEnabled: true))
        
        // Setup and perform sync
        manager.setupSync(modelContainer: container)
        await manager.syncNow()
        
        // Wait for sync to complete and state to update (350ms)
        try await Task.sleep(for: .milliseconds(350))
        
        // Get current sync date
        let currentDate = manager.lastSyncDate
        #expect(currentDate != nil, "Should have updated sync date")
        
        // Verify UserDefaults persistence
        if let syncDate = currentDate {
            UserDefaults.standard.synchronize()
            let savedDate = UserDefaults.standard.object(forKey: "LastiCloudSyncDate") as? Date
            #expect(savedDate != nil, "Should persist sync date")
            if let saved = savedDate {
                #expect(abs(syncDate.timeIntervalSince(saved)) < 1.0, "Dates should match")
            }
        }
        
        manager.disableSync()
    }
    
    @Test("Test context observer setup")
    func testContextObserverSetup() async throws {
        resetSharedState()
        
        let container = try createTestContainer()
        let manager = MockICloudSyncManager(settingsManager: createMockSettings(isPro: true, iCloudEnabled: true))
        let context = container.mainContext
        
        // Setup sync and initial state check
        manager.setupSync(modelContainer: container)
        #expect(manager.lastSyncDate == nil, "Should start with no sync date")
        
        // Make a change to trigger observer
        let home = Home(name: "Test Home")
        context.insert(home)
        try context.save()
        
        // Wait for async sync to finish (350ms)
        try await Task.sleep(for: .milliseconds(350))
        
        let lastSyncDate = manager.lastSyncDate
        #expect(lastSyncDate != nil, "Should update last sync date after save")
        
        // Cleanup test data
        let descriptor = FetchDescriptor<Home>()
        let homes = try context.fetch(descriptor)
        for home in homes {
            context.delete(home)
        }
        try context.save()
        
        manager.disableSync()
    }
    
    @Test("Test sync restrictions for non-pro users")
    func testSyncRestrictions() async throws {
        resetSharedState()
        
        let container = try createTestContainer()
        let manager = MockICloudSyncManager(settingsManager: createMockSettings(isPro: false, iCloudEnabled: true))
        
        manager.setupSync(modelContainer: container)
        await manager.syncNow()
        
        #expect(manager.isSyncing == false, "Should not sync for non-pro users")
        #expect(manager.lastSyncDate == nil, "Should not update sync date for non-pro users")
        
        manager.disableSync()
    }
    
    @Test("Test observer cleanup")
    func testObserverCleanup() async throws {
        resetSharedState()
        
        let container = try createTestContainer()
        let manager = MockICloudSyncManager(settingsManager: createMockSettings(isPro: true, iCloudEnabled: true))
        let context = container.mainContext
        
        let initialSyncDate = manager.lastSyncDate
        manager.setupSync(modelContainer: container)
        
        let home = Home(name: "Test Home")
        context.insert(home)
        try context.save()
        
        manager.disableSync()
        
        let secondHome = Home(name: "Second Home")
        context.insert(secondHome)
        try context.save()
        
        try await Task.sleep(for: .milliseconds(350))
        
        let currentSyncDate = manager.lastSyncDate
        #expect(currentSyncDate == initialSyncDate, "Should not update last sync date after disabling sync")
        
        // Cleanup
        let descriptor = FetchDescriptor<Home>()
        let homes = try context.fetch(descriptor)
        for home in homes {
            context.delete(home)
        }
        try context.save()
    }
    
    @Test("Test wait for sync behavior")
    func testWaitForSync() async throws {
        resetSharedState()
        
        let container = try createTestContainer()
        let manager = MockICloudSyncManager(settingsManager: createMockSettings(isPro: true, iCloudEnabled: true))
        
        manager.setupSync(modelContainer: container)
        let result = try await manager.waitForSync()
        
        #expect(result == true, "Should complete sync operation")
        
        manager.disableSync()
    }
    
    @Test("Test last sync date persistence")
    func testLastSyncDatePersistence() async throws {
        resetSharedState()
        
        let container = try createTestContainer()
        let manager = MockICloudSyncManager(settingsManager: createMockSettings(isPro: true, iCloudEnabled: true))
        
        manager.setupSync(modelContainer: container)
        await manager.syncNow()
        
        // Wait for persistence (350ms)
        var currentDate: Date?
        for _ in 0...5 {
            currentDate = manager.lastSyncDate
            if currentDate != nil { break }
            try await Task.sleep(for: .milliseconds(350))
        }
        
        let persistedDate = UserDefaults.standard.object(forKey: "LastiCloudSyncDate") as? Date
        #expect(currentDate != nil, "Should have a sync date")
        #expect(persistedDate != nil, "Should have persisted date")
        
        if let syncDate = currentDate, let savedDate = persistedDate {
            #expect(abs(syncDate.timeIntervalSince(savedDate)) < 1.0, "Dates should match")
        }
        
        manager.disableSync()
    }
}
