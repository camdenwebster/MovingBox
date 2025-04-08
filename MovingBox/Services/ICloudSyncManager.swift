import Foundation
import SwiftData
import CloudKit
import UIKit

@MainActor
class ICloudSyncManager: ObservableObject {
    static let shared = ICloudSyncManager(settingsManager: nil)
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date? {
        didSet {
            if let date = lastSyncDate {
                UserDefaults.standard.set(date, forKey: "LastiCloudSyncDate")
            }
        }
    }
    
    private var modelContainer: ModelContainer?
    private var settingsManager: SettingsManager?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    nonisolated private let cleanupQueue = DispatchQueue(label: "com.movingbox.cleanup")
    nonisolated private let cleanupLock = NSLock()
    
    private actor SyncState {
        var subscription: NSObjectProtocol?
        var syncDebounceTimer: Timer?
        
        func cleanup() {
            if let sub = subscription {
                NotificationCenter.default.removeObserver(sub)
                subscription = nil
            }
            syncDebounceTimer?.invalidate()
            syncDebounceTimer = nil
        }
        
        func setSubscription(_ sub: NSObjectProtocol?) {
            subscription = sub
        }
        
        func setTimer(_ timer: Timer?) {
            syncDebounceTimer?.invalidate()
            syncDebounceTimer = timer
        }
    }
    
    private let syncState = SyncState()
    private var pendingChanges = false
    
    init(settingsManager: SettingsManager?) {
        self.settingsManager = settingsManager
        self.lastSyncDate = UserDefaults.standard.object(forKey: "LastiCloudSyncDate") as? Date
    }
    
    func checkICloudStatus() {
        CKContainer.default().accountStatus { [weak self] status, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if status == .available {
                    print("iCloud is available")
                    await self.syncNow()
                } else {
                    print("iCloud is not available: \(status.rawValue)")
                }
            }
        }
    }
    
    func setSettingsManager(_ manager: SettingsManager) {
        self.settingsManager = manager
        
        // If settings change indicates sync should be enabled, check iCloud status
        if manager.isPro && manager.iCloudEnabled {
            checkICloudStatus()
        }
    }
    
    func setupSync(modelContainer: ModelContainer) {
        print("Setting up sync with model container")
        self.modelContainer = modelContainer
        setupContextObserver()
        setupBackgroundSync()
    }
    
    private func setupContextObserver() {
        Task {
            guard await syncState.subscription == nil else { return }
            print("Setting up context observer")
            
            let newSubscription = NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                
                Task { @MainActor in
                    print("Context did save notification received")
                    self.handleContextChange()
                }
            }
            
            await syncState.setSubscription(newSubscription)
        }
    }
    
    private func setupBackgroundSync() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppTransition),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppTransition),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAppTransition() {
        Task {
            await performBackgroundSync()
        }
    }
    
    private func performBackgroundSync() async {
        // Start background task before sync
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Perform sync
        await syncNow()
        
        // End background task after sync
        endBackgroundTask()
    }
    
    private nonisolated func endBackgroundTask() {
        Task { @MainActor in
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
    }
    
    func disableSync() {
        Task {
            // First remove all observers
            NotificationCenter.default.removeObserver(self)
            
            // Then cleanup sync state
            await syncState.cleanup()
            
            // Finally clear the model container
            modelContainer = nil
            print("iCloud sync disabled")
        }
    }
    
    private func handleContextChange() {
        guard let settingsManager = settingsManager,
              settingsManager.isPro && settingsManager.iCloudEnabled else {
            return
        }
        
        pendingChanges = true
        
        Task {
            await syncState.setTimer(nil)
            
            let newTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                
                Task { @MainActor in
                    await self.performDebouncedSync()
                }
            }
            
            await syncState.setTimer(newTimer)
        }
    }
    
    private func performDebouncedSync() async {
        guard pendingChanges else { return }
        pendingChanges = false
        await syncNow()
    }
    
    func syncNow() async {
        print("syncNow called")
        guard let settingsManager = settingsManager else {
            print("Sync cancelled - no settings manager available")
            return
        }
        
        guard settingsManager.isPro && settingsManager.iCloudEnabled else {
            print("Sync cancelled - user is not Pro or iCloud is disabled")
            return
        }
        
        guard !isSyncing else {
            print("Sync already in progress")
            return
        }
        
        guard modelContainer != nil else {
            print("Sync cancelled - no model container available")
            return
        }
        
        isSyncing = true
        defer {
            isSyncing = false
            print("Sync completed at: \(Date())")
        }
        
        do {
            guard let context = modelContainer?.mainContext else {
                print("No model context available")
                return
            }
            
            print("Attempting to save context")
            try context.save()
            print("Context saved successfully")
            await updateLastSyncDate()
        } catch {
            print("Error synchronizing with iCloud: \(error)")
        }
    }
    
    func waitForSync() async throws -> Bool {
        return await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { [weak self] status, error in
                guard let self = self else {
                    continuation.resume(returning: true)
                    return
                }
                
                Task { @MainActor in
                    if status == .available {
                        if let settingsManager = self.settingsManager,
                           settingsManager.isPro && settingsManager.iCloudEnabled {
                            await self.syncNow()
                        }
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: true)
                    }
                }
            }
        }
    }
    
    private func updateLastSyncDate() async {
        print("Updating last sync date")
        let now = Date()
        lastSyncDate = now
        print("Updated last sync date to: \(now)")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
        
        let semaphore = DispatchSemaphore(value: 0)
        let state = syncState
        
        cleanupQueue.async {
            Task { @MainActor in
                await state.cleanup()
                semaphore.signal()
            }
        }
        
        _ = semaphore.wait(timeout: .now() + 5.0)
    }
}
