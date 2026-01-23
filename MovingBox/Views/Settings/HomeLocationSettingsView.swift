//
//  HomeLocationSettingsView.swift
//  MovingBox
//
//  Created by Claude on 12/20/25.
//

import SwiftData
import SwiftUI

struct HomeLocationSettingsView: View {
    @Environment(\.modelContext) var modelContext
    @Query private var allLocations: [InventoryLocation]

    let home: Home

    @State private var selectedLocation: InventoryLocation?
    @State private var showAddLocationSheet = false

    private var filteredLocations: [InventoryLocation] {
        allLocations.filter { location in
            location.home?.id == home.id
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if filteredLocations.isEmpty {
                ContentUnavailableView(
                    "No Locations",
                    systemImage: "map",
                    description: Text("Add locations to organize items in this home.")
                )
            } else {
                Section {
                    ForEach(filteredLocations) { location in
                        Button {
                            selectedLocation = location
                        } label: {
                            HStack {
                                if let symbolName = location.sfSymbolName {
                                    Image(systemName: symbolName)
                                        .foregroundStyle(.accentColor)
                                        .frame(width: 24)
                                }
                                Text(location.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                    .onDelete(perform: deleteLocations)
                }
            }
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()
                Button("Add Location", systemImage: "plus") {
                    showAddLocationSheet = true
                }
            }
        }
        .sheet(item: $selectedLocation) { location in
            NavigationStack {
                EditLocationView(location: location, isEditing: true, presentedInSheet: true, home: home)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddLocationSheet) {
            NavigationStack {
                EditLocationView(location: nil, isEditing: true, presentedInSheet: true, home: home)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    func deleteLocations(at offsets: IndexSet) {
        for index in offsets {
            let locationToDelete = filteredLocations[index]
            modelContext.delete(locationToDelete)
            print("Deleting location: \(locationToDelete.name)")
            TelemetryManager.shared.trackLocationDeleted()
        }
        try? modelContext.save()
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Home.self, InventoryLocation.self, configurations: config)

        let home = Home(name: "Main House")
        container.mainContext.insert(home)

        let location1 = InventoryLocation(name: "Living Room", desc: "Main living area")
        location1.home = home
        location1.sfSymbolName = "sofa"

        let location2 = InventoryLocation(name: "Kitchen", desc: "Cooking area")
        location2.home = home
        location2.sfSymbolName = "fork.knife"

        container.mainContext.insert(location1)
        container.mainContext.insert(location2)

        return NavigationStack {
            HomeLocationSettingsView(home: home)
                .modelContainer(container)
                .environmentObject(SettingsManager())
        }
    } catch {
        return Text("Failed to set up preview: \(error.localizedDescription)")
            .foregroundStyle(.red)
    }
}
