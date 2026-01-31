//
//  HomeDetailSettingsViewModelTests.swift
//  MovingBoxTests
//
//  Created by Claude Code on 1/26/26.
//

import Foundation
import SwiftData
import Testing

@testable import MovingBox

@MainActor
@Suite struct HomeDetailSettingsViewModelTests {

    // MARK: - Test Helpers

    func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            Home.self,
            InventoryItem.self,
            InventoryLocation.self,
            InventoryLabel.self,
            InsurancePolicy.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func createContext(with container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    func createViewModel(
        home: Home?,
        context: ModelContext,
        settings: SettingsManager? = nil,
        allHomes: [Home] = []
    ) -> HomeDetailSettingsViewModel {
        let effectiveSettings = settings ?? MockSettingsManager()
        return HomeDetailSettingsViewModel(
            home: home,
            modelContext: context,
            settings: effectiveSettings,
            allHomesProvider: { allHomes }
        )
    }

    // MARK: - Initialization Tests

    @Test("Init with existing home copies all values")
    func testInitWithExistingHome() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home = Home.createTestHome(
            in: context,
            name: "My House",
            address1: "123 Main St",
            city: "San Francisco",
            state: "CA",
            zip: "94102",
            country: "US",
            isPrimary: true,
            colorName: "blue"
        )

        let viewModel = createViewModel(home: home, context: context)

        #expect(viewModel.tempHome.name == "My House")
        #expect(viewModel.tempHome.address1 == "123 Main St")
        #expect(viewModel.tempHome.city == "San Francisco")
        #expect(viewModel.tempHome.state == "CA")
        #expect(viewModel.tempHome.zip == "94102")
        #expect(viewModel.tempHome.country == "US")
        #expect(viewModel.tempHome.isPrimary == true)
        #expect(viewModel.tempHome.colorName == "blue")
        #expect(viewModel.isEditing == false)
        #expect(viewModel.isNewHome == false)
    }

