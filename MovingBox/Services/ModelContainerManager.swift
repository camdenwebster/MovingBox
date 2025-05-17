import SwiftData
import Foundation

@MainActor
class ModelContainerManager: ObservableObject {
    static let shared = ModelContainerManager()
    
    @Published private(set) var container: ModelContainer
    @Published private(set) var isLoading = true
    
    private init() {
        let schema = Schema([
            Home.self,
            InsurancePolicy.self,
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self
        ])
        
        self.container = try! ModelContainer(for: schema)
    }
    
    func initialize() async {
        // Give time for the UI to show splash screen
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isLoading = false
    }
}
