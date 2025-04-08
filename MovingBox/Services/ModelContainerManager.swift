import SwiftData
import Foundation

@MainActor
class ModelContainerManager: ObservableObject {
    static let shared = ModelContainerManager()
    
    @Published private(set) var container: ModelContainer
    
    private let schema = Schema([
        InventoryLabel.self,
        InventoryItem.self,
        InventoryLocation.self,
        InsurancePolicy.self,
        Home.self
    ])
    
    private init() {
        // Initialize container with a default configuration (no iCloud)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("Disable-Persistence"),
            allowsSave: true,
            cloudKitDatabase: .none
        )
        
        do {
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    func createContainer(isPro: Bool, iCloudEnabled: Bool) throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("Disable-Persistence"),
            allowsSave: true,
            cloudKitDatabase: (isPro && iCloudEnabled) ? .automatic : .none
        )
        
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
    
    func updateContainer(isPro: Bool, iCloudEnabled: Bool) {
        do {
            // Create new container with updated configuration
            let newContainer = try createContainer(isPro: isPro, iCloudEnabled: iCloudEnabled)
            
            // Update the published container
            self.container = newContainer
            
            // Update iCloud sync manager if needed
            if isPro && iCloudEnabled {
                ICloudSyncManager.shared.setupSync(modelContainer: newContainer)
            } else {
                ICloudSyncManager.shared.removeSubscription()
            }
        } catch {
            print("Error updating container: \(error)")
        }
    }
}
