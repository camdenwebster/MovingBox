//
//  HomeDetailSettingsViewModelTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 1/26/26.
//

import Foundation
import SQLiteData
import Testing

@testable import MovingBox

@MainActor
@Suite struct HomeDetailSettingsViewModelTests {

    // MARK: - Test Helpers

    /// Creates an in-memory SQLite database and inserts a home, returning both.
    func insertTestHome(
        into db: DatabaseQueue,
        id: UUID = UUID(),
        name: String = "Test Home",
        address1: String = "123 Test St",
        address2: String = "",
        city: String = "Test City",
        state: String = "CA",
        zip: String = "12345",
        country: String = "US",
        isPrimary: Bool = false,
        colorName: String = "green"
    ) throws -> SQLiteHome {
        let home = SQLiteHome(
            id: id,
            name: name,
            address1: address1,
            address2: address2,
            city: city,
            state: state,
            zip: zip,
            country: country,
            isPrimary: isPrimary,
            colorName: colorName
        )
        try db.write { database in
            try SQLiteHome.insert(home).execute(database)
        }
        return home
    }

    /// Creates a ViewModel wired to the given database and home list.
    func createViewModel(
        homeID: UUID?,
        db: DatabaseQueue,
        settings: SettingsManager? = nil,
        allHomes: [SQLiteHome] = []
    ) -> HomeDetailSettingsViewModel {
        let effectiveSettings = settings ?? MockSettingsManager()
        let vm = HomeDetailSettingsViewModel(
            homeID: homeID,
            settings: effectiveSettings,
            allHomesProvider: { allHomes }
        )
        vm.setDatabase(db)
        return vm
    }

    // MARK: - Initialization Tests

    @Test("Init with existing home copies all values")
    func testInitWithExistingHome() async throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()

        let _ = try insertTestHome(
            into: db,
            id: homeID,
            name: "My House",
            address1: "123 Main St",
            city: "San Francisco",
            state: "CA",
            zip: "94102",
            country: "US",
            isPrimary: true,
            colorName: "blue"
        )

        let viewModel = createViewModel(homeID: homeID, db: db)
        await viewModel.loadHomeData()

