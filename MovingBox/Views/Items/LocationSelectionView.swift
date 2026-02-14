//
//  LocationSelectionView.swift
//  MovingBox
//
//  Created by AI Assistant on 1/10/25.
//

import Dependencies
import SQLiteData
import SwiftUI

struct LocationSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) var database
    @EnvironmentObject var settingsManager: SettingsManager
    @FetchAll(SQLiteInventoryLocation.order(by: \.name), animation: .default)
    private var allLocations: [SQLiteInventoryLocation]
    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]

    @Binding var selectedLocation: SQLiteInventoryLocation?
    @Binding var selectedHome: SQLiteHome?
    @State private var pickedHome: SQLiteHome?
    @State private var searchText = ""

    init(selectedLocation: Binding<SQLiteInventoryLocation?>, selectedHome: Binding<SQLiteHome?>) {
        self._selectedLocation = selectedLocation
        self._selectedHome = selectedHome
    }

    private var activeHome: SQLiteHome? {
        guard let activeIdString = settingsManager.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    private var locationsForPickedHome: [SQLiteInventoryLocation] {
        guard let pickedHome = pickedHome else {
            return allLocations
        }
        return allLocations.filter { $0.homeID == pickedHome.id }
    }

    private var filteredLocations: [SQLiteInventoryLocation] {
        if searchText.isEmpty {
            return locationsForPickedHome
        }
        return locationsForPickedHome.filter { location in
            location.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !homes.isEmpty {
                    Section {
                        Picker("Home", selection: $pickedHome) {
                            ForEach(homes) { home in
                                Text(home.displayName)
                                    .tag(home as SQLiteHome?)
                            }
                        }
                        .accessibilityIdentifier("locationSelection-homePicker")
                    }
                }

                // None option
                Button(action: {
                    selectedHome = pickedHome
                    selectedLocation = nil
                    dismiss()
                }) {
                    HStack {
                        Text("No Location")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedLocation == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("locationSelection-noLocation")

                if !filteredLocations.isEmpty {
                    Section {
                        ForEach(filteredLocations) { location in
                            Button(action: {
                                selectedHome = pickedHome
                                selectedLocation = location
                                dismiss()
                            }) {
                                HStack {
                                    if let symbolName = location.sfSymbolName {
                                        Image(systemName: symbolName)
                                            .foregroundStyle(.tint)
                                            .frame(width: 24)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(location.name)
                                            .foregroundStyle(.primary)
                                        if !location.desc.isEmpty {
                                            Text(location.desc)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    if selectedLocation?.id == location.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("locationSelection-row-\(location.name)")
                        }
                    }
                }

                if filteredLocations.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        "No Locations Found",
                        systemImage: "magnifyingglass",
                        description: Text("No locations match '\(searchText)'")
                    )
                }
            }
            .searchable(text: $searchText, prompt: "Search locations")
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        addNewLocation()
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                if pickedHome == nil {
                    pickedHome = selectedHome ?? activeHome ?? homes.first
                }
            }
        }
    }

    private func addNewLocation() {
        let newID = UUID()
        do {
            try database.write { db in
                try SQLiteInventoryLocation.insert {
                    SQLiteInventoryLocation(id: newID, name: "New Location", homeID: pickedHome?.id)
                }.execute(db)
            }
            selectedHome = pickedHome
            selectedLocation = SQLiteInventoryLocation(id: newID, name: "New Location", homeID: pickedHome?.id)
            dismiss()
        } catch {
            print("Failed to create new location: \(error)")
        }
    }
}

#Preview {
    @Previewable @State var location: SQLiteInventoryLocation? = nil
    @Previewable @State var home: SQLiteHome? = nil
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    return LocationSelectionView(selectedLocation: $location, selectedHome: $home)
        .environmentObject(SettingsManager())
}
