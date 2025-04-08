import Testing
import SwiftData
import CloudKit
@testable import MovingBox

@MainActor
@Suite struct ICloudSyncManagerTests {
    
    enum TestError: Error {
        case missingLastSyncDate
        case missingSavedDate
        case bothDatesNotSet
    }
    
    // Helper to reset shared state
    func resetSharedState() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        UserDefaults.standard.synchronize()
    }
    
    // Helper to create a mock SettingsManager
    func createMockSettings() -> SettingsManager {
        let settings = SettingsManager()
        settings.resetToDefaults()
        return settings
    }
    
    // Helper to create test container
    func createTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Home.self, configurations: config)
    }
    
    @Test("Test initialization")
    func testInitialization() async {
        resetSharedState()
        // Given
        let settings = createMockSettings()
        
        // When
        let manager = await ICloudSyncManager(settingsManager: settings)
        
        // Then
        #expect(await manager.isSyncing == false, "Should not be syncing initially")
        #expect(await manager.lastSyncDate == UserDefaults.standard.object(forKey: "LastiCloudSyncDate") as? Date, "Should load last sync date from UserDefaults")
    }
    
    @Test("Test settings manager update")
    func testSettingsManagerUpdate() async {
        resetSharedState()
        // Given
        let initialSettings = createMockSettings()
        let manager = await ICloudSyncManager(settingsManager: initialSettings)
        
        // When
        let newSettings = createMockSettings()
        newSettings.isPro = true
        await manager.setSettingsManager(newSettings)
        
        // Then
        await manager.syncNow()
        #expect(await manager.isSyncing == false, "Should complete sync")
    }
    
    @Test("Test sync state management")
    func testSyncStateManagement() async throws {
        // Given
        resetSharedState()
        let settings = createMockSettings()
        settings.isPro = true
        let manager = ICloudSyncManager(settingsManager: settings)
        
        // When - Trigger sync
        await manager.syncNow()
        
        // Wait for sync to complete and state to update
        var currentDate: Date?
        for _ in 0...5 {
            currentDate = await manager.lastSyncDate
            if currentDate != nil {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Then - Verify sync completed
        let isSyncing = await manager.isSyncing
        #expect(isSyncing == false, "Should complete sync")
        #expect(currentDate != nil, "Should have updated sync date")
        
        // Verify UserDefaults persistence
        if let syncDate = currentDate {
            let savedDate = UserDefaults.standard.object(forKey: "LastiCloudSyncDate") as? Date
            #expect(savedDate != nil, "Should persist sync date")
            if let saved = savedDate {
                #expect(abs(syncDate.timeIntervalSince(saved)) < 1.0, "Dates should match")
            }
        }
    }
    
    @Test("Test sync restrictions for non-pro users")
    func testSyncRestrictions() async {
        resetSharedState()
        // Given
        let settings = createMockSettings()
        settings.isPro = false
        let manager = await ICloudSyncManager(settingsManager: settings)
        
        // When
        await manager.syncNow()
        
        // Then
        #expect(await manager.isSyncing == false, "Should not sync for non-pro users")
    }
    
    @Test("Test context observer setup")
    func testContextObserverSetup() async throws {
        resetSharedState()
        // Given
        let settings = createMockSettings()
        settings.isPro = true
        let manager = await ICloudSyncManager(settingsManager: settings)
        let container = try createTestContainer()
        
        // When
        await manager.setupSync(modelContainer: container)
        
        // Then - Make a change to trigger observer
        let context = container.mainContext
        let home = Home(name: "Test Home")
        context.insert(home)
        try context.save()
        
        // Wait for sync
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        #expect(await manager.lastSyncDate != nil, "Should update last sync date after save")
    }
    
    @Test("Test observer cleanup")
    func testObserverCleanup() async throws {
        resetSharedState()
        // Given
        let settings = createMockSettings()
        let manager = await ICloudSyncManager(settingsManager: settings)
        let container = try createTestContainer()
        
        // First clear any existing subscription
        await manager.removeSubscription()
        
        // Capture initial sync date
        let initialSyncDate = await manager.lastSyncDate
        
        // When
        await manager.setupSync(modelContainer: container)
        await manager.removeSubscription()
        
        // Then - Make a change
        let context = container.mainContext
        let home = Home(name: "Test Home")
        context.insert(home)
        try context.save()
        
        // Wait to ensure no sync occurs
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then - Verify no sync occurred
        #expect(await manager.lastSyncDate == initialSyncDate, "Should not update last sync date after removing subscription")
        
        // Cleanup
        try context.delete(model: Home.self)
    }
    
    @Test("Test wait for sync behavior")
    func testWaitForSync() async throws {
        resetSharedState()
        // Given
        let settings = createMockSettings()
        settings.isPro = true
        let manager = await ICloudSyncManager(settingsManager: settings)
        
        // When
        let result = try await manager.waitForSync()
        
        // Then
        #expect(result == true, "Should complete sync operation")
    }
    
    @Test("Test last sync date persistence")
    func testLastSyncDatePersistence() async throws {
        // Given
        resetSharedState()
        let settings = createMockSettings()
        settings.isPro = true
        let manager = ICloudSyncManager(settingsManager: settings)
        
        // When - Trigger sync and wait for completion
        await manager.syncNow()
        
        var currentDate: Date?
        for _ in 0...5 {
            currentDate = await manager.lastSyncDate
            if currentDate != nil {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Then - Verify dates
        let persistedDate = UserDefaults.standard.object(forKey: "LastiCloudSyncDate") as? Date
        #expect(currentDate != nil, "Should have a sync date")
        #expect(persistedDate != nil, "Should have persisted date")
        
        if let syncDate = currentDate, let savedDate = persistedDate {
            #expect(abs(syncDate.timeIntervalSince(savedDate)) < 1.0, "Dates should match")
        }
    }
}
