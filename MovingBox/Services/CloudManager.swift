import CloudKit
import SwiftUI

@MainActor
class CloudManager: ObservableObject {
    static let shared = CloudManager()
    
    @Published private(set) var isAvailable = false
    @Published private(set) var error: Error?
    
    private init() {
        Task {
            await monitorCloudKitAvailability()
        }
    }
    
    private func monitorCloudKitAvailability() async {
        let container = CKContainer(identifier: "iCloud.com.mothersound.movingbox")
        
        do {
            let accountStatus = try await container.accountStatus()
            isAvailable = accountStatus == .available
            if !isAvailable {
                error = CloudError.unavailable(status: accountStatus)
            }
        } catch {
            self.error = error
            isAvailable = false
        }
        
        // Set up notification for changes
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.monitorCloudKitAvailability()
            }
        }
    }
}

extension CloudManager {
    enum CloudError: LocalizedError {
        case unavailable(status: CKAccountStatus)
        
        var errorDescription: String? {
            switch self {
            case .unavailable(let status):
                switch status {
                case .couldNotDetermine:
                    return "Could not determine iCloud status"
                case .restricted:
                    return "iCloud access is restricted"
                case .noAccount:
                    return "No iCloud account found"
                case .temporarilyUnavailable:
                    return "iCloud is temporarily unavailable"
                case .available:
                    return nil
                @unknown default:
                    return "Unknown iCloud status"
                }
            }
        }
    }
}