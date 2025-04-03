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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @State private var path = NavigationPath()
    @State private var sortOrder = [SortDescriptor(\InventoryLocation.name)]
    @State private var showingPaywall = false
    @State private var showLimitAlert = false
    
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    
    // CHANGE: Make grid layout adaptive
    private var columns: [GridItem] {
        // Card width + padding on each side
        let minimumCardWidth: CGFloat = 160
        
        // Use more columns on larger devices
        let columnCount = horizontalSizeClass == .regular ? 4 : 2
        
        return Array(repeating: GridItem(.adaptive(minimum: minimumCardWidth), spacing: 16), count: columnCount)
    }
    
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
                                .frame(maxWidth: 180)
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
            Button("Add Item", systemImage: "plus") {
                if settings.shouldShowFirstLocationPaywall(locationCount: locations.count) {
                    showingPaywall = true
                } else if settings.hasReachedLocationLimit(currentCount: locations.count) {
                    showLimitAlert = true
                } else {
                    addLocation()
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            MovingBoxPaywallView()
        }
        .alert("Upgrade to Pro", isPresented: $showLimitAlert) {
            Button("Upgrade") {
                showingPaywall = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You've reached the maximum number of locations (\(SettingsManager.maxFreeLocations)) for free users. Upgrade to Pro for unlimited locations!")
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
