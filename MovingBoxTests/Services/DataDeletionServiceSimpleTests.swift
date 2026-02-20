import Foundation
import SQLiteData
import Testing

@testable import MovingBox

@MainActor
struct DataDeletionServiceSimpleTests {

    @Test("DataDeletionService initializes correctly")
    func testInitialization() throws {
        let database = try makeInMemoryDatabase()
        let service = DataDeletionService(database: database)

        #expect(!service.isDeleting)
        #expect(service.lastError == nil)
        #expect(!service.deletionCompleted)
    }

    @Test("DataDeletionService deletes empty database successfully")
    func testDeleteEmptyDatabase() async throws {
        let database = try makeInMemoryDatabase()
        let service = DataDeletionService(database: database)

        await service.deleteAllData(scope: DeletionScope.localOnly)

        #expect(!service.isDeleting)
        #expect(service.lastError == nil)
        #expect(service.deletionCompleted)
    }

    @Test("DataDeletionService state management works correctly")
    func testStateManagement() async throws {
        let database = try makeInMemoryDatabase()
        let service = DataDeletionService(database: database)

        #expect(!service.isDeleting)
        #expect(!service.deletionCompleted)
        #expect(service.lastError == nil)

        await service.deleteAllData(scope: DeletionScope.localOnly)

        #expect(!service.isDeleting)
        #expect(service.deletionCompleted)
        #expect(service.lastError == nil)

        service.resetState()

        #expect(!service.deletionCompleted)
        #expect(service.lastError == nil)
    }
}
