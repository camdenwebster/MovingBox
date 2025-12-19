//
//  MainSplitView.swift
//  MovingBox
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct MainSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var router: Router
    @Binding var navigationPath: NavigationPath

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $router.sidebarSelection)
        } detail: {
            NavigationStack(path: $navigationPath) {
                detailView(for: router.sidebarSelection)
                    .navigationDestination(for: Router.Destination.self) { destination in
                        destinationView(for: destination, navigationPath: $navigationPath)
                    }
                    .navigationDestination(for: String.self) { destination in
                        stringDestinationView(for: destination)
                    }
            }
        }
        .tint(.green)
    }

    @ViewBuilder
    private func detailView(for sidebarDestination: Router.SidebarDestination?) -> some View {
        switch sidebarDestination {
        case .dashboard:
            DashboardView()
        case .allInventory:
            InventoryListView(location: nil)
        case .label(let labelId):
            if let label = modelContext.model(for: labelId) as? InventoryLabel {
                InventoryListView(location: nil, filterLabel: label)
            } else {
                ContentUnavailableView("Label Not Found", systemImage: "tag.slash")
            }
        case .location(let locationId):
            if let location = modelContext.model(for: locationId) as? InventoryLocation {
                InventoryListView(location: location)
            } else {
                ContentUnavailableView("Location Not Found", systemImage: "mappin.slash")
            }
        case .none:
            DashboardView()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: Router.Destination, navigationPath: Binding<NavigationPath>) -> some View {
        switch destination {
        case .dashboardView:
            DashboardView()
        case .locationsListView:
            LocationsListView()
        case .settingsView:
            SettingsView()
        case .aISettingsView:
            AISettingsView()
        case .inventoryListView(let location):
            InventoryListView(location: location)
        case .editLocationView(let location, let isEditing):
            EditLocationView(location: location, isEditing: isEditing)
        case .editLabelView(let label, let isEditing):
            EditLabelView(label: label, isEditing: isEditing)
        case .inventoryDetailView(let item, let showSparklesButton, let isEditing):
            InventoryDetailView(inventoryItemToDisplay: item, navigationPath: navigationPath, showSparklesButton: showSparklesButton, isEditing: isEditing)
        case .addInventoryItemView(let location):
            AddInventoryItemView(location: location)
        case .locationsSettingsView:
            LocationSettingsView()
        case .subscriptionSettingsView:
            SubscriptionSettingsView()
        case .syncDataSettingsView:
            SyncDataSettingsView()
        case .importDataView:
            ImportDataView()
        case .exportDataView:
            ExportDataView()
        case .deleteDataView:
            DataDeletionView()
        }
    }

    @ViewBuilder
    private func stringDestinationView(for destination: String) -> some View {
        switch destination {
        case "appearance":
            AppearanceSettingsView()
        case "notifications":
            NotificationSettingsView()
        case "ai":
            AISettingsView()
        case "locations":
            LocationSettingsView()
        case "labels":
            LabelSettingsView()
        case "home":
            EditHomeView()
        case "no-location":
            InventoryListView(location: nil, showOnlyUnassigned: true)
        default:
            EmptyView()
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return PreviewWrapper()
            .modelContainer(previewer.container)
            .environmentObject(Router())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

private struct PreviewWrapper: View {
    @State private var path = NavigationPath()

    var body: some View {
        MainSplitView(navigationPath: $path)
    }
}
