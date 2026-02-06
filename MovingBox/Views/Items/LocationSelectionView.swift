//
//  LocationSelectionView.swift
//  MovingBox
//
//  Created by AI Assistant on 1/10/25.
//

import SwiftData
import SwiftUI

struct LocationSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    @Query(sort: [SortDescriptor(\InventoryLocation.name)]) private var allLocations: [InventoryLocation]
    @Query(sort: \Home.purchaseDate) private var homes: [Home]

    @Binding var selectedLocation: InventoryLocation?
    @Binding var selectedHome: Home?
    @State private var pickedHome: Home?
    @State private var draftSelectedLocation: InventoryLocation?
    @State private var draftSelectedHome: Home?
    @State private var searchText = ""
    @State private var showingAddLocationSheet = false
    @State private var locationIDsBeforeAddSheet: Set<UUID> = []

    init(selectedLocation: Binding<InventoryLocation?>, selectedHome: Binding<Home?>) {
        self._selectedLocation = selectedLocation
        self._selectedHome = selectedHome
    }

    private var activeHome: Home? {
        guard let activeIdString = settingsManager.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    private var locationsForPickedHome: [InventoryLocation] {
        guard let pickedHome = pickedHome else {
            return allLocations
        }
        return allLocations.filter { $0.home?.id == pickedHome.id }
    }

    private var filteredLocations: [InventoryLocation] {
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
                                    .tag(home as Home?)
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
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        selectedHome = draftSelectedHome ?? pickedHome
                        selectedLocation = draftSelectedLocation
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("locationSelection-done")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        locationIDsBeforeAddSheet = Set(allLocations.map(\.id))
                        showingAddLocationSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("locationSelection-add")
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
                if draftSelectedLocation?.home?.id != newHome.id {
                    draftSelectedLocation = nil
                }
            }
        }
        .sheet(
            isPresented: $showingAddLocationSheet,
            onDismiss: {
                handleAddLocationSheetDismissed()
            }
        ) {
            NavigationStack {
                EditLocationView(
                    location: nil,
                    isEditing: true,
                    presentedInSheet: true,
                    home: pickedHome
                )
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func handleAddLocationSheetDismissed() {
        guard !locationIDsBeforeAddSheet.isEmpty else { return }
        defer { locationIDsBeforeAddSheet.removeAll() }

        let addedLocations = allLocations.filter { !locationIDsBeforeAddSheet.contains($0.id) }
        guard !addedLocations.isEmpty else { return }

        let newlyAddedLocation: InventoryLocation?
        if let pickedHome {
            newlyAddedLocation =
                addedLocations.first(where: { $0.home?.id == pickedHome.id }) ?? addedLocations.first
        } else {
            newlyAddedLocation = addedLocations.first
        }

        guard let newlyAddedLocation else { return }

        if let locationHome = newlyAddedLocation.home {
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
    @Previewable @State var location: InventoryLocation? = nil
    @Previewable @State var home: Home? = nil
    return LocationSelectionView(selectedLocation: $location, selectedHome: $home)
        .environmentObject(SettingsManager())
}
