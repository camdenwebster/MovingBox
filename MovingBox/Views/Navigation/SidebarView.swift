//
//  SidebarView.swift
//  MovingBox
//
//  Created by Claude Code
//

import SQLiteData
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @FetchAll(SQLiteInventoryLabel.order(by: \.name), animation: .default)
    private var allLabels: [SQLiteInventoryLabel]
    @FetchAll(SQLiteInventoryLocation.order(by: \.name), animation: .default)
    private var allLocations: [SQLiteInventoryLocation]
    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]
    @Binding var selection: Router.SidebarDestination?

    // State to force re-render when active home changes
    @State private var activeHomeIdTrigger: String?

    // MARK: - Computed Properties

    private var primaryHome: SQLiteHome? {
        homes.first { $0.isPrimary }
    }

    private var secondaryHomes: [SQLiteHome] {
        homes.filter { !$0.isPrimary }.sorted { $0.name < $1.name }
    }

    private var activeHome: SQLiteHome? {
        // Use activeHomeIdTrigger to ensure SwiftUI tracks this dependency
        let activeIdString = activeHomeIdTrigger ?? settingsManager.activeHomeId
        guard let idString = activeIdString,
            let activeId = UUID(uuidString: idString)
        else {
            return primaryHome
        }
        return homes.first { $0.id == activeId } ?? primaryHome
    }

    private var filteredLocations: [SQLiteInventoryLocation] {
        guard let activeHome = activeHome else {
            return []
        }
        return allLocations.filter { $0.homeID == activeHome.id }
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
                ForEach(homes) { home in
                    NavigationLink(value: Router.SidebarDestination.home(home.id)) {
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
                    ForEach(filteredLocations) { location in
                        NavigationLink(value: Router.SidebarDestination.location(location.id)) {
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

            // Labels Section (global across all homes)
            Section("Labels") {
                if allLabels.isEmpty {
                    Text("No labels")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(allLabels) { label in
                        NavigationLink(
                            value:
                                Router.SidebarDestination.label(label.id)
                        ) {
                            LabelCapsuleView(label: label)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            // Sync activeHomeId on initial load
            activeHomeIdTrigger = settingsManager.activeHomeId
            updateActiveHome(for: selection)
        }
        .onChange(of: selection) { _, newValue in
            updateActiveHome(for: newValue)
        }
        .onChange(of: settingsManager.activeHomeId) { _, newValue in
            // Sync local trigger to force re-render when active home changes
            activeHomeIdTrigger = newValue
            print(
                "📍 SidebarView - activeHomeId changed to: \(newValue ?? "nil"), filtered locations: \(filteredLocations.count)"
            )
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
            settingsManager.activeHomeId = homeId.uuidString

        default:
            // For other destinations (labels, locations, all inventory), don't change active home
            break
        }
    }
}

// MARK: - Sidebar Row Views

struct SidebarHomeRow: View {
    let home: SQLiteHome
    let isActive: Bool

    var body: some View {
        HStack {
            Label(home.displayName, systemImage: "building.2")

            if home.isPrimary {
                Text("PRIMARY")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green)
                    .clipShape(.rect(cornerRadius: 4))
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark")
            }
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    NavigationSplitView {
        SidebarView(selection: .constant(.dashboard))
    } detail: {
        Text("Select an item")
    }
}
