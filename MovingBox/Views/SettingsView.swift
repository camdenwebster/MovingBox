//
//  SettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/4/24.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager()
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: AISettingsView(settings: settings)) {
                    Label("AI Settings", systemImage: "brain")
                }
                
                NavigationLink(destination: LocationSettingsView()) {
                    Label("Location Settings", systemImage: "location")
                }
                
                NavigationLink(destination: LabelSettingsView()) {
                    Label("Label Settings", systemImage: "tag")
                }
                
                NavigationLink(destination: AboutView()) {
                    Label("About", systemImage: "info.circle")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// Placeholder Views
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
            
            Section(header: Text("API Configuration")) {
                HStack(spacing: 0) {
                    Text("OpenAI API Key")
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
                
                // Added high detail toggle
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
        }
        .navigationTitle("Location Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LabelSettingsView: View {
    var body: some View {
        Text("Label Settings")
            .navigationTitle("Label Settings")
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
