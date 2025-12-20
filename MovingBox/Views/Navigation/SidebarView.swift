//
//  SidebarView.swift
//  MovingBox
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settingsManager: SettingsManager
    @Query(sort: \InventoryLabel.name) private var allLabels: [InventoryLabel]
    @Query(sort: \InventoryLocation.name) private var allLocations: [InventoryLocation]
    @Query(sort: \Home.name) private var homes: [Home]
    @Binding var selection: Router.SidebarDestination?

    // MARK: - Computed Properties

    private var primaryHome: Home? {
        homes.first { $0.isPrimary }
    }

    private var secondaryHomes: [Home] {
        homes.filter { !$0.isPrimary }.sorted { $0.name < $1.name }
    }

    private var activeHome: Home? {
        guard let activeId = settingsManager.activeHomeId else {
            return primaryHome
        }
        return homes.first { home in
            do {
                let idData = try JSONEncoder().encode(home.persistentModelID)
                return idData.base64EncodedString() == activeId
            } catch {
                return false
            }
        } ?? primaryHome
    }

    private var filteredLocations: [InventoryLocation] {
        guard let activeHome = activeHome else {
            return []
        }
        return allLocations.filter { $0.home?.persistentModelID == activeHome.persistentModelID }
    }

    private var filteredLabels: [InventoryLabel] {
        guard let activeHome = activeHome else {
            return []
        }
        return allLabels.filter { $0.home?.persistentModelID == activeHome.persistentModelID }
    }

    // MARK: - Body

    var body: some View {
        List(selection: $selection) {
            // Dashboard (Primary Home)
            NavigationLink(value: Router.SidebarDestination.dashboard) {
                Label("Dashboard", systemImage: "house.fill")
                    .tint(.green)
            }

            // Homes Section (only show if multiple homes exist)
            if !secondaryHomes.isEmpty {
                Section("Homes") {
                    ForEach(secondaryHomes, id: \.persistentModelID) { home in
                        NavigationLink(value: Router.SidebarDestination.home(home.persistentModelID)) {
                            Label(home.name.isEmpty ? "Unnamed Home" : home.name, systemImage: "building.2")
                        }
                    }
                }
            }

            // All Inventory
            NavigationLink(value: Router.SidebarDestination.allInventory) {
                Label("All Inventory", systemImage: "shippingbox.fill")
                    .tint(.green)
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
                                Text(label.name)
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
                do {
                    let idData = try JSONEncoder().encode(primaryHome.persistentModelID)
                    settingsManager.activeHomeId = idData.base64EncodedString()
                } catch {
                    print("Failed to encode home ID: \(error)")
                }
            }

        case .home(let homeId):
            // Set active home to selected home
            if let home = homes.first(where: { $0.persistentModelID == homeId }) {
                do {
                    let idData = try JSONEncoder().encode(home.persistentModelID)
                    settingsManager.activeHomeId = idData.base64EncodedString()
                } catch {
                    print("Failed to encode home ID: \(error)")
                }
            }

        default:
            // For other destinations (labels, locations, all inventory), don't change active home
            break
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