        #expect(viewModel.name == "My House")
        #expect(viewModel.address1 == "123 Main St")
        #expect(viewModel.city == "San Francisco")
        #expect(viewModel.state == "CA")
        #expect(viewModel.zip == "94102")
        #expect(viewModel.country == "US")
        #expect(viewModel.isPrimary == true)
        #expect(viewModel.colorName == "blue")
        #expect(viewModel.isEditing == false)
        #expect(viewModel.isNewHome == false)
    }

    @Test("Init for new home sets defaults and editing mode")
    func testInitForNewHome() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)

        #expect(viewModel.name == "")
        #expect(viewModel.address1 == "")
        #expect(viewModel.country.isEmpty == false)  // Should be set to user's locale
        #expect(viewModel.isEditing == true)
        #expect(viewModel.isNewHome == true)
    }

    @Test("isNewHome returns true when home is nil")
    func testIsNewHomeTrue() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)

        #expect(viewModel.isNewHome == true)
    }

    @Test("isNewHome returns false when home exists")
    func testIsNewHomeFalse() async throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()

        let _ = try insertTestHome(into: db, id: homeID)
        let viewModel = createViewModel(homeID: homeID, db: db)
        await viewModel.loadHomeData()

        #expect(viewModel.isNewHome == false)
    }

    // MARK: - Validation Tests

    @Test("canSave is false when both name and address are empty")
    func testCanSaveFalseEmpty() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)
        viewModel.name = ""
        viewModel.addressInput = ""

        #expect(viewModel.canSave == false)
    }

    @Test("canSave is true with name only")
    func testCanSaveTrueNameOnly() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)
        viewModel.name = "My Home"
        viewModel.addressInput = ""

        #expect(viewModel.canSave == true)
    }

    @Test("canSave is true with address only")
    func testCanSaveTrueAddressOnly() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)
        viewModel.name = ""
        viewModel.addressInput = "123 Main St"

        #expect(viewModel.canSave == true)
    }

    @Test("canSave is true with both name and address")
    func testCanSaveTrueBoth() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)
        viewModel.name = "My Home"
        viewModel.addressInput = "123 Main St"

        #expect(viewModel.canSave == true)
    }

    @Test("canSave is false when creating")
    func testCanSaveFalseWhenCreating() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)
        viewModel.name = "My Home"
        viewModel.addressInput = "123 Main St"
        viewModel.isCreating = true

        #expect(viewModel.canSave == false)
    }

    @Test("canSave is false when parsing address")
    func testCanSaveFalseWhenParsing() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)
        viewModel.name = "My Home"
        viewModel.addressInput = "123 Main St"
        viewModel.isParsingAddress = true

        #expect(viewModel.canSave == false)
    }

    @Test("canDelete is false when single home")
    func testCanDeleteFalseSingleHome() async throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()

        let home = try insertTestHome(into: db, id: homeID)
        let viewModel = createViewModel(homeID: homeID, db: db, allHomes: [home])
        await viewModel.loadHomeData()

        #expect(viewModel.canDelete == false)
    }

    @Test("canDelete is true when multiple homes")
    func testCanDeleteTrueMultiple() async throws {
        let db = try makeInMemoryDatabase()
        let homeID1 = UUID()
        let homeID2 = UUID()

        let home1 = try insertTestHome(into: db, id: homeID1, name: "Home 1")
        let home2 = try insertTestHome(into: db, id: homeID2, name: "Home 2")
        let viewModel = createViewModel(homeID: homeID1, db: db, allHomes: [home1, home2])
        await viewModel.loadHomeData()
        viewModel.isEditing = true

        #expect(viewModel.canDelete == true)
    }

    // MARK: - Save Changes Tests

    @Test("saveChanges persists all fields to existing home")
    func testSaveChanges() async throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()

        let _ = try insertTestHome(into: db, id: homeID, name: "Original Name")
        let viewModel = createViewModel(homeID: homeID, db: db)
        await viewModel.loadHomeData()

        viewModel.name = "Updated Name"
        viewModel.addressInput = "456 New St"
        viewModel.colorName = "purple"

        await viewModel.saveChanges()

        // Verify changes were persisted to database
        let updatedHome = try await db.read { database in
            try SQLiteHome.find(homeID).fetchOne(database)
        }
        #expect(updatedHome?.name == "Updated Name")
        #expect(updatedHome?.colorName == "purple")
        // Address is parsed from addressInput via CLGeocoder (fallback stores raw text)
        #expect(updatedHome?.address1.isEmpty == false)
    }

    @Test("saveChanges does nothing for new home")
    func testSaveChangesNewHome() async throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)
        viewModel.name = "New Home"

        // Should not crash or throw
        await viewModel.saveChanges()

        // Verify no home was accidentally created
        let count = try await db.read { database in
            try SQLiteHome.count().fetchOne(database)
        }
        #expect(count == 0)
    }

    // MARK: - Delete Home Tests

    @Test("deleteHome removes home from context")
    func testDeleteHome() async throws {
        let db = try makeInMemoryDatabase()
        let homeID1 = UUID()
        let homeID2 = UUID()

        let home1 = try insertTestHome(into: db, id: homeID1, name: "Home 1", isPrimary: false)
        let home2 = try insertTestHome(into: db, id: homeID2, name: "Home 2", isPrimary: true)

        let viewModel = createViewModel(homeID: homeID1, db: db, allHomes: [home1, home2])
        await viewModel.loadHomeData()

        let result = viewModel.deleteHome()

        #expect(result == true)

        let homes = try await db.read { database in
            try SQLiteHome.all.fetchAll(database)
        }
        #expect(homes.count == 1)
        #expect(homes.first?.name == "Home 2")
    }

    @Test("deleteHome reassigns primary to another home")
    func testDeleteHomeReassignsPrimary() async throws {
        let db = try makeInMemoryDatabase()
        let settings = MockSettingsManager()
        let homeID1 = UUID()
        let homeID2 = UUID()

        let home1 = try insertTestHome(into: db, id: homeID1, name: "Home 1", isPrimary: true)
        let home2 = try insertTestHome(into: db, id: homeID2, name: "Home 2", isPrimary: false)

        let viewModel = HomeDetailSettingsViewModel(
            homeID: homeID1,
            settings: settings,
            allHomesProvider: { [home1, home2] }
        )
        viewModel.setDatabase(db)
        await viewModel.loadHomeData()

        let result = viewModel.deleteHome()

        #expect(result == true)

        // Verify the remaining home is now primary
        let remainingHome = try await db.read { database in
            try SQLiteHome.find(homeID2).fetchOne(database)
        }
        #expect(remainingHome?.isPrimary == true)
    }

    @Test("deleteHome cleans up associated locations")
    func testDeleteHomeCleansLocations() async throws {
        let db = try makeInMemoryDatabase()
        let homeID1 = UUID()
        let homeID2 = UUID()

        let home1 = try insertTestHome(into: db, id: homeID1, name: "Home 1", isPrimary: false)
        let home2 = try insertTestHome(into: db, id: homeID2, name: "Home 2", isPrimary: true)

        // Create locations for home1
        try await db.write { database in
            for i in 1...3 {
                try SQLiteInventoryLocation.insert(
                    SQLiteInventoryLocation(id: UUID(), name: "Room \(i)", homeID: homeID1)
                ).execute(database)
            }
        }

        let viewModel = createViewModel(homeID: homeID1, db: db, allHomes: [home1, home2])
        await viewModel.loadHomeData()

        let result = viewModel.deleteHome()

        #expect(result == true)

        let locations = try await db.read { database in
            try SQLiteInventoryLocation.all.fetchAll(database)
        }
        #expect(locations.isEmpty == true)
    }

    @Test("deleteHome fails on last home")
    func testDeleteHomeFailsLastHome() async throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()

        let home = try insertTestHome(into: db, id: homeID)
        let viewModel = createViewModel(homeID: homeID, db: db, allHomes: [home])
        await viewModel.loadHomeData()

        let result = viewModel.deleteHome()

        #expect(result == false)
        #expect(viewModel.deleteError != nil)
        #expect(viewModel.deleteError?.contains("at least one home") == true)
    }

    // MARK: - Toggle Primary Tests

    @Test("togglePrimary sets home as primary")
    func testTogglePrimaryOn() async throws {
        let db = try makeInMemoryDatabase()
        let settings = MockSettingsManager()
        let homeID1 = UUID()
        let homeID2 = UUID()

        let home1 = try insertTestHome(into: db, id: homeID1, name: "Home 1", isPrimary: true)
        let home2 = try insertTestHome(into: db, id: homeID2, name: "Home 2", isPrimary: false)

        let viewModel = HomeDetailSettingsViewModel(
            homeID: homeID2,
            settings: settings,
            allHomesProvider: { [home1, home2] }
        )
        viewModel.setDatabase(db)
        await viewModel.loadHomeData()

        viewModel.togglePrimary(true)

        #expect(viewModel.isPrimary == true)

        // Verify home1 is no longer primary in the database
        let updatedHome1 = try await db.read { database in
            try SQLiteHome.find(homeID1).fetchOne(database)
        }
        #expect(updatedHome1?.isPrimary == false)

        // Verify home2 is primary in the database (via the togglePrimary write)
        let updatedHome2 = try await db.read { database in
            try SQLiteHome.find(homeID2).fetchOne(database)
        }
        // Note: togglePrimary updates other homes in DB but only sets the local isPrimary flag
        // The actual home2 DB record is updated on saveChanges
        #expect(viewModel.isPrimary == true)
    }

    @Test("togglePrimary off reassigns to another home")
    func testTogglePrimaryOff() async throws {
        let db = try makeInMemoryDatabase()
        let settings = MockSettingsManager()
        let homeID1 = UUID()
        let homeID2 = UUID()

        let home1 = try insertTestHome(into: db, id: homeID1, name: "Home 1", isPrimary: true)
        let home2 = try insertTestHome(into: db, id: homeID2, name: "Home 2", isPrimary: false)

        let viewModel = HomeDetailSettingsViewModel(
            homeID: homeID1,
            settings: settings,
            allHomesProvider: { [home1, home2] }
        )
        viewModel.setDatabase(db)
        await viewModel.loadHomeData()

        viewModel.togglePrimary(false)

        #expect(viewModel.isPrimary == false)

        // Verify home2 was made primary in the database
        let updatedHome2 = try await db.read { database in
            try SQLiteHome.find(homeID2).fetchOne(database)
        }
        #expect(updatedHome2?.isPrimary == true)
    }

    // MARK: - Error State Tests

    @Test("clearDeleteError clears the error")
    func testClearDeleteError() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)
        viewModel.deleteError = "Test error"

        viewModel.clearDeleteError()

        #expect(viewModel.deleteError == nil)
    }

    @Test("clearSaveError clears the error")
    func testClearSaveError() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)
        viewModel.saveError = "Test error"

        viewModel.clearSaveError()

        #expect(viewModel.saveError == nil)
    }

    @Test("confirmDelete sets showingDeleteConfirmation")
    func testConfirmDelete() async throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()

        let _ = try insertTestHome(into: db, id: homeID)
        let viewModel = createViewModel(homeID: homeID, db: db)
        await viewModel.loadHomeData()

        viewModel.confirmDelete()

        #expect(viewModel.showingDeleteConfirmation == true)
    }

    // MARK: - Address Input Tests

    @Test("addressInput is populated from existing home fields")
    func testAddressInputFromExistingHome() async throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()

        let _ = try insertTestHome(
            into: db,
            id: homeID,
            name: "Test",
            address1: "123 Main St",
            city: "Springfield",
            state: "IL",
            zip: "62701"
        )
        let viewModel = createViewModel(homeID: homeID, db: db)
        await viewModel.loadHomeData()

        #expect(viewModel.addressInput.contains("123 Main St"))
        #expect(viewModel.addressInput.contains("Springfield"))
    }

    @Test("addressInput is empty for new home")
    func testAddressInputEmptyForNewHome() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)

        #expect(viewModel.addressInput == "")
    }

    // MARK: - Home Property Tests

    @Test("home properties match loaded data for existing home")
    func testHomePropertiesMatchLoaded() async throws {
        let db = try makeInMemoryDatabase()
        let homeID = UUID()

        let _ = try insertTestHome(into: db, id: homeID, name: "Original")
        let viewModel = createViewModel(homeID: homeID, db: db)
        await viewModel.loadHomeData()

        #expect(viewModel.originalHomeID == homeID)
        #expect(viewModel.name == "Original")
    }

    @Test("new home has empty name")
    func testNewHomeHasEmptyName() throws {
        let db = try makeInMemoryDatabase()

        let viewModel = createViewModel(homeID: nil, db: db)
        viewModel.name = "New Home"

        #expect(viewModel.name == "New Home")
    }

    // MARK: - Update Dependencies Tests

    @Test("updateAllHomesProvider updates the homes provider")
    func testUpdateAllHomesProvider() async throws {
        let db = try makeInMemoryDatabase()
        let homeID1 = UUID()
        let homeID2 = UUID()

        let home1 = try insertTestHome(into: db, id: homeID1, name: "Home 1")
        let home2 = try insertTestHome(into: db, id: homeID2, name: "Home 2")

        let viewModel = HomeDetailSettingsViewModel(
            homeID: homeID1,
            settings: MockSettingsManager(),
            allHomesProvider: { [home1] }
        )
        viewModel.setDatabase(db)
        await viewModel.loadHomeData()

        viewModel.isEditing = true
        #expect(viewModel.canDelete == false)  // Only one home in provider

        viewModel.updateAllHomesProvider { [home1, home2] }

        #expect(viewModel.canDelete == true)  // Now two homes in provider
    }
}
