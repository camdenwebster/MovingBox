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
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settingsManager: SettingsManager
    @Query(sort: [SortDescriptor(\InventoryLocation.name)]) private var allLocations: [InventoryLocation]
    @Query(sort: \Home.purchaseDate) private var homes: [Home]

    @Binding var selectedLocation: InventoryLocation?
    @Binding var selectedHome: Home?
    @State private var pickedHome: Home?
    @State private var searchText = ""

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
        let newLocation = InventoryLocation(name: "New Location", desc: "")
        newLocation.home = pickedHome
        modelContext.insert(newLocation)
        selectedHome = pickedHome
        selectedLocation = newLocation
        dismiss()
    }
}

#Preview {
    @Previewable @State var location: InventoryLocation? = nil
    @Previewable @State var home: Home? = nil
    return LocationSelectionView(selectedLocation: $location, selectedHome: $home)
        .environmentObject(SettingsManager())
}