    @Test("Init for new home sets defaults and editing mode")
    func testInitForNewHome() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)

        #expect(viewModel.tempHome.name == "")
        #expect(viewModel.tempHome.address1 == "")
        #expect(viewModel.tempHome.country.isEmpty == false)  // Should be set to user's locale
        #expect(viewModel.isEditing == true)
        #expect(viewModel.isNewHome == true)
    }

    @Test("isNewHome returns true when home is nil")
    func testIsNewHomeTrue() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)

        #expect(viewModel.isNewHome == true)
    }

    @Test("isNewHome returns false when home exists")
    func testIsNewHomeFalse() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home = Home.createTestHome(in: context)
        let viewModel = createViewModel(home: home, context: context)

        #expect(viewModel.isNewHome == false)
    }

    // MARK: - Validation Tests

    @Test("canSave is false when both name and address are empty")
    func testCanSaveFalseEmpty() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)
        viewModel.tempHome.name = ""
        viewModel.addressInput = ""

        #expect(viewModel.canSave == false)
    }

    @Test("canSave is true with name only")
    func testCanSaveTrueNameOnly() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)
        viewModel.tempHome.name = "My Home"
        viewModel.addressInput = ""

        #expect(viewModel.canSave == true)
    }

    @Test("canSave is true with address only")
    func testCanSaveTrueAddressOnly() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)
        viewModel.tempHome.name = ""
        viewModel.addressInput = "123 Main St"

        #expect(viewModel.canSave == true)
    }

    @Test("canSave is true with both name and address")
    func testCanSaveTrueBoth() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)
        viewModel.tempHome.name = "My Home"
        viewModel.addressInput = "123 Main St"

        #expect(viewModel.canSave == true)
    }

    @Test("canSave is false when creating")
    func testCanSaveFalseWhenCreating() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)
        viewModel.tempHome.name = "My Home"
        viewModel.addressInput = "123 Main St"
        viewModel.isCreating = true

        #expect(viewModel.canSave == false)
    }

    @Test("canSave is false when parsing address")
    func testCanSaveFalseWhenParsing() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)
        viewModel.tempHome.name = "My Home"
        viewModel.addressInput = "123 Main St"
        viewModel.isParsingAddress = true

        #expect(viewModel.canSave == false)
    }

    @Test("canDelete is false when single home")
    func testCanDeleteFalseSingleHome() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home = Home.createTestHome(in: context)
        let viewModel = createViewModel(home: home, context: context, allHomes: [home])

        #expect(viewModel.canDelete == false)
    }

    @Test("canDelete is true when multiple homes")
    func testCanDeleteTrueMultiple() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home1 = Home.createTestHome(in: context, name: "Home 1")
        let home2 = Home.createTestHome(in: context, name: "Home 2")
        let viewModel = createViewModel(home: home1, context: context, allHomes: [home1, home2])

        #expect(viewModel.canDelete == true)
    }

    // MARK: - Save Changes Tests

    @Test("saveChanges persists all fields to existing home")
    func testSaveChanges() async throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home = Home.createTestHome(in: context, name: "Original Name")
        let viewModel = createViewModel(home: home, context: context)

        viewModel.tempHome.name = "Updated Name"
        viewModel.addressInput = "456 New St"
        viewModel.tempHome.colorName = "purple"

        await viewModel.saveChanges()

        #expect(home.name == "Updated Name")
        #expect(home.colorName == "purple")
        // Address is parsed from addressInput via CLGeocoder (fallback stores raw text)
        #expect(home.address1.isEmpty == false)
    }

    @Test("saveChanges does nothing for new home")
    func testSaveChangesNewHome() async throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)
        viewModel.tempHome.name = "New Home"

        // Should not crash or throw
        await viewModel.saveChanges()

        // Verify no home was accidentally created
        let descriptor = FetchDescriptor<Home>()
        let homes = try context.fetch(descriptor)
        #expect(homes.isEmpty == true)
    }

    // MARK: - Delete Home Tests

    @Test("deleteHome removes home from context")
    func testDeleteHome() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home1 = Home.createTestHome(in: context, name: "Home 1", isPrimary: false)
        let home2 = Home.createTestHome(in: context, name: "Home 2", isPrimary: true)
        try context.save()

        let viewModel = createViewModel(home: home1, context: context, allHomes: [home1, home2])

        let result = viewModel.deleteHome()

        #expect(result == true)

        let descriptor = FetchDescriptor<Home>()
        let homes = try context.fetch(descriptor)
        #expect(homes.count == 1)
        #expect(homes.first?.name == "Home 2")
    }

    @Test("deleteHome reassigns primary to another home")
    func testDeleteHomeReassignsPrimary() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)
        let settings = MockSettingsManager()

        let home1 = Home.createTestHome(in: context, name: "Home 1", isPrimary: true)
        let home2 = Home.createTestHome(in: context, name: "Home 2", isPrimary: false)
        try context.save()

        let viewModel = HomeDetailSettingsViewModel(
            home: home1,
            modelContext: context,
            settings: settings,
            allHomesProvider: { [home1, home2] }
        )

        let result = viewModel.deleteHome()

        #expect(result == true)
        #expect(home2.isPrimary == true)
    }

    @Test("deleteHome cleans up associated locations")
    func testDeleteHomeCleansLocations() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home1 = Home.createTestHomeWithLocations(in: context, name: "Home 1", locationCount: 3)
        let home2 = Home.createTestHome(in: context, name: "Home 2", isPrimary: true)
        try context.save()

        let viewModel = createViewModel(home: home1, context: context, allHomes: [home1, home2])

        let result = viewModel.deleteHome()

        #expect(result == true)

        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        let locations = try context.fetch(locationDescriptor)
        #expect(locations.isEmpty == true)
    }

    @Test("deleteHome fails on last home")
    func testDeleteHomeFailsLastHome() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home = Home.createTestHome(in: context)
        let viewModel = createViewModel(home: home, context: context, allHomes: [home])

        let result = viewModel.deleteHome()

        #expect(result == false)
        #expect(viewModel.deleteError != nil)
        #expect(viewModel.deleteError?.contains("at least one home") == true)
    }

    // MARK: - Toggle Primary Tests

    @Test("togglePrimary sets home as primary")
    func testTogglePrimaryOn() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)
        let settings = MockSettingsManager()

        let home1 = Home.createTestHome(in: context, name: "Home 1", isPrimary: true)
        let home2 = Home.createTestHome(in: context, name: "Home 2", isPrimary: false)
        try context.save()

        let viewModel = HomeDetailSettingsViewModel(
            home: home2,
            modelContext: context,
            settings: settings,
            allHomesProvider: { [home1, home2] }
        )

        viewModel.togglePrimary(true)

        #expect(viewModel.tempHome.isPrimary == true)
        #expect(home1.isPrimary == false)
        #expect(home2.isPrimary == true)
    }

    @Test("togglePrimary off reassigns to another home")
    func testTogglePrimaryOff() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)
        let settings = MockSettingsManager()

        let home1 = Home.createTestHome(in: context, name: "Home 1", isPrimary: true)
        let home2 = Home.createTestHome(in: context, name: "Home 2", isPrimary: false)
        try context.save()

        let viewModel = HomeDetailSettingsViewModel(
            home: home1,
            modelContext: context,
            settings: settings,
            allHomesProvider: { [home1, home2] }
        )

        viewModel.togglePrimary(false)

        #expect(viewModel.tempHome.isPrimary == false)
        #expect(home2.isPrimary == true)
    }

    // MARK: - Error State Tests

    @Test("clearDeleteError clears the error")
    func testClearDeleteError() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)
        viewModel.deleteError = "Test error"

        viewModel.clearDeleteError()

        #expect(viewModel.deleteError == nil)
    }

    @Test("clearSaveError clears the error")
    func testClearSaveError() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)
        viewModel.saveError = "Test error"

        viewModel.clearSaveError()

        #expect(viewModel.saveError == nil)
    }

    @Test("confirmDelete sets showingDeleteConfirmation")
    func testConfirmDelete() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home = Home.createTestHome(in: context)
        let viewModel = createViewModel(home: home, context: context)

        viewModel.confirmDelete()

        #expect(viewModel.showingDeleteConfirmation == true)
    }

    // MARK: - Address Input Tests

    @Test("addressInput is populated from existing home fields")
    func testAddressInputFromExistingHome() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home = Home.createTestHome(
            in: context,
            name: "Test",
            address1: "123 Main St",
            city: "Springfield",
            state: "IL",
            zip: "62701"
        )
        let viewModel = createViewModel(home: home, context: context)

        #expect(viewModel.addressInput.contains("123 Main St"))
        #expect(viewModel.addressInput.contains("Springfield"))
    }

    @Test("addressInput is empty for new home")
    func testAddressInputEmptyForNewHome() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)

        #expect(viewModel.addressInput == "")
    }

    // MARK: - DisplayHome Tests

    @Test("displayHome returns original home when editing existing")
    func testDisplayHomeReturnsOriginal() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let home = Home.createTestHome(in: context, name: "Original")
        let viewModel = createViewModel(home: home, context: context)

        #expect(viewModel.displayHome.id == home.id)
    }

    @Test("displayHome returns tempHome when creating new")
    func testDisplayHomeReturnsTempHome() throws {
        let container = try createTestContainer()
        let context = createContext(with: container)

        let viewModel = createViewModel(home: nil, context: context)
        viewModel.tempHome.name = "New Home"

        #expect(viewModel.displayHome.name == "New Home")
    }

    // MARK: - Update Dependencies Tests

    @Test("updateDependencies updates all dependencies")
    func testUpdateDependencies() throws {
        let container = try createTestContainer()
        let context1 = createContext(with: container)
        let context2 = createContext(with: container)
        let settings1 = MockSettingsManager()
        let settings2 = MockSettingsManager()

        let home = Home.createTestHome(in: context1, name: "Home 1")
        let home2 = Home.createTestHome(in: context1, name: "Home 2")

        let viewModel = HomeDetailSettingsViewModel(
            home: home,
            modelContext: context1,
            settings: settings1,
            allHomesProvider: { [home] }
        )

        #expect(viewModel.canDelete == false)  // Only one home

        viewModel.updateDependencies(
            modelContext: context2,
            settings: settings2,
            allHomesProvider: { [home, home2] }
        )

        #expect(viewModel.canDelete == true)  // Now two homes
    }
}
