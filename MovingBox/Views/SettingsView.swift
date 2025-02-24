//
//  SettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/4/24.
//

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
                            .frame(alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }

                }
            }
            
            Section(header: Text("API Configuration")) {
                HStack {
                    Text("OpenAI API Key")
                    Spacer()
                    if isEditing {
                        TextField("", text: $settings.apiKey)
                            .multilineTextAlignment(.trailing)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .frame(maxWidth: 200)
                            .focused($isApiKeyFieldFocused)
                    } else {                            
                        Text(settings.apiKey)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 200, alignment: .trailing)
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
    var body: some View {
        Text("Location Settings")
            .navigationTitle("Location Settings")
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
    SettingsView()
}
