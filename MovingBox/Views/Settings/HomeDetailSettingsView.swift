//
//  HomeDetailSettingsView.swift
//  MovingBox
//
//  Created by Claude on 12/20/25.
//

import SwiftUI
import SwiftData

struct HomeDetailSettingsView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @Query private var allHomes: [Home]

    let home: Home
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: String?
    
    private let availableColors: [(name: String, color: Color)] = [
        ("green", .green),
        ("blue", .blue),
        ("purple", .purple),
        ("pink", .pink),
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("teal", .teal),
        ("cyan", .cyan),
        ("indigo", .indigo),
        ("mint", .mint),
        ("brown", .brown)
    ]

    var body: some View {
        Form {
            Section("Home Details") {
                if isEditing {
                    TextField("Home Name", text: Binding(
                        get: { home.name },
                        set: { home.name = $0 }
                    ))
                } else {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(home.name.isEmpty ? "Unnamed Home" : home.name)
                            .foregroundColor(.secondary)
                    }
                }

                if isEditing {
                    Toggle("Set as Primary", isOn: Binding(
                        get: { home.isPrimary },
                        set: { newValue in
                            if newValue {
                                // Make this home primary and unmark all others
                                for otherHome in allHomes {
                                    otherHome.isPrimary = (otherHome.id == home.id)
                                }
                                // Update active home ID
                                settings.activeHomeId = home.id.uuidString
                            } else {
                                // Can't unset if it's the only home or currently primary
                                // Find another home to make primary
                                if let firstOtherHome = allHomes.first(where: { $0.id != home.id }) {
                                    firstOtherHome.isPrimary = true
                                    home.isPrimary = false
                                    settings.activeHomeId = firstOtherHome.id.uuidString
                                }
                            }
                        }
                    ))
                } else {
                    HStack {
                        Text("Primary Home")
                        Spacer()
                        if home.isPrimary {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                if isEditing {
                    HStack {
                        Text("Color")
                        Spacer()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableColors, id: \.name) { colorOption in
                                    Circle()
                                        .fill(colorOption.color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(home.colorName == colorOption.name ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            home.colorName = colorOption.name
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    HStack {
                        Text("Color")
                        Spacer()
                        Circle()
                            .fill(home.color)
                            .frame(width: 24, height: 24)
                    }
                }
            }

            Section("Address") {
                if !home.address1.isEmpty {
                    LabeledContent("Street", value: home.address1)
                }
                if !home.address2.isEmpty {
                    LabeledContent("Unit", value: home.address2)
                }
                if !home.city.isEmpty {
                    LabeledContent("City", value: home.city)
                }
                if !home.state.isEmpty {
                    LabeledContent("State", value: home.state)
                }
                if !home.zip.isEmpty {
                    LabeledContent("ZIP", value: home.zip)
                }
            }

            Section("Organization") {
                NavigationLink {
                    HomeLocationSettingsView(home: home)
                } label: {
                    Label("Locations", systemImage: "map")
                }

                NavigationLink {
                    HomeLabelSettingsView(home: home)
                } label: {
                    Label("Labels", systemImage: "tag")
                }
            }

            if allHomes.count > 1 {
                Section {
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Delete Home", systemImage: "trash")
                    }
                } footer: {
                    Text("Deleting this home will also delete all associated locations and labels. Items will remain but will be unassigned.")
                }
            }
        }
        .navigationTitle(home.name.isEmpty ? "Home Details" : home.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        try? modelContext.save()
                    }
                    isEditing.toggle()
                }
            }
        }
        .alert("Delete Home", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteHome()
            }
        } message: {
            Text("Are you sure you want to delete \(home.name.isEmpty ? "this home" : home.name)? This will also delete all locations and labels associated with this home. Items will remain but will be unassigned.")
        }
        .alert("Cannot Delete", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
    }

    private func deleteHome() {
        // Validation: can't delete if only one home exists
        if allHomes.count == 1 {
            deleteError = "You must have at least one home. Cannot delete the last remaining home."
            return
        }

        // If deleting primary home, make another home primary first
        if home.isPrimary {
            if let firstOtherHome = allHomes.first(where: { $0.id != home.id }) {
                firstOtherHome.isPrimary = true
                settings.activeHomeId = firstOtherHome.id.uuidString
            }
        }

        // Delete all locations associated with this home
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        if let locations = try? modelContext.fetch(locationDescriptor) {
            for location in locations where location.home?.id == home.id {
                // Unassign items from this location
                if let items = location.inventoryItems {
                    for item in items {
                        item.location = nil
                    }
                }
                modelContext.delete(location)
            }
        }

        // Delete all labels associated with this home
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        if let labels = try? modelContext.fetch(labelDescriptor) {
            for label in labels where label.home?.id == home.id {
                // Unassign items from this label
                if let items = label.inventoryItems {
                    for item in items {
                        item.label = nil
                    }
                }
                modelContext.delete(label)
            }
        }

        // Delete the home itself
        modelContext.delete(home)

        // Save changes
        do {
            try modelContext.save()
            router.navigateBack()
        } catch {
            deleteError = "Failed to delete home: \(error.localizedDescription)"
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Home.self, InventoryLocation.self, InventoryLabel.self, configurations: config)

        let home1 = Home(name: "Main House", address1: "123 Main St", city: "San Francisco", state: "CA", zip: "94102")
        home1.isPrimary = true

        let home2 = Home(name: "Beach House", address1: "456 Ocean Ave", city: "Santa Monica", state: "CA", zip: "90401")

        container.mainContext.insert(home1)
        container.mainContext.insert(home2)

        return NavigationStack {
            HomeDetailSettingsView(home: home1)
                .modelContainer(container)
                .environmentObject(Router())
                .environmentObject(SettingsManager())
        }
    } catch {
        return Text("Failed to set up preview: \(error.localizedDescription)")
            .foregroundColor(.red)
    }
}
