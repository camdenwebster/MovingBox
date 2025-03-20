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
    
    // Add grid layout configuration
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            if locations.isEmpty {
                ContentUnavailableView(
                    "No Locations",
                    systemImage: "map",
                    description: Text("Add locations to organize your items by room or area.")
                )
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(locations) { location in
                        NavigationLink(value: location) {
                            LocationItemCard(location: location)
                                .background(RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationDestination(for: InventoryLocation.self) { location in
            InventoryListView(location: location)
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button("Edit") {
                router.navigate(to: .locationsSettingsView)
            }
            Button("Add Item", systemImage: "plus", action: addLocation)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            print("LocationsListView: Total number of locations: \(locations.count)")
        }
    }
    
    func addLocation() {
        router.navigate(to: .editLocationView(location: nil))
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
