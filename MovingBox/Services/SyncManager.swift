//
//  SyncManager.swift
//  MovingBox
//
//  Created by Camden Webster on 6/22/25.
//

import Foundation
import SwiftData
import BackgroundTasks

/// Central coordinator for all sync operations across different sync services
@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    // MARK: - Published Properties
    
    @Published var currentSyncService: SyncServiceType = .icloud
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isConfigured: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var syncProgress: Double = 0.0
    @Published var pendingSyncCount: Int = 0
    
    // MARK: - Private Properties
    
    private var activeSyncService: (any SyncService)?
    private var iCloudSyncService: (any SyncService)?
    private var homeBoxSyncService: (any SyncService)?
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private var backgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    
    // MARK: - Sync Queue
    
    private var syncQueue: [SyncOperation] = []
    private var isSyncing: Bool = false
    
    // MARK: - Notification Names
    
    static let syncDidStart = Notification.Name("SyncDidStart")
    static let syncDidComplete = Notification.Name("SyncDidComplete")
    static let syncDidFail = Notification.Name("SyncDidFail")
    static let syncServiceDidChange = Notification.Name("SyncServiceDidChange")
    
    // MARK: - Initialization
    
    private init() {
        loadSyncConfiguration()
        setupBackgroundSync()
    }
    
    // MARK: - Configuration
    
    /// Configure the sync manager with the specified service type
    func configureSyncService(_ serviceType: SyncServiceType) async throws {
        print("🔄 SyncManager - Configuring sync service: \(serviceType)")
        
        guard serviceType != currentSyncService else {
            print("🔄 SyncManager - Service type unchanged, skipping configuration")
            return
        }
        
        // Store the new service type
        let previousService = currentSyncService
        currentSyncService = serviceType
        
        // Update active sync service
        try await updateActiveSyncService()
        
        // Save configuration
        saveSyncConfiguration()
        
        // Notify observers
        NotificationCenter.default.post(name: Self.syncServiceDidChange, object: self, userInfo: [
            "previousService": previousService,
            "newService": serviceType
        ])
        
        print("🔄 SyncManager - Successfully configured sync service: \(serviceType)")
    }
    
    /// Update the active sync service based on current configuration
    private func updateActiveSyncService() async throws {
        switch currentSyncService {
        case .icloud:
            if iCloudSyncService == nil {
                // iCloudSyncService = CloudKitSyncService() // To be implemented
                print("⚠️ SyncManager - iCloud sync service not yet implemented")
            }
            activeSyncService = iCloudSyncService
            
        case .homebox:
            if homeBoxSyncService == nil {
                // homeBoxSyncService = HomeBoxSyncService() // To be implemented
                print("⚠️ SyncManager - HomeBox sync service not yet implemented")
            }
            activeSyncService = homeBoxSyncService
        }
        
        // Update status based on active service
        updateSyncStatus()
    }
    
    /// Update sync status based on active service state
    private func updateSyncStatus() {
        Task {
            if let service = activeSyncService {
                isConfigured = await service.isConfigured
                isAuthenticated = await service.isAuthenticated
                syncStatus = await service.syncStatus
            } else {
                isConfigured = false
                isAuthenticated = false
                syncStatus = .idle
            }
        }
    }
    
    // MARK: - Sync Operations
    
    /// Perform a full sync with the active sync service
    func performFullSync() async throws {
        guard let service = activeSyncService else {
            throw SyncError.notConfigured
        }
        
        guard !isSyncing else {
            print("🔄 SyncManager - Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        syncStatus = .syncing(progress: 0.0)
        
        // Post sync start notification
        NotificationCenter.default.post(name: Self.syncDidStart, object: self)
        
        // Start background task
        beginBackgroundTask()
        
        do {
            print("🔄 SyncManager - Starting full sync with \(currentSyncService.displayName)")
            
            // Perform the sync
            try await service.fullSync()
            
            // Update last sync date
            lastSyncDate = Date()
            
            // Clear pending sync count
            pendingSyncCount = 0
            
            // Update status
            syncStatus = .completed(at: Date())
            
            print("🔄 SyncManager - Full sync completed successfully")
            
            // Post success notification
            NotificationCenter.default.post(name: Self.syncDidComplete, object: self)
            
        } catch {
            print("⚠️ SyncManager - Sync failed: \(error)")
            syncStatus = .failed(error: error as? SyncError ?? .unknownError(error))
            
            // Post failure notification
            NotificationCenter.default.post(name: Self.syncDidFail, object: self, userInfo: ["error": error])
            
            throw error
        }
        
        isSyncing = false
        endBackgroundTask()
    }
    
    /// Queue a sync operation for later execution
    func queueSyncOperation<T: Syncable>(_ operation: SyncOperationType, for model: T) {
        let syncOp = SyncOperation(
            id: UUID(),
            type: operation,
            modelType: String(describing: T.self),
            modelId: model.id,
            timestamp: Date()
        )
        
        syncQueue.append(syncOp)
        pendingSyncCount = syncQueue.count
        
        print("🔄 SyncManager - Queued \(operation) operation for \(T.self)")
    }
    
    /// Process the sync queue
    func processSyncQueue() async throws {
        guard !syncQueue.isEmpty else { return }
        guard let service = activeSyncService else {
            throw SyncError.notConfigured
        }
        
        print("🔄 SyncManager - Processing \(syncQueue.count) queued sync operations")
        
        for operation in syncQueue {
            // Process each operation based on type
            // Implementation will depend on the specific sync service
            print("🔄 SyncManager - Processing \(operation.type) for \(operation.modelType)")
        }
        
        // Clear the queue
        syncQueue.removeAll()
        pendingSyncCount = 0
    }
    
    // MARK: - Background Sync
    
    /// Set up automatic background sync
    private func setupBackgroundSync() {
        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.movingbox.sync", using: nil) { task in
            Task {
                await self.handleBackgroundSync(task: task as! BGAppRefreshTask)
            }
        }
        
        // Start sync timer
        startSyncTimer()
    }
    
    /// Start the sync timer for regular sync operations
    private func startSyncTimer() {
        stopSyncTimer()
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            Task { @MainActor in
                do {
                    try await self.performIncrementalSync()
                } catch {
                    print("⚠️ SyncManager - Scheduled sync failed: \(error)")
                }
            }
        }
        
        print("🔄 SyncManager - Started sync timer with \(syncInterval)s interval")
    }
    
    /// Stop the sync timer
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    /// Perform incremental sync (only changed items)
    private func performIncrementalSync() async throws {
        guard isAuthenticated && isConfigured else { return }
        guard !isSyncing else { return }
        
        // Only sync if there are pending changes
        guard pendingSyncCount > 0 else { return }
        
        print("🔄 SyncManager - Performing incremental sync")
        try await processSyncQueue()
    }
    
    /// Handle background sync task
    private func handleBackgroundSync(task: BGAppRefreshTask) async {
        // Schedule next background refresh
        scheduleBackgroundSync()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        do {
            try await performIncrementalSync()
            task.setTaskCompleted(success: true)
        } catch {
            print("⚠️ SyncManager - Background sync failed: \(error)")
            task.setTaskCompleted(success: false)
        }
    }
    
    /// Schedule next background sync
    private func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.movingbox.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: syncInterval)
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "MovingBoxSync") {
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
        }
    }
    
    // MARK: - Configuration Persistence
    
    private func loadSyncConfiguration() {
        let serviceTypeString = UserDefaults.standard.string(forKey: "syncServiceType") ?? SyncServiceType.icloud.rawValue
        currentSyncService = SyncServiceType(rawValue: serviceTypeString) ?? .icloud
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        
        print("🔄 SyncManager - Loaded configuration: \(currentSyncService)")
    }
    
    private func saveSyncConfiguration() {
        UserDefaults.standard.set(currentSyncService.rawValue, forKey: "syncServiceType")
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
        
        print("🔄 SyncManager - Saved configuration: \(currentSyncService)")
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopSyncTimer()
        endBackgroundTask()
    }
}

// MARK: - Supporting Types

/// Represents a sync operation in the queue
struct SyncOperation: Identifiable {
    let id: UUID
    let type: SyncOperationType
    let modelType: String
    let modelId: UUID
    let timestamp: Date
}

/// Types of sync operations
enum SyncOperationType: String, CaseIterable {
    case create
    case update
    case delete
    
    var displayName: String {
        switch self {
        case .create: return "Create"
        case .update: return "Update"
        case .delete: return "Delete"
        }
    }
}