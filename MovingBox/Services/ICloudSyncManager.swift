import Foundation
import SwiftData
import CloudKit

@MainActor
class ICloudSyncManager: ObservableObject {
    static let shared = ICloudSyncManager()
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date? {
        didSet {
            if let date = lastSyncDate {
                UserDefaults.standard.set(date, forKey: "LastiCloudSyncDate")
            }
        }
    }
    
    private var modelContainer: ModelContainer?
    private weak var settingsManager: SettingsManager?
    private var subscription: NSObjectProtocol?
    
    init(settingsManager: SettingsManager? = nil) {
        self.settingsManager = settingsManager
        // Load last sync date from UserDefaults
        self.lastSyncDate = UserDefaults.standard.object(forKey: "LastiCloudSyncDate") as? Date
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
    
    func setupSync(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        setupContextObserver()
    }
    
    func setupContextObserver() {
        guard subscription == nil else { return }
        
        subscription = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: modelContainer?.mainContext,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("SwiftData context saved, updating sync date")
                await self?.updateLastSyncDate()
            }
        }
    }
    
    func removeCloudKitSubscription() {
        if let subscription = subscription {
            NotificationCenter.default.removeObserver(subscription)
            self.subscription = nil
        }
    }
    
    func syncNow() async {
        guard settingsManager?.isPro == true else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            try modelContainer?.mainContext.save()
            print("Manual sync completed, updating sync date")
            await updateLastSyncDate()
        } catch {
            print("Error synchronizing with iCloud: \(error)")
        }
    }
    
    private func updateLastSyncDate() async {
        let now = Date()
        lastSyncDate = now
        print("Updated last sync date to: \(now)")
    }
}
