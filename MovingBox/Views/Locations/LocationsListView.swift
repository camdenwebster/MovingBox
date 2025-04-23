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
    
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared
    
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    
    private var columns: [GridItem] {
        let minimumCardWidth: CGFloat = 160
        let columnCount = horizontalSizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.adaptive(minimum: minimumCardWidth), spacing: 16), count: columnCount)
    }
    
    var body: some View {
        Group {
            if locations.isEmpty {
                ContentUnavailableView(
                    "No Locations",
                    systemImage: "map",
                    description: Text("Add locations to organize your items by room or area.")
                )
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            addLocation()
                        } label: {
                            Label("Add Location", systemImage: "plus")
                        }
                        .accessibilityIdentifier("addLocation")
                        
                        Button {
                            router.navigate(to: .locationsSettingsView)
                        } label: {
                            Text("Edit")
                        }
                    }
                }
            } else {
                ScrollView {
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
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            addLocation()
                        } label: {
                            Label("Add Location", systemImage: "plus")
                        }
                        .accessibilityIdentifier("addLocation")
                        
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
                let location = locations[index]
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
