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
            cloudKitDatabase: CloudManager.shared.isAvailable ? .automatic : .none
        )
        
        do {
            self.container = try ModelContainer(for: schema, configurations: [configuration])
            print("📦 ModelContainerManager - Created container with CloudKit \(CloudManager.shared.isAvailable ? "enabled" : "disabled")")
        } catch {
            print("📦 ModelContainerManager - Fatal error creating container: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    init(testContainer: ModelContainer) {
        self.container = testContainer
        self.isLoading = false
    }
    
    func initialize() async {
        do {
            // Migrate all models before completing initialization
            try await migrateHomes()
            try await migrateLocations()
            try await migrateInventoryItems()
            
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
    
    internal func migrateHomes() async throws {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Home>()
        
        let homes = try context.fetch(descriptor)
        print("📦 ModelContainerManager - Beginning migration for \(homes.count) homes")
        
        for home in homes {
            do {
                try await home.migrateImageIfNeeded()
                try context.save()
            } catch {
                print("📦 ModelContainerManager - Failed to migrate home \(home.name): \(error)")
            }
        }
        
        print("📦 ModelContainerManager - Completed home migrations")
    }
    
    internal func migrateLocations() async throws {
        let context = container.mainContext
        let descriptor = FetchDescriptor<InventoryLocation>()
        
        let locations = try context.fetch(descriptor)
        print("📦 ModelContainerManager - Beginning migration for \(locations.count) locations")
        
        for location in locations {
            do {
                try await location.migrateImageIfNeeded()
                try context.save()
            } catch {
                print("📦 ModelContainerManager - Failed to migrate location \(location.name): \(error)")
            }
        }
        
        print("📦 ModelContainerManager - Completed location migrations")
    }
    
    internal func migrateInventoryItems() async throws {
        let context = container.mainContext
        let descriptor = FetchDescriptor<InventoryItem>()
        
        let items = try context.fetch(descriptor)
        print("📦 ModelContainerManager - Beginning migration for \(items.count) inventory items")
        
        for item in items {
            do {
                try await item.migrateImageIfNeeded()
                try context.save()
            } catch {
                print("📦 ModelContainerManager - Failed to migrate inventory item \(item.title): \(error)")
            }
        }
        
        print("📦 ModelContainerManager - Completed inventory item migrations")
    }
}
