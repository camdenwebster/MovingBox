//
//  LocationStatisticsView.swift
//  MovingBox
//
//  Created by AI Assistant on 1/10/25.
//

import SQLiteData
import SwiftUI

struct LocationStatisticsView: View {
    @FetchAll(SQLiteInventoryLocation.order(by: \.name), animation: .default)
    private var allLocations: [SQLiteInventoryLocation]
    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]
    @FetchAll(SQLiteInventoryItem.all, animation: .default)
    private var allItems: [SQLiteInventoryItem]
    @EnvironmentObject var router: Router
    @EnvironmentObject var settingsManager: SettingsManager

    private let row = GridItem(.fixed(160))

    // Precomputed lookup for item counts/values per location
    private var locationItemData: [UUID: (count: Int, value: Decimal)] {
        var result: [UUID: (count: Int, value: Decimal)] = [:]
        for item in allItems {
            guard let locationID = item.locationID else { continue }
            let price = item.price * Decimal(item.quantityInt)
            if var existing = result[locationID] {
                existing.count += 1
                existing.value += price
                result[locationID] = existing
            } else {
                result[locationID] = (count: 1, value: price)
            }
        }
        return result
    }

    private var activeHome: SQLiteHome? {
        guard let activeIdString = settingsManager.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    // Filter locations by active home
    private var locations: [SQLiteInventoryLocation] {
        guard let activeHome = activeHome else {
            return allLocations
        }
        return allLocations.filter { $0.homeID == activeHome.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                router.navigate(to: .locationsListView(showAllHomes: false))
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
                        router.navigate(to: .editLocationView(locationID: nil))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(height: 160)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [row], spacing: 16) {
                        ForEach(locations) { location in
                            NavigationLink(
                                value: Router.Destination.inventoryListView(
                                    locationID: location.id, showAllHomes: false)
                            ) {
                                LocationItemCard(
                                    location: location,
                                    itemCount: locationItemData[location.id]?.count ?? 0,
                                    totalValue: locationItemData[location.id]?.value ?? 0
                                )
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
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    LocationStatisticsView()
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
