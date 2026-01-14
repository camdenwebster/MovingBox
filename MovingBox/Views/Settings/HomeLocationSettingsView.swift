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
    @EnvironmentObject var router: Router
    @Query private var allLocations: [InventoryLocation]

    let home: Home

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
                ForEach(filteredLocations) { location in
                    NavigationLink {
                        EditLocationView(location: location)
                    } label: {
                        HStack {
                            if let symbolName = location.sfSymbolName {
                                Image(systemName: symbolName)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                            }
                            Text(location.name)
                        }
                    }
                }
                .onDelete(perform: deleteLocations)
            }
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()
                Button("Add Location", systemImage: "plus") {
                    addLocation()
                }
            }
        }
    }

    func addLocation() {
        let newLocation = InventoryLocation(name: "", desc: "")
        newLocation.home = home
        router.navigate(to: .editLocationView(location: newLocation, isEditing: true))
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
                .environmentObject(Router())
        }
    } catch {
        return Text("Failed to set up preview: \(error.localizedDescription)")
            .foregroundColor(.red)
    }
}
