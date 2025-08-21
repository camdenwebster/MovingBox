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
    @Query(sort: [SortDescriptor(\InventoryLocation.name)]) private var locations: [InventoryLocation]
    
    @Binding var selectedLocation: InventoryLocation?
    @State private var searchText = ""
    
    private var filteredLocations: [InventoryLocation] {
        if searchText.isEmpty {
            return locations
        }
        return locations.filter { location in
            location.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // None option
                Button(action: {
                    selectedLocation = nil
                    dismiss()
                }) {
                    HStack {
                        Text("None")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedLocation == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                if !filteredLocations.isEmpty {
                    Section {
                        ForEach(filteredLocations) { location in
                            Button(action: {
                                selectedLocation = location
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(location.name)
                                            .foregroundColor(.primary)
                                        if !location.desc.isEmpty {
                                            Text(location.desc)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    if selectedLocation?.id == location.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        addNewLocation()
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func addNewLocation() {
        let newLocation = InventoryLocation(name: "New Location", desc: "")
        modelContext.insert(newLocation)
        selectedLocation = newLocation
        dismiss()
    }
}

#Preview {
    @Previewable @State var location: InventoryLocation? = nil
    return LocationSelectionView(selectedLocation: $location)
}
