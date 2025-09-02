//
//  LocationsListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import RevenueCatUI
import SwiftUI
import SwiftData

struct LocationsListView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @State private var path = NavigationPath()
    @State private var sortOrder = [SortDescriptor(\InventoryLocation.name)]
    @State private var showingCamera = false
    @State private var showingImageAnalysis = false
    @State private var analyzingImage: UIImage?
    @State private var searchText = ""
    
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared
    
    // Use @Query with sort descriptor for efficient loading
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) private var locations: [InventoryLocation]
    
    // Filtered locations based on search
    private var filteredLocations: [InventoryLocation] {
        if searchText.isEmpty {
            return locations
        }
        return locations.filter { location in
            location.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var columns: [GridItem] {
        let minimumCardWidth: CGFloat = 160
        let maximumCardWidth: CGFloat = 220
        return [GridItem(.adaptive(minimum: minimumCardWidth, maximum: maximumCardWidth))]
    }
    
    var body: some View {
        Group {
            if filteredLocations.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    "No Locations",
                    systemImage: "map",
                    description: Text("Add locations to organize your items by room or area.")
                )
                .toolbar {
                    ToolbarItem {
                        Button {
                            router.navigate(to: .locationsSettingsView)
                        } label: {
                            Text("Edit")
                        }
                    }
                    ToolbarItem {
                        Button {
                            addLocation()
                        } label: {
                            Label("Add Location", systemImage: "plus")
                        }
                        .accessibilityIdentifier("addLocation")
                    }
                }
            } else if filteredLocations.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No locations found matching '\(searchText)'")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredLocations) { location in
                            NavigationLink(value: location) {
                                LocationItemCard(location: location)
                                    .frame(maxWidth: 180)
                            }
                        }
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            router.navigate(to: .locationsSettingsView)
                        } label: {
                            Text("Edit")
                        }
                    }
                }
            }
        }
        .navigationDestination(for: InventoryLocation.self) { location in
            InventoryListView(location: location)
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search locations")
        .background(Color(.systemGroupedBackground))
        .onAppear {
            print("LocationsListView: Total number of locations: \(locations.count)")
        }
    }
    
    private func addLocation() {
        router.navigate(to: .editLocationView(location: nil))
    }
    
    private func deleteLocations(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let location = filteredLocations[index]
                modelContext.delete(location)
            }
            try? modelContext.save()
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
