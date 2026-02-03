//
//  MainSplitView.swift
//  MovingBox
//
//  Created by Claude Code
//

import Dependencies
import SQLiteData
import SwiftUI

struct MainSplitView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject private var settingsManager: SettingsManager
    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default) private var homes: [SQLiteHome]
    @Binding var navigationPath: NavigationPath
    @State private var currentTintColor: Color = .green

    private var primaryHome: SQLiteHome? {
        homes.first { $0.isPrimary }
    }

    private var activeHome: SQLiteHome? {
        guard let activeIdString = settingsManager.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
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
        let newColor = Color.homeColor(for: activeHome?.colorName ?? "green")
        print("🎨 MainSplitView - Updating tint color to: \(activeHome?.colorName ?? "green")")
        currentTintColor = newColor
    }

    @ViewBuilder
    private func detailView(for sidebarDestination: Router.SidebarDestination?) -> some View {
        switch sidebarDestination {
        case .dashboard:
            DashboardView()
        case .home(let homeId):
            DashboardView(homeID: homeId)
        case .allInventory:
            InventoryListView(locationID: nil, showAllHomes: true)
        case .label(let labelId):
            InventoryListView(locationID: nil, filterLabelID: labelId)
        case .location(let locationId):
            InventoryListView(locationID: locationId)
        case .none:
            DashboardView()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: Router.Destination, navigationPath: Binding<NavigationPath>)
        -> some View
    {
        switch destination {
        case .dashboardView:
            DashboardView()
        case .locationsListView(let showAllHomes):
            LocationsListView(showAllHomes: showAllHomes)
        case .labelsListView(let showAllHomes):
            LabelsListView(showAllHomes: showAllHomes)
        case .settingsView:
            SettingsView()
        case .aISettingsView:
            AISettingsView()
        case .inventoryListView(let locationID, let showAllHomes):
            InventoryListView(locationID: locationID, showAllHomes: showAllHomes)
        case .inventoryListViewForLabel(let labelID):
            InventoryListView(locationID: nil, filterLabelID: labelID)
        case .editLocationView(let locationID, let isEditing):
            EditLocationView(locationID: locationID, isEditing: isEditing)
        case .editLabelView(let labelID, let isEditing):
            EditLabelView(labelID: labelID, isEditing: isEditing)
        case .inventoryDetailView(let itemID, let showSparklesButton, let isEditing):
            InventoryDetailView(
                itemID: itemID, navigationPath: navigationPath, showSparklesButton: showSparklesButton,
                isEditing: isEditing)
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
        case .globalLabelSettingsView:
            GlobalLabelSettingsView()
        case .insurancePolicyListView:
            InsurancePolicyListView()
        case .insurancePolicyDetailView(let policyID):
            InsurancePolicyDetailView(policyID: policyID)
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
            InventoryListView(locationID: nil, showOnlyUnassigned: true)
        default:
            EmptyView()
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    PreviewWrapper()
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}

private struct PreviewWrapper: View {
    @State private var path = NavigationPath()

    var body: some View {
        MainSplitView(navigationPath: $path)
    }
}
