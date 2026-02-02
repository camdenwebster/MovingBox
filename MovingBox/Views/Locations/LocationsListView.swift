//
//  LocationsListView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/5/24.
//

import RevenueCatUI
import SwiftData
import SwiftUI

struct LocationsListView: View {
    let showAllHomes: Bool

    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @State private var sortOrder = [SortDescriptor(\InventoryLocation.name)]
    @State private var showingCamera = false
    @State private var showingImageAnalysis = false
    @State private var analyzingImage: UIImage?
    @State private var searchText = ""
    @State private var showAddLocationSheet = false
    @State private var isEditing = false
    @State private var locationToDelete: InventoryLocation?

    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared

    // Use @Query with sort descriptor for efficient loading
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) private var allLocations: [InventoryLocation]

    @Query(sort: \Home.purchaseDate) private var homes: [Home]

    private var activeHome: Home? {
        guard let activeIdString = settings.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    // Filter locations by active home
    private var locations: [InventoryLocation] {
        guard !showAllHomes, let activeHome = activeHome else {
            return allLocations
        }
        return allLocations.filter { $0.home?.id == activeHome.id }
    }

    // Query for items without location
    @Query(
        filter: #Predicate<InventoryItem> { item in
            item.location == nil
        }) private var unassignedItems: [InventoryItem]

    // Computed property for unassigned items count and total value
    private var unassignedItemsCount: Int {
        unassignedItems.count
    }

    private var unassignedItemsTotalValue: Decimal {
        unassignedItems.reduce(0) { $0 + $1.price }
    }

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
        .background(
            RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
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
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAddLocationSheet = true
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
                            .accessibilityIdentifier("locations-no-location-card")
                        }

                        ForEach(filteredLocations) { location in
                            if isEditing {
                                Button {
                                    locationToDelete = location
                                } label: {
                                    LocationItemCard(location: location)
                                        .frame(maxWidth: 180)
                                        .overlay(alignment: .topLeading) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title)
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .red)
                                                .offset(x: -8, y: -8)
                                        }
                                }
                                .accessibilityIdentifier("location-delete-\(location.name)")
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink(value: location) {
                                    LocationItemCard(location: location)
                                        .frame(maxWidth: 180)
                                }
                            }
                        }
                    }
                    .padding()
                    .animation(.default, value: filteredLocations.map(\.id))
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isEditing.toggle()
                        } label: {
                            Text(isEditing ? "Done" : "Edit")
                        }
                        .accessibilityIdentifier("locations-edit-button")
                    }
                    if !isEditing {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showAddLocationSheet = true
                            } label: {
                                Label("Add Location", systemImage: "plus")
                            }
                            .accessibilityIdentifier("addLocation")
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
        .sheet(isPresented: $showAddLocationSheet) {
            NavigationStack {
                EditLocationView(location: nil, isEditing: true, presentedInSheet: true)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "Delete Location?",
            isPresented: Binding(
                get: { locationToDelete != nil },
                set: { if !$0 { locationToDelete = nil } }
            ),
            presenting: locationToDelete
        ) { location in
            Button("Delete", role: .destructive) {
                deleteLocation(location)
            }
            Button("Cancel", role: .cancel) {}
        } message: { location in
            Text("\"\(location.name)\" will be deleted. Any items in this location will be unassigned.")
        }
        .onAppear {
            print("LocationsListView: Total number of locations: \(locations.count)")
        }
    }

    private func deleteLocation(_ location: InventoryLocation) {
        withAnimation {
            modelContext.delete(location)
            TelemetryManager.shared.trackLocationDeleted()
            try? modelContext.save()
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return LocationsListView(showAllHomes: false)
            .modelContainer(previewer.container)
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
