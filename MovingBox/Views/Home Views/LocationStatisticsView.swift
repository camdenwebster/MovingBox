//
//  LocationStatisticsView.swift
//  MovingBox
//
//  Created by AI Assistant on 1/10/25.
//

import SwiftData
import SwiftUI

struct LocationStatisticsView: View {
    @Query(sort: [SortDescriptor(\InventoryLocation.name)]) private var allLocations: [InventoryLocation]
    @Query(sort: \Home.purchaseDate) private var homes: [Home]
    @EnvironmentObject var router: Router
    @EnvironmentObject var settingsManager: SettingsManager

    private let row = GridItem(.fixed(160))

    private var activeHome: Home? {
        guard let activeIdString = settingsManager.activeHomeId,
              let activeId = UUID(uuidString: activeIdString) else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    // Filter locations by active home
    private var locations: [InventoryLocation] {
        guard let activeHome = activeHome else {
            return allLocations
        }
        return allLocations.filter { $0.home?.id == activeHome.id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                router.navigate(to: .locationsListView)
            } label: {
                DashboardSectionLabel(text: "Locations")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard-locations-button")

            if locations.isEmpty {
                ContentUnavailableView {
                        Label("No Locations", systemImage: "map")
                    } description: {
                        Text("Add locations to organize your items")
                    } actions: {
                        Button("Add a Location") {
                            router.navigate(to: .editLocationView(location: nil))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(height: 160)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [row], spacing: 16) {
                        ForEach(locations) { location in
                            NavigationLink(value: Router.Destination.inventoryListView(location: location)) {
                                LocationItemCard(location: location)
                                    .frame(width: 180)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return LocationStatisticsView()
            .modelContainer(previewer.container)
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
