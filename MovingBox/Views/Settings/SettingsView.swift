//
//  SettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/4/24.
//

import SwiftUI
import SwiftData
import SafariServices
import StoreKit

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
    @EnvironmentObject private var settingsManager: SettingsManager
    @ObservedObject private var revenueCatManager: RevenueCatManager = .shared
    @EnvironmentObject var router: Router
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: SettingsSection? = .categories // Default selection
    @State private var safariLink: SafariLinkData? = nil
    @State private var showingPaywall = false
    @State private var showingICloudAlert = false
    
    
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
            url: URL(string: "itms-apps://itunes.apple.com/app/id6742755218?action=write-review")!
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
                    .foregroundColor(.customPrimary)
                    .listRowInsets(EdgeInsets())
                }
            }
            
            Section("Home Settings") {
                Group {
                    NavigationLink(value: "home") {
                        Label {
                            Text("Home Details")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "house")
                                .foregroundStyle(Color.customPrimary)
                        }
                    }
                    NavigationLink(value: "locations") {
                        Label {
                            Text("Location Settings")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "location")
                                .foregroundStyle(Color.customPrimary)
                        }
                    }
                    NavigationLink(value: "labels") {
                        Label {
                            Text("Label Settings")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "tag")
                                .foregroundStyle(Color.customPrimary)
                        }
                    }
                }
            }
            
            if revenueCatManager.isProSubscriptionActive {
                Section("Subscription Status") {
                    NavigationLink(value: Router.Destination.subscriptionSettingsView) {
                        Label {
                            Text("Subscription Details")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "creditcard")
                                .foregroundStyle(Color.customPrimary)
                        }
                    }
                }
            }
            
            Section("Sync & Backup") {
                NavigationLink(value: "importExport") {
                    Label {
                        Text("Import & Export")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "doc.plaintext")
                            .foregroundStyle(Color.customPrimary)
                    }
                }
                .accessibilityIdentifier("importExportLink")
                Text("Your data is automatically synced across all your devices using iCloud")
                    .foregroundStyle(.secondary)
            }
            
            Section {
                HStack {
                    Label {
                        Text("High Detail")
                            .foregroundStyle(settingsManager.isPro ? .primary : .secondary)
                    } icon: {
                        Image(systemName: "brain")
                            .foregroundStyle(settingsManager.isPro ? Color.customPrimary : .secondary)
                    }
                    
                    Spacer()
                    if !settingsManager.isPro {
                        Text("Pro")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.yellow)
                            .cornerRadius(4)
                    }
                    if settingsManager.isHighQualityToggleAvailable {
                        Toggle("", isOn: $settingsManager.highQualityAnalysisEnabled)
                            .onChange(of: settingsManager.highQualityAnalysisEnabled) { _, newValue in
                                TelemetryManager.shared.trackHighQualityToggleUsed(
                                    enabled: newValue,
                                    isProUser: settingsManager.isPro
                                )
                            }
                    } else {
                        Toggle("", isOn: .constant(false))
                            .disabled(true)
                    }
                }
            } header: {
                Text("AI Analysis")
            } footer: {
                if !settingsManager.isHighQualityToggleAvailable {
                    Text("High quality analysis with 1250x1250 resolution and advanced AI models is available with MovingBox Pro.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if settingsManager.highQualityAnalysisEnabled {
                    Text("Using 1250x1250 resolution with high detail for enhanced accuracy. Disable for faster image analysis.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Using 512x512 resolution with low detail for faster image analysis.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Community & Support") {
                ForEach([
                    externalLinks["knowledgeBase"]!,
                    externalLinks["support"]!,
                    externalLinks["bugs"]!
                ], id: \.title) { link in
                    externalLinkButton(for: link)
                }
                
                Button {
                    requestAppReview()
                } label: {
                    HStack {
                        Label {
                            Text("Rate Us")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "star")
                                .foregroundStyle(Color.customPrimary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            Section("About") {
                HStack {
                    Label {
                        Text("Version")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.customPrimary)
                    }
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                ForEach([
                    externalLinks["roadmap"]!,
                    externalLinks["privacyPolicy"]!,
                    externalLinks["termsOfService"]!
                ], id: \.title) { link in
                    externalLinkButton(for: link)
                }
            }
        }
        .navigationTitle("Settings")
        .tint(Color.customPrimary)
        .sheet(item: $safariLink) { linkData in
            SafariView(url: linkData.url)
                .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showingPaywall) {
            revenueCatManager.presentPaywall(
                isPresented: $showingPaywall,
                onCompletion: {
                    settingsManager.isPro = true
                },
                onDismiss: nil
            )
        }
        .navigationDestination(for: String.self) { value in
            switch value {
                case "home": EditHomeView()
                case "locations": LocationSettingsView()
                case "labels": LabelSettingsView()
                case "importExport": ImportExportSettingsView()
                default: EmptyView()
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
    
    private func externalLinkButton(for link: ExternalLink) -> some View {
        Button {
            print("Button tapped for: \(link.title) with URL: \(link.url.absoluteString)")
            safariLink = SafariLinkData(url: link.url)
        } label: {
            HStack {
                Label {
                    Text(link.title)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: link.icon)
                        .foregroundStyle(Color.customPrimary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func requestAppReview() {
        if #available(iOS 18.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
                print("Requested app review using AppStore API")
            }
        } else {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
                print("Requested app review using legacy API")
            } else {
                if let url = URL(string: "itms-apps://itunes.apple.com/app/id6742755218?action=write-review") {
                    UIApplication.shared.open(url)
                    print("Opening App Store URL for review")
                }
            }
        }
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        print("SafariView - Creating controller for URL: \(url.absoluteString)")
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        
        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.delegate = context.coordinator
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // We don't update the controller - each time we show a new URL, we create a new controller
    }
    
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
    }
}

// MARK: - Safari Link Data
struct SafariLinkData: Identifiable {
    let url: URL
    let id = UUID()
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
    @EnvironmentObject var settings: SettingsManager
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
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()
                Button("Add Location", systemImage: "plus") {
                    addLocation()
                }
                .accessibilityIdentifier("addLocation")
            }
        }
    }
    
    func addLocation() {
        router.navigate(to: .editLocationView(location: nil, isEditing: true))
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
        if labels.isEmpty {
            ContentUnavailableView(
                "No Labels",
                systemImage: "tag",
                description: Text("Add labels to categorize your items.")
            )
        } else {
            List {
                ForEach(labels) { label in
                    NavigationLink {
                        EditLabelView(label: label)
                    } label: {
                        Text(label.emoji)
                            .padding(7)
                            .background(in: Circle())
                            .backgroundStyle(Color(label.color ?? .blue))
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
                        router.navigate(to: .editLabelView(label: nil, isEditing: true))
                    } label: {
                        Label("Add Label", systemImage: "plus")
                    }
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
