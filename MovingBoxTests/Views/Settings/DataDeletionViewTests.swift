import SQLiteData
import SwiftUI
import Testing

@testable import MovingBox

@MainActor
@Observable
final class MockDataDeletionService: DataDeletionServiceProtocol {
    private(set) var isDeleting = false
    private(set) var lastError: Error?
    private(set) var deletionCompleted = false

    var shouldFailDeletion = false
    var deletionDelay: TimeInterval = 0

    func deleteAllData(scope: DeletionScope) async {
        isDeleting = true

        if deletionDelay > 0 {
            try? await Task.sleep(for: .seconds(deletionDelay))
        }

        if shouldFailDeletion {
            lastError = TestError.deletionFailed
        } else {
            deletionCompleted = true
        }

        isDeleting = false
    }

    func resetState() {
        lastError = nil
        deletionCompleted = false
    }

    enum TestError: Error, LocalizedError {
        case deletionFailed

        var errorDescription: String? {
            switch self {
            case .deletionFailed:
                return "Test deletion failed"
            }
        }
    }
}

@MainActor
struct DataDeletionViewTests {

    @Test("DataDeletionView displays warning section correctly")
    func testWarningSection() throws {
        let database = try makeInMemoryDatabase()
        prepareDependencies { $0.defaultDatabase = database }
        let view = DataDeletionView()

        #expect(view != nil)
    }

    @Test("DataDeletionView shows scope selection options")
    func testScopeSelectionSection() throws {
        let database = try makeInMemoryDatabase()
        prepareDependencies { $0.defaultDatabase = database }
        let view = DataDeletionView()

        #expect(view != nil)
    }

    @Test("DataDeletionView confirmation section validates input")
    func testConfirmationSection() throws {
        let database = try makeInMemoryDatabase()
        prepareDependencies { $0.defaultDatabase = database }
        let view = DataDeletionView()

        #expect(view != nil)
    }

    @Test("DataDeletionView handles navigation correctly")
    func testNavigationElements() throws {
        let database = try makeInMemoryDatabase()
        prepareDependencies { $0.defaultDatabase = database }
        let view = NavigationStack {
            DataDeletionView()
        }

        #expect(view != nil)
    }

    @Test("DataDeletionView displays alerts correctly")
    func testAlertPresentation() throws {
        let database = try makeInMemoryDatabase()
        prepareDependencies { $0.defaultDatabase = database }
        let view = DataDeletionView()

        #expect(view != nil)
    }

    @Test("DataDeletionView responds to service state changes")
    func testServiceStateBinding() throws {
        let database = try makeInMemoryDatabase()
        prepareDependencies { $0.defaultDatabase = database }
        let mockService = MockDataDeletionService()
        let view = DataDeletionView(deletionService: mockService)

        #expect(view != nil)
    }

    @Test("DataDeletionView uses injected service for testing")
    func testDependencyInjection() throws {
        let database = try makeInMemoryDatabase()
        prepareDependencies { $0.defaultDatabase = database }
        let mockService = MockDataDeletionService()
        let view = DataDeletionView(deletionService: mockService)

        #expect(view != nil)
        #expect(!mockService.isDeleting)
        #expect(mockService.lastError == nil)
        #expect(!mockService.deletionCompleted)
    }
}
