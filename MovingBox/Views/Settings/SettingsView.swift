//
//  SettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/4/24.
//

import SwiftData
import SwiftUI
import SafariServices

enum SettingsSection: Hashable {
    case categories
    case stores
    case legal
}

struct ExternalLink {
    let title: String
    let icon: String
    let url: URL
}

// MARK: - Main Settings Body
struct SettingsView: View {
    @StateObject private var settings = SettingsManager()
    @EnvironmentObject var router: Router
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: SettingsSection? = .categories // Default selection
    @State private var showingSafariView = false
    @State private var selectedURL: URL?
    
    private let externalLinks: [String: ExternalLink] = [
        "knowledgeBase": ExternalLink(
            title: "Knowledge Base",
            icon: "questionmark.circle",
            url: URL(string: "https://movingbox.ai/docs")!
            ),
        "support": ExternalLink(
            title: "Support",
            icon: "envelope",
            url: URL(string: "https://movingbox.ai/help")!
        ),
        "rateUs": ExternalLink(
            title: "Rate Us",
            icon: "star",
            url: URL(string: "https://movingbox.ai/rate")!
        ),
        "roadmap": ExternalLink(
            title: "Roadmap",
            icon: "map",
            url: URL(string: "https://movingbox.ai/roadmap")!
        ),
        "bugs": ExternalLink(
            title: "View and Report Issues",
            icon: "ladybug",
            url: URL(string: "https://movingbox.ai/bugs")!
        ),
        "privacyPolicy": ExternalLink(
            title: "Privacy Policy",
            icon: "lock",
            url: URL(string: "https://movingbox.ai/privacy")!
        ),
        "termsOfService": ExternalLink(
            title: "Terms of Service",
            icon: "doc.text",
            url: URL(string: "https://movingbox.ai/eula")!
        )
    ]

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section("General") {
                // TODO: Implement Appearance & Notification Settings
//                NavigationLink(value: "appearance") {
//                    Label("Apperance", systemImage: "paintbrush")
//                }
//                
//                NavigationLink(value: "notifications") {
//                    Label("Notification Settings", systemImage: "bell")
//                }
                
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
                externalLinkButton(for: externalLinks["knowledgeBase"]!)
                externalLinkButton(for: externalLinks["support"]!)
                externalLinkButton(for: externalLinks["bugs"]!)
                externalLinkButton(for: externalLinks["rateUs"]!)
            }
            
            
            Section("About") {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                externalLinkButton(for: externalLinks["roadmap"]!)
                externalLinkButton(for: externalLinks["privacyPolicy"]!)
                externalLinkButton(for: externalLinks["termsOfService"]!)
            }
        }
        .navigationTitle("Settings")
        .navigationDestination(for: String.self) { destination in
            switch destination {
            case "appearance":
                AppearanceSettingsView()
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
        .sheet(isPresented: $showingSafariView) {
            if let url = selectedURL {
                SafariView(url: url)
            }
        }
    }
    // Helper function to create external link buttons
    private func externalLinkButton(for link: ExternalLink) -> some View {
        Button {
            // Add print statement for debugging
            print("Button tapped for: \(link.title) with URL: \(link.url.absoluteString)")
            selectedURL = link.url
            showingSafariView = true
        } label: {
            HStack {
                Label(link.title, systemImage: link.icon)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Menu SubViews

struct AppearanceSettingsView: View {
    var body: some View {
        Text("Appearance Settings Here")
    }
}

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
            if locations.isEmpty {
                ContentUnavailableView(
                    "No Locations",
                    systemImage: "map",
                    description: Text("Add locations to organize your items by room or area.")
                )
            } else {
                ForEach(locations) { location in
                    NavigationLink {
                        EditLocationView(location: location)
                    } label: {
                        Text(location.name)
                    }
                }
                .onDelete(perform: deleteLocations)
            }
        }
        .navigationTitle("Location Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.navigate(to: .editLocationView(location: nil))
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
            TelemetryManager.shared.trackLocationDeleted()
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
                    router.navigate(to: .editLabelView(label: nil))
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
            TelemetryManager.shared.trackLabelDeleted()
        }
    }
}

struct AboutView: View {
    var body: some View {
        Text("About MovingBox")
            .navigationTitle("About")
    }
}

// MARK: - SafariView
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        
        let safariViewController = SFSafariViewController(url: url, configuration: configuration)
        safariViewController.delegate = context.coordinator
        safariViewController.preferredControlTintColor = .systemBlue
        
        // Print the URL to help with debugging
        print("Opening URL: \(url.absoluteString)")
        
        return safariViewController
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: SafariView
        
        init(_ parent: SafariView) {
            self.parent = parent
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
            print("Safari view did complete initial load: \(didLoadSuccessfully)")
            if !didLoadSuccessfully {
                print("Failed to load URL: \(parent.url.absoluteString)")
            }
        }
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
