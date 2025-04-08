import Foundation
import SwiftData
import CloudKit

@MainActor
class ICloudSyncManager: ObservableObject {
    static let shared = ICloudSyncManager(settingsManager: nil)
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date? {
        didSet {
            if let date = lastSyncDate {
                print("Setting last sync date in UserDefaults: \(date)")
                UserDefaults.standard.set(date, forKey: "LastiCloudSyncDate")
            }
        }
    }
    
    private var modelContainer: ModelContainer?
    private var settingsManager: SettingsManager?
    private var subscription: NSObjectProtocol?
    
    init(settingsManager: SettingsManager?) {
        self.settingsManager = settingsManager
        self.lastSyncDate = UserDefaults.standard.object(forKey: "LastiCloudSyncDate") as? Date
        print("ICloudSyncManager initialized with last sync date: \(String(describing: lastSyncDate))")
    }
    
    func checkICloudStatus() {
        CKContainer.default().accountStatus { status, error in
            Task { @MainActor in
                if status == .available {
                    print("iCloud is available")
                } else {
                    print("iCloud is not available: \(status.rawValue)")
                }
            }
        }
    }
    
    func setSettingsManager(_ manager: SettingsManager) {
        self.settingsManager = manager
    }
    
    func setupSync(modelContainer: ModelContainer) {
        print("Setting up sync with model container")
        self.modelContainer = modelContainer
        setupContextObserver()
    }
    
    func setupContextObserver() {
        guard subscription == nil else { return }
        print("Setting up context observer")
        
        let newSubscription = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("Context did save notification received")
                await self?.updateLastSyncDate()
            }
        }
        
        subscription = newSubscription
    }
    
    func removeSubscription() {
        if let sub = subscription {
            NotificationCenter.default.removeObserver(sub)
            subscription = nil
        }
    }
    
    func syncNow() async {
        print("syncNow called")
        guard let settingsManager = settingsManager else {
            print("Sync cancelled - no settings manager available")
            return
        }
        
        print("Pro status: \(settingsManager.isPro)") // Debug print
        guard settingsManager.isPro else {
            print("Sync cancelled - user is not Pro")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
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
        // First check if iCloud is even available
        return await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                Task { @MainActor in
                    if status == .available {
                        // Only attempt sync for Pro users with iCloud enabled
                        if let settingsManager = self.settingsManager, settingsManager.isPro {
                            await self.syncNow()
                        }
                        continuation.resume(returning: true)
                    } else {
                        // iCloud not available, that's ok - just continue
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
        if let sub = subscription {
            NotificationCenter.default.removeObserver(sub)
        }
    }
}
