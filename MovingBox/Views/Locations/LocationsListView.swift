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
    @State private var sortOrder = [SortDescriptor(\InventoryLocation.name)]
    @State private var showingCamera = false
    @State private var showingImageAnalysis = false
    @State private var analyzingImage: UIImage?
    @State private var searchText = ""
    
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared
    
    // Use @Query with sort descriptor for efficient loading
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) private var allLocations: [InventoryLocation]

    // Computed property to get only root locations (no parent)
    private var rootLocations: [InventoryLocation] {
        allLocations.filter { $0.parent == nil }
    }

    // Query for items without location
    @Query(filter: #Predicate<InventoryItem> { item in
        item.location == nil
    }) private var unassignedItems: [InventoryItem]

    // Computed property for unassigned items count and total value
    private var unassignedItemsCount: Int {
        unassignedItems.count
    }

    private var unassignedItemsTotalValue: Decimal {
        unassignedItems.reduce(0) { $0 + $1.price }
    }

    // Filtered locations based on search (searches all locations including nested)
    private var filteredLocations: [InventoryLocation] {
        if searchText.isEmpty {
            return rootLocations
        }
        // When searching, show all matching locations (including nested ones)
        return allLocations.filter { location in
            location.name.localizedCaseInsensitiveContains(searchText) ||
            location.getFullPath().localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var columns: [GridItem] {
        let minimumCardWidth: CGFloat = 160
        let maximumCardWidth: CGFloat = 220
        return [GridItem(.adaptive(minimum: minimumCardWidth, maximum: maximumCardWidth))]
    }

    // Special card for items without a location
    private var noLocationCard: some View {
        VStack(spacing: 0) {
            // Icon section
            Rectangle()
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 160, height: 100)
                .overlay(
                    Image(systemName: "questionmark.folder.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.orange)
                )

            // Location details
            VStack(alignment: .leading) {
                Text("No Location")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.label))
                HStack {
                    Text("Items")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                    Text("\(unassignedItemsCount)")
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                }
                HStack {
                    Text("Value")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                    Text(CurrencyFormatter.format(unassignedItemsTotalValue))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius))
        .background(RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1))
        .padding(1)
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
                        // Special "No Location" card - only show if there are unassigned items
                        if unassignedItemsCount > 0 && searchText.isEmpty {
                            NavigationLink(value: "no-location") {
                                noLocationCard
                                    .frame(maxWidth: 180)
                            }
                        }

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
