//
//  SettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/4/24.
//

import SwiftUI
import SwiftData
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
    @StateObject private var settingsManager = SettingsManager()
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared
    @EnvironmentObject var router: Router
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: SettingsSection? = .categories // Default selection
    @State private var showingSafariView = false
    @State private var selectedURL: URL?
    @State private var showingPaywall = false
    @State private var showingICloudAlert = false
    @Query private var homes: [Home]
    private var home: Home { homes.first ?? Home() }
    
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
        NavigationView {
            List {
                if !revenueCatManager.isProSubscriptionActive {
                    Section {
                        Button(action: {
                            showingPaywall = true
                        }) {
                            Text("Get MovingBox Pro")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(10)
                        }
                        .listRowInsets(EdgeInsets())
                    }
                }
                
                Section("Home Settings") {
                    NavigationLink(value: "home") {
                        Label("Home Details", systemImage: "house")
                    }
                    NavigationLink(value: "locations") {
                        Label("Location Settings", systemImage: "location")
                    }
                    NavigationLink(value: "labels") {
                        Label("Label Settings", systemImage: "tag")
                    }
                }
                
                if revenueCatManager.isProSubscriptionActive {
                    Section("Subscription Status") {
                        NavigationLink {
                            SubscriptionSettingsView()
                        } label: {
                            Label("Subscription Details", systemImage: "creditcard")
                        }
                    }
                }
                
                Section("Sync & Backup") {
                    if revenueCatManager.isProSubscriptionActive {
                        NavigationLink {
                            ICloudSettingsView(settingsManager: settingsManager)
                        } label: {
                            Label("iCloud Settings", systemImage: "icloud")
                        }
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Label("iCloud Settings", systemImage: "icloud")
                                Spacer()
                                Text("PRO")
                                    .font(.caption2)
                                    .padding(4)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.yellow)
                                    .cornerRadius(4)
                            }
                        }
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
                    AISettingsView(settings: settingsManager)
                case "locations":
                    LocationSettingsView()
                case "labels":
                    LabelSettingsView()
                case "home":
                    EditHomeView()
                case "icloud":
                    ICloudSettingsView(settingsManager: settingsManager)
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
                default:
                    EmptyView()
                }
            }
            .sheet(isPresented: $showingSafariView) {
                if let url = selectedURL {
                    SafariView(url: url)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                revenueCatManager.presentPaywall(
                    isPresented: $showingPaywall,
                    onCompletion: {
                        // Update settings manager when purchase completes
                        settingsManager.isPro = true
                    },
                    onDismiss: nil
                )
            }
            .alert("Pro Feature", isPresented: $showingICloudAlert) {
                Button("Not Now", role: .cancel) { }
                Button("Upgrade to Pro") {
                    showingPaywall = true
                }
            } message: {
                Text("iCloud sync is available exclusively to Pro subscribers.")
            }
        }
    }
    
    private struct FeatureRow: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                Text(text)
                    .foregroundColor(.primary)
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
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @State private var showingPaywall = false
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
        .sheet(isPresented: $showingPaywall) {
            revenueCatManager.presentPaywall(
                isPresented: $showingPaywall,
                onCompletion: {
                    settings.isPro = true
                    // Continue with attempted action after successful purchase
                    if settings.canAddMoreLocations(currentCount: locations.count) {
                        router.navigate(to: .editLocationView(location: nil))
                    }
                },
                onDismiss: nil
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Location", systemImage: "plus") {
                    if settings.hasReachedLocationLimit(currentCount: locations.count) {
                        showingPaywall = true
                    } else {
                        addLocation()
                    }
                }
                .accessibilityIdentifier("addLocation")
            }

        }
    }
    
    func addLocation() {
        router.navigate(to: .editLocationView(location: nil))
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

struct ICloudSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.modelContext) private var modelContext
    @State private var showRestartAlert = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable iCloud Sync", isOn: $settingsManager.iCloudEnabled)
            } footer: {
                if settingsManager.iCloudEnabled {
                    Text("Your data automatically syncs with iCloud when changes are made. Please restart the app for changes to take effect.")
                } else {
                    Text("When disabled, your data will only be stored locally on this device. Please restart the app for changes to take effect.")
                }
            }
        }
        .navigationTitle("iCloud Settings")
        .onChange(of: settingsManager.iCloudEnabled) { _, _ in
            showRestartAlert = true
        }
        .alert("App Restart Required", isPresented: $showRestartAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please restart the app for iCloud changes to take effect.")
        }
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
        
        let location1 = InventoryLocation(name: "Living Room")
        let location2 = InventoryLocation(name: "Kitchen")
        let location3 = InventoryLocation(name: "Master Bedroom")
        
        container.mainContext.insert(location1)
        container.mainContext.insert(location2)
        container.mainContext.insert(location3)
        
        return NavigationStack {
            SettingsView()
                .modelContainer(container)
                .environmentObject(Router())
                .environmentObject(RevenueCatManager.shared)
        }
    } catch {
        return Text("Failed to set up preview")
            .foregroundColor(.red)
    }
}
