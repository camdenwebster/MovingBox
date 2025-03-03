//
//  SettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/4/24.
//

import SwiftData
import SwiftUI

// MARK: - Main Settings Body
struct SettingsView: View {
    @StateObject private var settings = SettingsManager()
    @EnvironmentObject var router: Router

    var body: some View {
        List {
            Section("General") {
                Label("Apperance", systemImage: "paintbrush")
                
                NavigationLink(value: "notifications") {
                    Label("Notification Settings", systemImage: "bell")
                }
                
                NavigationLink(value: "ai") {
                    Label("AI Settings", systemImage: "brain")
                }
            }
            
            Section("Home Settings") {
                NavigationLink(value: "locations") {
                    Label("Location Settings", systemImage: "location")
                }
                NavigationLink(value: "labels") {
                    Label("Label Settings", systemImage: "tag")
                }
            }
            
            Section("Community & Support") {
                Label("Knowledge Base", systemImage: "questionmark.circle")
                Label("Support", systemImage: "envelope")
            }
            
            Section("About") {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                Label("Roadmap", systemImage: "map")
                Label("Privacy Policy", systemImage: "lock")
                Label("Terms of Service", systemImage: "doc.text")
            }
        }
        .navigationTitle("Settings")
        .navigationDestination(for: String.self) { destination in
            switch destination {
            case "notifications":
                NotificationSettingsView()
            case "ai":
                AISettingsView(settings: settings)
            case "locations":
                LocationSettingsView()
            case "labels":
                LabelSettingsView()
            default:
                EmptyView()
            }
        }
        .navigationDestination(for: Router.Destination.self) { destination in
            switch destination {
            case .editLocationView(let location):
                EditLocationView(location: location)
            case .editLabelView(let label):
                EditLabelView(label: label)
            case .editInventoryItemView(let item, let showSparklesButton):
                EditInventoryItemView(inventoryItemToDisplay: item, navigationPath: $router.path, showSparklesButton: showSparklesButton)
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Settings Menu SubViews

struct NotificationSettingsView: View {
    var body: some View {
        Text("Notifications Settings Here")
    }
}

struct AISettingsView: View {
    @State private var isEditing = false
    @ObservedObject var settings: SettingsManager
    let models = ["gpt-4o", "gpt-4o-mini"]
    @FocusState private var isApiKeyFieldFocused: Bool
    
    var body: some View {
        Form {
            Section(header: Text("Model Settings")) {
                if isEditing {
                    Picker("Model", selection: $settings.aiModel) {
                        ForEach(models, id: \.self) { model in
                            Text(model)
                        }
                    }
                } else {
                    HStack {
                        Text("Model")
                        Spacer()
                        Text(settings.aiModel)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section(
                footer: Text("High detail image analysis uses 2048x2048 resolution and may take up to 4 times longer and use 4 times more credits than standard detail analysis (512x512 resolution).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            ) {
                HStack(spacing: 0) {
                    Text("API Key")
                    Spacer()
                    if isEditing {
                        TextField("", text: $settings.apiKey)
                            .multilineTextAlignment(.trailing)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .frame(maxWidth: 200, alignment: .trailing)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .focused($isApiKeyFieldFocused)
                    } else {
                        Text(settings.apiKey)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 200, alignment: .trailing)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                if isEditing {
                    Toggle("Use high detail image analysis", isOn: $settings.isHighDetail)
                } else {
                    HStack {
                        Text("Use high detail image analysis")
                        Spacer()
                        Text(settings.isHighDetail ? "On" : "Off")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                            Button("Save") {
                                isEditing = false
                            }
                            .bold()
                        } else {
                            Button("Edit") {
                                isEditing = true
                            }
                        }
                    }
            }
    }
}



struct LocationSettingsView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    
    var body: some View {
        List {
            ForEach(locations) { location in
                NavigationLink {
                    EditLocationView(location: location)
                } label: {
                    Text(location.name)
                }
            }
            .onDelete(perform: deleteLocations)
        }
        .navigationTitle("Location Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let location = InventoryLocation()
                    modelContext.insert(location)
                    router.navigate(to: .editLocationView(location: location))
                } label: {
                    Label("Add Location", systemImage: "plus")
                }
            }

        }
    }
    
    func deleteLocations(at offsets: IndexSet) {
        for index in offsets {
            let locationToDelete = locations[index]
            modelContext.delete(locationToDelete)
            print("Deleting location: \(locationToDelete.name)")
        }
    }
}

struct LabelSettingsView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @Query(sort: [
        SortDescriptor(\InventoryLabel.name)
    ]) var labels: [InventoryLabel]
    
    var body: some View {
        List {
            ForEach(labels) { label in
                NavigationLink {
                    EditLabelView(label: label)
                } label: {
                    Text(label.name)
                }
            }
            .onDelete(perform: deleteLabel)
        }
        .navigationTitle("Label Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let label = InventoryLabel()
                    modelContext.insert(label)
                    router.navigate(to: .editLabelView(label: label))
                } label: {
                    Label("Add Label", systemImage: "plus")
                }
            }

        }
    }
    
    func deleteLabel(at offsets: IndexSet) {
        for index in offsets {
            let labelToDelete = labels[index]
            modelContext.delete(labelToDelete)
            print("Deleting label: \(labelToDelete.name)")
        }
    }
}

struct AboutView: View {
    var body: some View {
        Text("About MovingBox")
            .navigationTitle("About")
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: InventoryLocation.self, configurations: config)
        
        // Create sample data with default empty descriptions
        let location1 = InventoryLocation(name: "Living Room")
        let location2 = InventoryLocation(name: "Kitchen")
        let location3 = InventoryLocation(name: "Master Bedroom")
        
        // Insert sample data
        container.mainContext.insert(location1)
        container.mainContext.insert(location2)
        container.mainContext.insert(location3)
        
        // Return the view with necessary modifiers
        return SettingsView()
            .modelContainer(container)
            .environmentObject(Router())
    } catch {
        // Return a fallback view in case of errors
        return Text("Failed to set up preview")
            .foregroundColor(.red)
    }
}
