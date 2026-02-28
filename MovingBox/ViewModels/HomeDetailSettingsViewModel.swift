//
//  HomeDetailSettingsViewModel.swift
//  MovingBox
//
//  Created by Claude Code on 1/26/26.
//

import CoreLocation
import Dependencies
import Foundation
import SQLiteData
import SwiftUI

@Observable
@MainActor
final class HomeDetailSettingsViewModel {

    // MARK: - State

    var isEditing: Bool
    var isCreating: Bool = false
    var showingDeleteConfirmation: Bool = false
    var deleteError: String?
    var saveError: String?
    var addressInput: String = ""
    var isParsingAddress: Bool = false

    // Form state
    var name: String = ""
    var address1: String = ""
    var address2: String = ""
    var city: String = ""
    var state: String = ""
    var zip: String = ""
    var country: String = ""
    var colorName: String = "green"
    var isPrimary: Bool = false

    // MARK: - Dependencies

    let originalHomeID: UUID?
    private var database: (any DatabaseWriter)?
    private var settings: SettingsManager
    private var allHomesProvider: () -> [SQLiteHome]

    // MARK: - Computed Properties

    var isNewHome: Bool {
        originalHomeID == nil
    }

    var displayName: String {
        if !name.isEmpty {
            return name
        } else if !address1.isEmpty {
            return address1
        }
        return "Unnamed Home"
    }

    var displayColor: Color {
        Color.homeColor(for: colorName)
    }

