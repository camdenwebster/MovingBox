//
//  LocationSelectionView.swift
//  MovingBox
//
//  Created by AI Assistant on 1/10/25.
//

import SQLiteData
import SwiftUI

struct LocationSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    @FetchAll(SQLiteInventoryLocation.order(by: \.name), animation: .default)
    private var allLocations: [SQLiteInventoryLocation]
    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]

    @Binding var selectedLocation: SQLiteInventoryLocation?
    @Binding var selectedHome: SQLiteHome?
    @State private var pickedHome: SQLiteHome?
    @State private var draftSelectedLocation: SQLiteInventoryLocation?
    @State private var draftSelectedHome: SQLiteHome?
    @State private var searchText = ""
    @State private var showingAddLocationSheet = false
    @State private var locationIDsBeforeAddSheet: Set<UUID> = []

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
                    draftSelectedHome = pickedHome
                    draftSelectedLocation = nil
                }) {
                    HStack {
                        Text("No Location")
                            .foregroundStyle(.primary)
                        Spacer()
                        if draftSelectedLocation == nil {
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
                                draftSelectedHome = pickedHome
                                draftSelectedLocation = location
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
                                    if draftSelectedLocation?.id == location.id {
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
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem {
                    Button(action: {
                        locationIDsBeforeAddSheet = Set(allLocations.map(\.id))
                        showingAddLocationSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("locationSelection-add")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        selectedHome = draftSelectedHome ?? pickedHome
                        selectedLocation = draftSelectedLocation
                        dismiss()
                    }
                    .accessibilityIdentifier("locationSelection-done")
                }
            }
            .onAppear {
                if pickedHome == nil {
                    pickedHome = selectedHome ?? activeHome ?? homes.first
                }
                draftSelectedHome = selectedHome ?? pickedHome
                draftSelectedLocation = selectedLocation
            }
            .onChange(of: pickedHome) { _, newHome in
                draftSelectedHome = newHome
                guard let newHome else { return }
                if draftSelectedLocation?.homeID != newHome.id {
                    draftSelectedLocation = nil
                }
            }
        }
        .sheet(
            isPresented: $showingAddLocationSheet,
            onDismiss: {
                handleAddLocationSheetDismissed()
            },
            content: {
                NavigationStack {
                    EditLocationView(
                        locationID: nil,
                        isEditing: true,
                        presentedInSheet: true,
                        homeID: pickedHome?.id
                    )
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        )
    }

    private func handleAddLocationSheetDismissed() {
        defer { locationIDsBeforeAddSheet.removeAll() }

        let addedLocations = allLocations.filter { !locationIDsBeforeAddSheet.contains($0.id) }
        guard !addedLocations.isEmpty else { return }

        let newlyAddedLocation: SQLiteInventoryLocation?
        if let pickedHome {
            newlyAddedLocation =
                addedLocations.first(where: { $0.homeID == pickedHome.id }) ?? addedLocations.first
        } else {
            newlyAddedLocation = addedLocations.first
        }

        guard let newlyAddedLocation else { return }

        if let locationHomeID = newlyAddedLocation.homeID,
            let locationHome = homes.first(where: { $0.id == locationHomeID })
        {
            pickedHome = locationHome
            draftSelectedHome = locationHome
        } else {
            draftSelectedHome = pickedHome
        }

        draftSelectedLocation = newlyAddedLocation
        searchText = ""
    }
}

#Preview {
    @Previewable @State var location: SQLiteInventoryLocation? = nil
    @Previewable @State var home: SQLiteHome? = nil
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    return LocationSelectionView(selectedLocation: $location, selectedHome: $home)
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
