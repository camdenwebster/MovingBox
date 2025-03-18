//
//  LocationsListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import SwiftUI
import SwiftData

struct LocationsListView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @State private var path = NavigationPath()
    @State private var sortOrder = [SortDescriptor(\InventoryLocation.name)]
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    
    var body: some View {
        List {
            ForEach(locations) { location in
                NavigationLink(value: location) {
                    LocationItemCard(location: location)
                }
            }
            .onDelete(perform: deleteLocations)
        }
        .navigationDestination(for: InventoryLocation.self) { location in
            InventoryListView(location: location)
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            EditButton()
            Button("Add Item", systemImage: "plus", action: addLocation)
        }
        .onAppear {
            print("LocationsListView: Total number of locations: \(locations.count)")
        }
    }
    
    func addLocation() {
        router.navigate(to: .editLocationView(location: nil))
    }
    
    func deleteLocations(at offsets: IndexSet) {
        for index in offsets {
            let locationToDelete = locations[index]
            modelContext.delete(locationToDelete)
            print("Deleting location: \(locationToDelete.name)")
            TelemetryManager.shared.trackLocationDeleted()
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return LocationsListView()
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
