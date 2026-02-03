import Foundation
import SwiftData
import Testing

@testable import MovingBox

@MainActor
struct DataDeletionServiceSimpleTests {

    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([
            InventoryItem.self, InventoryLocation.self, InventoryLabel.self,
            Home.self, InsurancePolicy.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("DataDeletionService initializes correctly")
    func testInitialization() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let database = try makeInMemoryDatabase()
        let service = DataDeletionService(modelContext: context, database: database)

        #expect(!service.isDeleting)
        #expect(service.lastError == nil)
        #expect(!service.deletionCompleted)
    }

    @Test("DataDeletionService deletes empty database successfully")
    func testDeleteEmptyDatabase() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let database = try makeInMemoryDatabase()
        let service = DataDeletionService(modelContext: context, database: database)

        // Perform deletion on empty database
        await service.deleteAllData(scope: DeletionScope.localOnly)

        // Should complete successfully even with no data
        #expect(!service.isDeleting)
        #expect(service.lastError == nil)
        #expect(service.deletionCompleted)
    }

    @Test("DataDeletionService state management works correctly")
    func testStateManagement() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let database = try makeInMemoryDatabase()
        let service = DataDeletionService(modelContext: context, database: database)

        // Initial state
        #expect(!service.isDeleting)
        #expect(!service.deletionCompleted)
        #expect(service.lastError == nil)

        // Perform deletion
        await service.deleteAllData(scope: DeletionScope.localOnly)

        // Final state
        #expect(!service.isDeleting)
        #expect(service.deletionCompleted)
        #expect(service.lastError == nil)

        // Reset state
        service.resetState()

        // Verify state is reset
        #expect(!service.deletionCompleted)
        #expect(service.lastError == nil)
    }
}
