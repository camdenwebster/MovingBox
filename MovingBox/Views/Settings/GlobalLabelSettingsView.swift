//
//  GlobalLabelSettingsView.swift
//  MovingBox
//
//  Created by Claude on 1/17/26.
//

import Dependencies
import SQLiteData
import SwiftUI

struct GlobalLabelSettingsView: View {
    @Dependency(\.defaultDatabase) var database

    @FetchAll(SQLiteInventoryLabel.order(by: \.name), animation: .default)
    private var allLabels: [SQLiteInventoryLabel]

    @State private var selectedLabelID: UUID?
    @State private var showAddLabelSheet = false

    var body: some View {
        List {
            if allLabels.isEmpty {
                ContentUnavailableView(
                    "No Labels",
                    systemImage: "tag",
                    description: Text("Add labels to categorize your items.")
                )
            } else {
                ForEach(allLabels) { label in
                    Button {
                        selectedLabelID = label.id
                    } label: {
                        LabelCapsuleView(label: label)
                    }
                    .accessibilityIdentifier("label-row-\(label.id.uuidString)")
                }
                .onDelete(perform: deleteLabel)
            }
        }
        .accessibilityIdentifier("labels-list")
        .navigationTitle("Labels")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .accessibilityIdentifier("labels-edit-button")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddLabelSheet = true
                } label: {
                    Label("Add Label", systemImage: "plus")
                }
                .accessibilityIdentifier("labels-add-button")
            }
        }
        .sheet(
            item: Binding(
                get: { selectedLabelID.map { IdentifiableUUID(id: $0) } },
                set: { selectedLabelID = $0?.id }
            )
        ) { wrapper in
            NavigationStack {
                EditLabelView(labelID: wrapper.id, isEditing: true, presentedInSheet: true)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddLabelSheet) {
            NavigationStack {
                EditLabelView(labelID: nil, isEditing: true, presentedInSheet: true)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    func deleteLabel(at offsets: IndexSet) {
        for index in offsets {
            let labelToDelete = allLabels[index]
            do {
                try database.write { db in
                    try SQLiteInventoryLabel.find(labelToDelete.id).delete().execute(db)
                }
                print("Deleting label: \(labelToDelete.name)")
                TelemetryManager.shared.trackLabelDeleted()
            } catch {
                print("Failed to delete label: \(error)")
            }
        }
    }
}

/// Simple wrapper to make a UUID work with sheet(item:)
private struct IdentifiableUUID: Identifiable {
    let id: UUID
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    NavigationStack {
        GlobalLabelSettingsView()
            .environmentObject(Router())
    }
}
