//
//  HomeLabelSettingsView.swift
//  MovingBox
//
//  Created by Claude on 12/20/25.
//

import SwiftUI
import SwiftData

struct HomeLabelSettingsView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @Query private var allLabels: [InventoryLabel]

    let home: Home

    private var filteredLabels: [InventoryLabel] {
        allLabels.filter { label in
            label.home?.persistentModelID == home.persistentModelID
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if filteredLabels.isEmpty {
                ContentUnavailableView(
                    "No Labels",
                    systemImage: "tag",
                    description: Text("Add labels to categorize items in this home.")
                )
            } else {
                ForEach(filteredLabels) { label in
                    NavigationLink {
                        EditLabelView(label: label)
                    } label: {
                        HStack {
                            Text(label.emoji)
                                .padding(7)
                                .background(in: Circle())
                                .backgroundStyle(Color(label.color ?? .blue))
                            Text(label.name)
                        }
                    }
                }
                .onDelete(perform: deleteLabel)
            }
        }
        .navigationTitle("Labels")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addLabel()
                } label: {
                    Label("Add Label", systemImage: "plus")
                }
            }
        }
    }

    func addLabel() {
        let newLabel = InventoryLabel(name: "", desc: "")
        newLabel.home = home
        router.navigate(to: .editLabelView(label: newLabel, isEditing: true))
    }

    func deleteLabel(at offsets: IndexSet) {
        for index in offsets {
            let labelToDelete = filteredLabels[index]
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
        let container = try ModelContainer(for: Home.self, InventoryLabel.self, configurations: config)

        let home = Home(name: "Main House")
        container.mainContext.insert(home)

        let label1 = InventoryLabel(name: "Electronics", desc: "Electronic devices", emoji: "📱")
        label1.home = home

        let label2 = InventoryLabel(name: "Furniture", desc: "Home furniture", emoji: "🛋️")
        label2.home = home

        container.mainContext.insert(label1)
        container.mainContext.insert(label2)

        return NavigationStack {
            HomeLabelSettingsView(home: home)
                .modelContainer(container)
                .environmentObject(Router())
        }
    } catch {
        return Text("Failed to set up preview: \(error.localizedDescription)")
            .foregroundColor(.red)
    }
}
