import SwiftData
import Foundation

@MainActor
class ModelContainerManager: ObservableObject {
    static let shared = ModelContainerManager()
    
    @Published private(set) var container: ModelContainer
    @Published private(set) var isLoading = true
    
    private let schema = Schema([
        InventoryLabel.self,
        InventoryItem.self,
        InventoryLocation.self,
        InsurancePolicy.self,
        Home.self
    ])
    
    private init() {
        let isPro = UserDefaults.standard.bool(forKey: "isPro")
        let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudEnabled")
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("Disable-Persistence"),
            allowsSave: true,
            cloudKitDatabase: (isPro && iCloudEnabled) ? .automatic : .none
        )
        
        do {
            self.container = try ModelContainer(for: schema, configurations: [configuration])
            print("📦 ModelContainerManager - Created container with cloudKitDatabase: \(isPro && iCloudEnabled ? "automatic" : "none")")
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    func initialize() async {
        // Allow time for initial sync
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("Error during initialization: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
