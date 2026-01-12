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
    @Query(sort: \Home.purchaseDate) private var homes: [Home]
    @Query(sort: \InventoryLabel.name) private var labels: [InventoryLabel]
    @Query(sort: \InventoryLocation.name) private var locations: [InventoryLocation]

    @Binding var selection: Router.SidebarDestination?

    private var home: Home? {
        return homes.last
    }

    var body: some View {
        List(selection: $selection) {
            Section("Homes") {
                // Dashboard
                NavigationLink(value: Router.SidebarDestination.dashboard) {
                    Label(
                        (home?.name.isEmpty == false ? home?.name : nil) ?? "Dashboard",
                        systemImage: "house.fill"
                    )
                    .tint(.green)
                }
            }

            // All Inventory
            NavigationLink(value: Router.SidebarDestination.allInventory) {
                Label("All Inventory", systemImage: "shippingbox.fill")
                    .tint(.green)
            }

            // Locations Section
            Section("Locations") {
                if locations.isEmpty {
                    Text("No locations")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(locations, id: \.persistentModelID) { location in
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

            // Labels Section
            Section("Labels") {
                if labels.isEmpty {
                    Text("No labels")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(labels, id: \.persistentModelID) { label in
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
    }
}
//
//#Preview {
//    do {
//        let previewer = try Previewer()
//        return NavigationSplitView {
//            SidebarView(selection: .constant(.dashboard))
//                .modelContainer(previewer.container)
//        } detail: {
//            Text("Select an item")
//        }
//    } catch {
//        return Text("Failed to create preview: \(error.localizedDescription)")
//    }
//}
