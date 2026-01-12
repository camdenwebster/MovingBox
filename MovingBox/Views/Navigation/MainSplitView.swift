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
    @EnvironmentObject private var settingsManager: SettingsManager
    @Query(sort: \Home.purchaseDate) private var homes: [Home]
    @Binding var navigationPath: NavigationPath
    @State private var currentTintColor: Color = .green
    
    private var primaryHome: Home? {
        homes.first { $0.isPrimary }
    }
    
    private var activeHome: Home? {
        guard let activeIdString = settingsManager.activeHomeId,
              let activeId = UUID(uuidString: activeIdString) else {
            return primaryHome
        }
        return homes.first { $0.id == activeId } ?? primaryHome
    }

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
        .tint(currentTintColor)
        .onAppear {
            updateTintColor()
        }
        .onChange(of: settingsManager.activeHomeId) { oldValue, newValue in
            print("🎨 MainSplitView - activeHomeId changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
            updateTintColor()
        }
        .onChange(of: homes) { oldValue, newValue in
            print("🎨 MainSplitView - Homes changed, updating tint color")
            updateTintColor()
        }
    }
    
    private func updateTintColor() {
        let newColor = activeHome?.color ?? .green
        print("🎨 MainSplitView - Updating tint color to: \(activeHome?.colorName ?? "green")")
        currentTintColor = newColor
    }

    @ViewBuilder
    private func detailView(for sidebarDestination: Router.SidebarDestination?) -> some View {
        switch sidebarDestination {
        case .dashboard:
            DashboardView()
        case .home(let homeId):
            if let home = modelContext.model(for: homeId) as? Home {
                DashboardView(home: home)
            } else {
                ContentUnavailableView("Home Not Found", systemImage: "house.slash")
            }
        case .allInventory:
            InventoryListView(location: nil, showAllHomes: true)
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
        case .locationsListView(let showAllHomes):
            LocationsListView(showAllHomes: showAllHomes)
        case .settingsView:
            SettingsView()
        case .aISettingsView:
            AISettingsView()
        case .inventoryListView(let location, let showAllHomes):
            InventoryListView(location: location, showAllHomes: showAllHomes)
        case .editLocationView(let location, let isEditing):
            EditLocationView(location: location, isEditing: isEditing)
        case .editLabelView(let label, let isEditing):
            EditLabelView(label: label, isEditing: isEditing)
        case .inventoryDetailView(let item, let showSparklesButton, let isEditing):
            InventoryDetailView(inventoryItemToDisplay: item, navigationPath: navigationPath, showSparklesButton: showSparklesButton, isEditing: isEditing)
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
        case .homeListView:
            HomeListView()
        case .addHomeView:
            AddHomeView()
        case .aboutView:
            AboutView()
        case .featureRequestView:
            FeatureRequestView()
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
            .environmentObject(SettingsManager())
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
