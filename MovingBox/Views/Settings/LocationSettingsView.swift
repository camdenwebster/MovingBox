//
//  LocationSettingsView.swift
//  MovingBox
//
//  Created by Claude on 12/20/25.
//

import Dependencies
import SQLiteData
import SwiftUI

struct LocationSettingsView: View {
    @Dependency(\.defaultDatabase) var database
    @EnvironmentObject var settingsManager: SettingsManager

    @FetchAll(SQLiteInventoryLocation.order(by: \.name), animation: .default)
    private var allLocations: [SQLiteInventoryLocation]

    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]

    let homeID: UUID?

    @State private var selectedLocationID: UUID?
    @State private var showAddLocationSheet = false

    init(homeID: UUID? = nil) {
        self.homeID = homeID
    }

    private var activeHome: SQLiteHome? {
        if let homeID = homeID {
            return homes.first { $0.id == homeID }
        }
        guard let activeIdString = settingsManager.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    private var filteredLocations: [SQLiteInventoryLocation] {
        guard let activeHome = activeHome else {
            return allLocations
        }
        return allLocations.filter { $0.homeID == activeHome.id }
    }

    var body: some View {
        List {
            if filteredLocations.isEmpty {
                ContentUnavailableView(
                    "No Locations",
                    systemImage: "map",
                    description: Text("Add locations to organize items in this home.")
                )
            } else {
                Section {
                    ForEach(filteredLocations) { location in
                        Button {
                            selectedLocationID = location.id
                        } label: {
                            HStack {
                                if let symbolName = location.sfSymbolName {
                                    Image(systemName: symbolName)
                                        .frame(width: 24)
                                }
                                Text(location.name)
                                Spacer()
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .onDelete(perform: deleteLocations)
                }
            }
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()
                Button("Add Location", systemImage: "plus") {
                    showAddLocationSheet = true
                }
            }
        }
        .sheet(
            item: Binding(
                get: { selectedLocationID.map { IdentifiableUUID(id: $0) } },
                set: { selectedLocationID = $0?.id }
            )
        ) { wrapper in
            NavigationStack {
                EditLocationView(
                    locationID: wrapper.id, isEditing: true, presentedInSheet: true,
                    homeID: activeHome?.id)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddLocationSheet) {
            NavigationStack {
                EditLocationView(
                    locationID: nil, isEditing: true, presentedInSheet: true,
                    homeID: activeHome?.id)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    func deleteLocations(at offsets: IndexSet) {
        let locationsToDelete = offsets.map { filteredLocations[$0] }
        for location in locationsToDelete {
            TelemetryManager.shared.trackLocationDeleted()
            do {
                try database.write { db in
                    try SQLiteInventoryLocation.find(location.id).delete().execute(db)
                }
            } catch {
                print("Error deleting location: \(error)")
            }
        }
    }
}

// MARK: - Helpers

private struct IdentifiableUUID: Identifiable {
    let id: UUID
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    NavigationStack {
        LocationSettingsView()
            .environmentObject(SettingsManager())
    }
}
