//
//  HomeDetailSettingsViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 1/26/26.
//

import CoreLocation
import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class HomeDetailSettingsViewModel {

    // MARK: - State

    var tempHome: Home
    var isEditing: Bool
    var isCreating: Bool = false
    var showingDeleteConfirmation: Bool = false
    var deleteError: String?
    var saveError: String?
    var addressInput: String = ""
    var isParsingAddress: Bool = false

    // MARK: - Dependencies

    private let originalHome: Home?
    private var modelContext: ModelContext
    private var settings: SettingsManager
    private var allHomesProvider: () -> [Home]

    // MARK: - Computed Properties

    var isNewHome: Bool {
        originalHome == nil
    }

    var displayHome: Home {
        originalHome ?? tempHome
    }

    var canSave: Bool {
        let hasAddress = !addressInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasName = !tempHome.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasAddress || hasName) && !isCreating && !isParsingAddress
    }

    var canDelete: Bool {
        allHomesProvider().count > 1 && isEditing
    }

    private var allHomes: [Home] {
        allHomesProvider()
    }

    // MARK: - Initialization

    init(
        home: Home?,
        modelContext: ModelContext,
        settings: SettingsManager,
        allHomesProvider: @escaping () -> [Home] = { [] }
    ) {
        self.originalHome = home
        self.modelContext = modelContext
        self.settings = settings
        self.allHomesProvider = allHomesProvider

        if let home = home {
            // Create a copy for editing existing home
            // Set all properties before assigning to self to avoid using self before init complete
            let copy = Home(
                id: home.id,
                name: home.name,
                address1: home.address1,
                address2: home.address2,
                city: home.city,
                state: home.state,
                zip: home.zip,
                country: home.country
            )
            copy.isPrimary = home.isPrimary
            copy.colorName = home.colorName
            copy.imageURL = home.imageURL
            self.tempHome = copy
            self.isEditing = false
            self.addressInput = Self.composeAddressString(from: home)
        } else {
            // Creating new home
            let newHome = Home()
            newHome.country = Locale.current.region?.identifier ?? "US"
            self.tempHome = newHome
            self.isEditing = true
        }
    }

    // MARK: - Public Methods

    func updateDependencies(
        modelContext: ModelContext,
        settings: SettingsManager,
        allHomesProvider: @escaping () -> [Home]
    ) {
        // Note: We use a technique here where we update dependencies after init
        // because the View's init doesn't have access to @Environment values
        // This is safe because these are reference types and state is preserved
        self.modelContext = modelContext
        self.settings = settings
        self.allHomesProvider = allHomesProvider
    }

    func updateAllHomesProvider(_ provider: @escaping () -> [Home]) {
        self.allHomesProvider = provider
    }

    func parseAddress() async {
        let trimmed = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearAddressFields()
            return
        }
        isParsingAddress = true
        defer { isParsingAddress = false }

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmed)
            if let placemark = placemarks.first {
                tempHome.address1 = [placemark.subThoroughfare, placemark.thoroughfare]
                    .compactMap { $0 }.joined(separator: " ")
                tempHome.address2 = ""
                tempHome.city = placemark.locality ?? ""
                tempHome.state = placemark.administrativeArea ?? ""
                tempHome.zip = placemark.postalCode ?? ""
                tempHome.country =
                    placemark.isoCountryCode
                    ?? Locale.current.region?.identifier ?? "US"
            } else {
                setFallbackAddress(trimmed)
            }
        } catch {
            setFallbackAddress(trimmed)
        }
    }

    func togglePrimary(_ newValue: Bool) {
        if newValue {
            // Make this home primary and unmark all others
            for otherHome in allHomes {
                otherHome.isPrimary = (otherHome.id == tempHome.id)
            }
            tempHome.isPrimary = true
            settings.activeHomeId = tempHome.id.uuidString
        } else {
            // Find another home to make primary
            if let firstOtherHome = allHomes.first(where: { $0.id != tempHome.id }) {
                firstOtherHome.isPrimary = true
                tempHome.isPrimary = false
                settings.activeHomeId = firstOtherHome.id.uuidString
            }
        }
    }

    func saveChanges() async {
        guard let existingHome = originalHome else { return }

        await parseAddress()

        existingHome.name = tempHome.name
        existingHome.address1 = tempHome.address1
        existingHome.address2 = tempHome.address2
        existingHome.city = tempHome.city
        existingHome.state = tempHome.state
        existingHome.zip = tempHome.zip
        existingHome.country = tempHome.country
        existingHome.colorName = tempHome.colorName
        existingHome.isPrimary = tempHome.isPrimary
        existingHome.imageURL = tempHome.imageURL

        do {
            try modelContext.save()
        } catch {
            saveError = "Failed to save changes: \(error.localizedDescription)"
        }
    }

    func createHome() async -> Bool {
        isCreating = true
        saveError = nil

        do {
            let trimmedName = tempHome.name.trimmingCharacters(in: .whitespacesAndNewlines)

            await parseAddress()

            let newHome = try await DefaultDataManager.createNewHome(
                name: trimmedName,
                modelContext: modelContext
            )

            // Copy all properties from tempHome to newHome
            newHome.address1 = tempHome.address1
            newHome.address2 = tempHome.address2
            newHome.city = tempHome.city
            newHome.state = tempHome.state
            newHome.zip = tempHome.zip
            newHome.country = tempHome.country
            newHome.colorName = tempHome.colorName
            newHome.imageURL = tempHome.imageURL

            // If this is the first home, make it primary
            if allHomes.isEmpty {
                newHome.isPrimary = true
                settings.activeHomeId = newHome.id.uuidString
            }

            try modelContext.save()

            TelemetryManager.shared.trackHomeCreated(name: newHome.displayName)

            isCreating = false
            return true
        } catch {
            saveError = "Failed to create home: \(error.localizedDescription)"
            isCreating = false
            return false
        }
    }

    func deleteHome() -> Bool {
        guard let homeToDelete = originalHome else { return false }

        // Validation: can't delete if only one home exists
        if allHomes.count <= 1 {
            deleteError = "You must have at least one home. Cannot delete the last remaining home."
            return false
        }

        // If deleting primary home, make another home primary first
        if homeToDelete.isPrimary {
            if let firstOtherHome = allHomes.first(where: { $0.id != homeToDelete.id }) {
                firstOtherHome.isPrimary = true
                settings.activeHomeId = firstOtherHome.id.uuidString
            }
        }

        // Delete all locations associated with this home
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        if let locations = try? modelContext.fetch(locationDescriptor) {
            for location in locations where location.home?.id == homeToDelete.id {
                // Unassign items from this location
                if let items = location.inventoryItems {
                    for item in items {
                        item.location = nil
                    }
                }
                modelContext.delete(location)
            }
        }

        // Clear direct home references from items
        let itemDescriptor = FetchDescriptor<InventoryItem>()
        if let items = try? modelContext.fetch(itemDescriptor) {
            for item in items where item.home?.id == homeToDelete.id {
                item.home = nil
            }
        }

        // Delete the home itself
        modelContext.delete(homeToDelete)

        // Save changes
        do {
            try modelContext.save()
            return true
        } catch {
            deleteError = "Failed to delete home: \(error.localizedDescription)"
            return false
        }
    }

    func confirmDelete() {
        showingDeleteConfirmation = true
    }

    func clearDeleteError() {
        deleteError = nil
    }

    func clearSaveError() {
        saveError = nil
    }

    // MARK: - Private Helpers

    private static func composeAddressString(from home: Home) -> String {
        var components: [String] = []
        if !home.address1.isEmpty { components.append(home.address1) }
        if !home.address2.isEmpty { components.append(home.address2) }
        var cityStateParts: [String] = []
        if !home.city.isEmpty { cityStateParts.append(home.city) }
        if !home.state.isEmpty { cityStateParts.append(home.state) }
        if !home.zip.isEmpty { cityStateParts.append(home.zip) }
        if !cityStateParts.isEmpty {
            components.append(cityStateParts.joined(separator: ", "))
        }
        return components.joined(separator: ", ")
    }

    private func setFallbackAddress(_ raw: String) {
        tempHome.address1 = raw
        tempHome.address2 = ""
        tempHome.city = ""
        tempHome.state = ""
        tempHome.zip = ""
        tempHome.country = Locale.current.region?.identifier ?? "US"
    }

    private func clearAddressFields() {
        tempHome.address1 = ""
        tempHome.address2 = ""
        tempHome.city = ""
        tempHome.state = ""
        tempHome.zip = ""
        tempHome.country = ""
    }
}
