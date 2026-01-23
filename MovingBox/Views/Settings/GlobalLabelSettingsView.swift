//
//  GlobalLabelSettingsView.swift
//  MovingBox
//
//  Created by Claude on 1/17/26.
//

import SwiftData
import SwiftUI

struct GlobalLabelSettingsView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \InventoryLabel.name) private var allLabels: [InventoryLabel]

    @State private var selectedLabel: InventoryLabel?
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
                        selectedLabel = label
                    } label: {
                        HStack {
                            Text(label.emoji)
                                .padding(7)
                                .background(in: Circle())
                                .backgroundStyle(Color(label.color ?? .blue))
                            Text(label.name)
                            Spacer()
                        }
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
        .sheet(item: $selectedLabel) { label in
            NavigationStack {
                EditLabelView(label: label, isEditing: true, presentedInSheet: true)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddLabelSheet) {
            NavigationStack {
                EditLabelView(label: nil, isEditing: true, presentedInSheet: true)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    func deleteLabel(at offsets: IndexSet) {
        for index in offsets {
            let labelToDelete = allLabels[index]
            modelContext.delete(labelToDelete)
            print("Deleting label: \(labelToDelete.name)")
            TelemetryManager.shared.trackLabelDeleted()
        }
        try? modelContext.save()
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryLabel.self, configurations: config)

        let label1 = InventoryLabel(name: "Electronics", desc: "Electronic devices", emoji: "📱")
        let label2 = InventoryLabel(name: "Furniture", desc: "Home furniture", emoji: "🛋️")

        container.mainContext.insert(label1)
        container.mainContext.insert(label2)

        return NavigationStack {
            GlobalLabelSettingsView()
                .modelContainer(container)
                .environmentObject(Router())
        }
    } catch {
        return Text("Failed to set up preview: \(error.localizedDescription)")
            .foregroundStyle(.red)
    }
}
