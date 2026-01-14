//
//  SidebarView.swift
//  MovingBox
//
//  Created by Claude Code
//

import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager
    @Query(sort: \InventoryLabel.name) private var allLabels: [InventoryLabel]
    @Query(sort: \InventoryLocation.name) private var allLocations: [InventoryLocation]
    @Query(sort: \Home.purchaseDate) private var homes: [Home]
    @Binding var selection: Router.SidebarDestination?

    // MARK: - Computed Properties

    private var primaryHome: Home? {
        homes.first { $0.isPrimary }
    }

    private var secondaryHomes: [Home] {
        homes.filter { !$0.isPrimary }.sorted { $0.name < $1.name }
    }

    private var activeHome: Home? {
        guard let activeIdString = settingsManager.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return primaryHome
        }
        return homes.first { $0.id == activeId } ?? primaryHome
    }

    private var filteredLocations: [InventoryLocation] {
        guard let activeHome = activeHome else {
            return []
        }
        return allLocations.filter { $0.home?.id == activeHome.id }
    }

    private var filteredLabels: [InventoryLabel] {
        guard let activeHome = activeHome else {
            return []
        }
        return allLabels.filter { $0.home?.id == activeHome.id }
    }

    // MARK: - Body

    var body: some View {
        List(selection: $selection) {

            // All Inventory
            NavigationLink(value: Router.SidebarDestination.allInventory) {
                Label("All Inventory", systemImage: "shippingbox.fill")
                    .tint(.green)
            }

            // Homes Section
            Section("Homes") {
                ForEach(homes, id: \.persistentModelID) { home in
                    NavigationLink(value: Router.SidebarDestination.home(home.persistentModelID)) {
                        SidebarHomeRow(home: home, isActive: home.id == activeHome?.id)
                    }
                }
            }

            // Locations Section (filtered by active home)
            Section("Locations") {
                if filteredLocations.isEmpty {
                    Text("No locations")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(filteredLocations, id: \.persistentModelID) { location in
                        NavigationLink(value: Router.SidebarDestination.location(location.persistentModelID)) {
                            Label {
                                Text(location.name)
                            } icon: {
                                if let sfSymbol = location.sfSymbolName {
                                    Image(systemName: sfSymbol)
                                } else {
                                    Image(systemName: "mappin.circle.fill")
                                }
                            }
                        }
                    }
                }
            }

            // Labels Section (filtered by active home)
            Section("Labels") {
                if filteredLabels.isEmpty {
                    Text("No labels")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(filteredLabels, id: \.persistentModelID) { label in
                        NavigationLink(value: Router.SidebarDestination.label(label.persistentModelID)) {
                            Label {
                                let backgroundColor = Color(label.color ?? .blue)
                                Text(label.name)
                                    .fontDesign(.rounded)
                                    .fontWeight(.bold)
                                    .foregroundStyle(backgroundColor.idealTextColor())
                                    .padding(7)
                                    .background(in: Capsule())
                                    .backgroundStyle(backgroundColor.gradient)
                            } icon: {
                                Text(label.emoji)

                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selection) { _, newValue in
            updateActiveHome(for: newValue)
        }
    }

    // MARK: - Helper Methods

    private func updateActiveHome(for destination: Router.SidebarDestination?) {
        guard let destination = destination else { return }

        switch destination {
        case .dashboard:
            // Set active home to primary home
            if let primaryHome = primaryHome {
                settingsManager.activeHomeId = primaryHome.id.uuidString
            }

        case .home(let homeId):
            // Set active home to selected home
            if let home = homes.first(where: { $0.persistentModelID == homeId }) {
                settingsManager.activeHomeId = home.id.uuidString
            }

        default:
            // For other destinations (labels, locations, all inventory), don't change active home
            break
        }
    }
}

// MARK: - Sidebar Row Views

struct SidebarHomeRow: View {
    let home: Home
    let isActive: Bool

    var body: some View {
        HStack {
            Label(home.displayName, systemImage: "building.2")

            if home.isPrimary {
                Text("PRIMARY")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green)
                    .cornerRadius(4)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark")
            }
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return NavigationSplitView {
            SidebarView(selection: .constant(.dashboard))
                .modelContainer(previewer.container)
        } detail: {
            Text("Select an item")
        }
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
