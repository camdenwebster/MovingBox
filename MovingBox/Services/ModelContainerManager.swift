import SwiftData
import Foundation
import UIKit

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
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("Disable-Persistence"),
            allowsSave: true,
            cloudKitDatabase: .automatic
        )
        
        do {
            self.container = try ModelContainer(for: schema, configurations: [configuration])
            print("📦 ModelContainerManager - Created container with CloudKit enabled")
        } catch {
            print("📦 ModelContainerManager - Fatal error creating container: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    func initialize() async {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            print("Error during initialization: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