    var canSave: Bool {
        let hasAddress = !addressInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasAddress || hasName) && !isCreating && !isParsingAddress
    }

    var canDelete: Bool {
        allHomesProvider().count > 1 && isEditing
    }

    private var allHomes: [SQLiteHome] {
        allHomesProvider()
    }

    // MARK: - Initialization

    init(
        homeID: UUID?,
        settings: SettingsManager,
        allHomesProvider: @escaping () -> [SQLiteHome] = { [] }
    ) {
        self.originalHomeID = homeID
        self.settings = settings
        self.allHomesProvider = allHomesProvider

        if homeID != nil {
            // Editing existing home — fields will be loaded in loadHomeData()
            self.isEditing = false
        } else {
            // Creating new home
            self.country = Locale.current.region?.identifier ?? "US"
            self.isEditing = true
        }
    }

    // MARK: - Public Methods

    func setDatabase(_ db: any DatabaseWriter) {
        self.database = db
    }

    func updateAllHomesProvider(_ provider: @escaping () -> [SQLiteHome]) {
        self.allHomesProvider = provider
    }

    func loadHomeData() async {
        guard let originalHomeID, let database else { return }

        do {
            let home = try await database.read { db in
                try SQLiteHome.find(originalHomeID).fetchOne(db)
            }
            if let home {
                name = home.name
                address1 = home.address1
                address2 = home.address2
                city = home.city
                state = home.state
                zip = home.zip
                country = home.country
                colorName = home.colorName
                isPrimary = home.isPrimary
                addressInput = Self.composeAddressString(
                    address1: home.address1,
                    address2: home.address2,
                    city: home.city,
                    state: home.state,
                    zip: home.zip
                )
            }
        } catch {
            saveError = "Failed to load home: \(error.localizedDescription)"
        }
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
                address1 = [placemark.subThoroughfare, placemark.thoroughfare]
                    .compactMap { $0 }.joined(separator: " ")
                address2 = ""
                city = placemark.locality ?? ""
                state = placemark.administrativeArea ?? ""
                zip = placemark.postalCode ?? ""
                country =
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
        guard let database else { return }

        if newValue {
            isPrimary = true
            let homeID = originalHomeID ?? UUID()
            settings.activeHomeId = homeID.uuidString

            // Update all other homes to not be primary
            for otherHome in allHomes where otherHome.id != homeID {
                do {
                    try database.write { db in
                        try SQLiteHome.find(otherHome.id).update {
                            $0.isPrimary = false
                        }.execute(db)
                    }
                } catch {
                    print("Error updating home primary status: \(error)")
                }
            }
        } else {
            isPrimary = false
            // Find another home to make primary
            let homeID = originalHomeID ?? UUID()
            if let firstOther = allHomes.first(where: { $0.id != homeID }) {
                do {
                    try database.write { db in
                        try SQLiteHome.find(firstOther.id).update {
                            $0.isPrimary = true
                        }.execute(db)
                    }
                } catch {
                    print("Error updating home primary status: \(error)")
                }
                settings.activeHomeId = firstOther.id.uuidString
            }
        }
    }

    func saveChanges() async {
        guard let originalHomeID, let database else { return }

        await parseAddress()

        let saveName = name
        let saveAddr1 = address1
        let saveAddr2 = address2
        let saveCity = city
        let saveState = state
        let saveZip = zip
        let saveCountry = country
        let saveColor = colorName
        let savePrimary = isPrimary

        do {
            try await database.write { db in
                try SQLiteHome.find(originalHomeID).update {
                    $0.name = saveName
                    $0.address1 = saveAddr1
                    $0.address2 = saveAddr2
                    $0.city = saveCity
                    $0.state = saveState
                    $0.zip = saveZip
                    $0.country = saveCountry
                    $0.colorName = saveColor
                    $0.isPrimary = savePrimary
                }.execute(db)
            }
        } catch {
            saveError = "Failed to save changes: \(error.localizedDescription)"
        }
    }

    func createHome() async -> UUID? {
        guard let database else { return nil }
        isCreating = true
        saveError = nil

        do {
            await parseAddress()

            let newHomeID = UUID()
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let saveAddr1 = address1
            let saveAddr2 = address2
            let saveCity = city
            let saveState = state
            let saveZip = zip
            let saveCountry = country
            let saveColor = colorName
            let shouldBePrimary = allHomes.isEmpty
            let defaultRooms = TestData.defaultRooms

            try await database.write { db in
                let householdID = try SQLiteHousehold.order(by: \.createdAt).fetchOne(db)?.id
                try SQLiteHome.insert {
                    SQLiteHome(
                        id: newHomeID,
                        name: trimmedName,
                        address1: saveAddr1,
                        address2: saveAddr2,
                        city: saveCity,
                        state: saveState,
                        zip: saveZip,
                        country: saveCountry,
                        isPrimary: shouldBePrimary,
                        colorName: saveColor,
                        householdID: householdID
                    )
                }.execute(db)

                // Create default locations for the new home
                for roomData in defaultRooms {
                    try SQLiteInventoryLocation.insert {
                        SQLiteInventoryLocation(
                            id: UUID(),
                            name: roomData.name,
                            desc: roomData.desc,
                            sfSymbolName: roomData.sfSymbol,
                            homeID: newHomeID
                        )
                    }.execute(db)
                }
            }

            if shouldBePrimary {
                settings.activeHomeId = newHomeID.uuidString
            }

            TelemetryManager.shared.trackHomeCreated(name: trimmedName.isEmpty ? saveAddr1 : trimmedName)

            isCreating = false
            return newHomeID
        } catch {
            saveError = "Failed to create home: \(error.localizedDescription)"
            isCreating = false
            return nil
        }
    }

    func deleteHome() -> Bool {
        guard let originalHomeID, let database else { return false }

        // Validation: can't delete if only one home exists
        if allHomes.count <= 1 {
            deleteError = "You must have at least one home. Cannot delete the last remaining home."
            return false
        }

        // If deleting primary home, make another home primary first
        if isPrimary {
            if let firstOther = allHomes.first(where: { $0.id != originalHomeID }) {
                do {
                    try database.write { db in
                        try SQLiteHome.find(firstOther.id).update {
                            $0.isPrimary = true
                        }.execute(db)
                    }
                } catch {
                    print("Error updating home primary status: \(error)")
                }
                settings.activeHomeId = firstOther.id.uuidString
            }
        }

        do {
            try database.write { db in
                // Unassign items from locations belonging to this home,
                // then delete those locations, then clear home reference from items
                // Note: We use @FetchAll-sourced data filtered in memory

                // Set locationID = nil for items in locations belonging to this home
                // and homeID = nil for items directly assigned to this home
                try SQLiteInventoryItem
                    .where { $0.homeID == originalHomeID }
                    .update {
                        $0.homeID = nil as UUID?
                        $0.locationID = nil as UUID?
                    }
                    .execute(db)

                // Delete all locations for this home
                try SQLiteInventoryLocation
                    .where { $0.homeID == originalHomeID }
                    .delete()
                    .execute(db)

                // Delete the home itself
                try SQLiteHome.find(originalHomeID).delete().execute(db)
            }
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

    static func composeAddressString(
        address1: String,
        address2: String,
        city: String,
        state: String,
        zip: String
    ) -> String {
        var components: [String] = []
        if !address1.isEmpty { components.append(address1) }
        if !address2.isEmpty { components.append(address2) }
        var cityStateParts: [String] = []
        if !city.isEmpty { cityStateParts.append(city) }
        if !state.isEmpty { cityStateParts.append(state) }
        if !zip.isEmpty { cityStateParts.append(zip) }
        if !cityStateParts.isEmpty {
            components.append(cityStateParts.joined(separator: ", "))
        }
        return components.joined(separator: ", ")
    }

    private func setFallbackAddress(_ raw: String) {
        address1 = raw
        address2 = ""
        city = ""
        state = ""
        zip = ""
        country = Locale.current.region?.identifier ?? "US"
    }

    private func clearAddressFields() {
        address1 = ""
        address2 = ""
        city = ""
        state = ""
        zip = ""
        country = ""
    }
}
