//
//  SettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/4/24.
//

import Sentry
import StoreKit
import SwiftData
import SwiftUI
import SwiftUIBackports

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
    @State private var selectedSection: SettingsSection? = .categories  // Default selection
    @State private var showingPaywall = false
    @State private var showingICloudAlert = false
    @State private var analyzedItemsCount: Int = 0
    @Query private var allItems: [InventoryItem]

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
            title: "Rate MovingBox",
            icon: "star",
            url: URL(string: "itms-apps://itunes.apple.com/app/id6742755218?action=write-review")!
        ),
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
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("AI Analysis Usage")
                                .font(.headline)
                            Spacer()
                            Text("\(analyzedItemsCount)/50")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }

                        ProgressView(value: Double(analyzedItemsCount), total: 50)
                            .tint(progressTintColor)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.bottom, 5)

                        Text("\(50 - analyzedItemsCount) free image analyses remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                }

                Section {
                    Button(action: {
                        showingPaywall = true
                    }) {
                        Text("Get MovingBox Pro")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .cornerRadius(10)
                    }
                    .backport.glassProminentButtonStyle()
                    .listRowInsets(EdgeInsets())
                }
            }

            Section("Home Settings") {
                NavigationLink(value: Router.Destination.homeListView) {
                    Label {
                        Text("Manage Homes")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "house")
                    }
                }
                NavigationLink(value: Router.Destination.globalLabelSettingsView) {
                    Label {
                        Text("Labels")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "tag")
                    }
                }
                .accessibilityIdentifier("settings-labels-button")
            }

            if revenueCatManager.isProSubscriptionActive {
                Section("Subscription Status") {
                    NavigationLink(value: Router.Destination.subscriptionSettingsView) {
                        Label {
                            Text("Subscription Details")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "creditcard")

                        }
                    }
                }
            }

            Section("Data Management") {
                NavigationLink(value: Router.Destination.syncDataSettingsView) {
                    Label {
                        Text("Sync and Data")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "arrow.trianglehead.clockwise.icloud")

                    }
                }
                .accessibilityIdentifier("syncDataLink")
            }

            Section {
                HStack {
                    Label {
                        Text("High Detail")
                            .foregroundStyle(settingsManager.isPro ? .primary : .secondary)
                    } icon: {
                        Image(systemName: "eye")
                        //                            .foregroundStyle(settingsManager.isPro ? .primary : .secondary)
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
                    Text(
                        "High quality analysis with 1250x1250 resolution and advanced AI models is available with MovingBox Pro."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else if settingsManager.highQualityAnalysisEnabled {
                    Text(
                        "Using 1250x1250 resolution with high detail for enhanced accuracy. Disable for faster image analysis."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    Text("Using 512x512 resolution with low detail for faster image analysis.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Community & Support") {
                Button {
                    requestAppReview()
                } label: {
                    HStack {
                        Label {
                            Text("Rate Us")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "star")

                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(
                    [
                        externalLinks["knowledgeBase"]!,
                        externalLinks["support"]!,
                    ], id: \.title
                ) { link in
                    Link(destination: link.url) {
                        HStack {
                            Label {
                                Text(link.title)
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: link.icon)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                NavigationLink(value: Router.Destination.featureRequestView) {
                    Label {
                        Text("Request a Feature")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "lightbulb")
                    }
                }

                NavigationLink(value: Router.Destination.aboutView) {
                    Label {
                        Text("About")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                }
            }

            #if DEBUG
                Section("Debug") {
                    Button {
                        SentrySDK.capture(message: "Test message from MovingBox Settings")
                    } label: {
                        Label {
                            Text("Send Test Message to Sentry")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                    }

                    Button {
                        enum TestError: Error {
                            case sentryTestError
                        }
                        SentrySDK.capture(error: TestError.sentryTestError)
                    } label: {
                        Label {
                            Text("Send Test Error to Sentry")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                    }

                    Button {
                        fatalError("Test crash for Sentry")
                    } label: {
                        Label {
                            Text("Trigger Test Crash")
                                .foregroundStyle(.red)
                        } icon: {
                            Image(systemName: "xmark.octagon")
                                .foregroundStyle(.red)
                        }
                    }
                }
            #endif

        }
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle("Settings")
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
            case "syncData": SyncDataSettingsView()
            case "importData": ImportDataView()
            case "exportData": ExportDataView()
            case "deleteData": DataDeletionView()
            default: EmptyView()
            }
        }
        .navigationDestination(for: Router.Destination.self) { destination in
            switch destination {
            case .syncDataSettingsView: SyncDataSettingsView()
            case .importDataView: ImportDataView()
            case .exportDataView: ExportDataView()
            case .deleteDataView: DataDeletionView()
            case .homeListView: HomeListView()
            case .addHomeView: AddHomeView()
            case .aboutView: AboutView()
            case .featureRequestView: FeatureRequestView()
            case .globalLabelSettingsView: GlobalLabelSettingsView()
            default: EmptyView()
            }
        }
        .onAppear {
            updateAnalyzedItemsCount()
        }
    }

    private var progressTintColor: Color {
        let percentage = Double(analyzedItemsCount) / 50.0

        if percentage < 0.5 {
            return .green
        } else if percentage < 0.8 {
            return .orange
        } else {
            return .red
        }
    }

    private func updateAnalyzedItemsCount() {
        analyzedItemsCount = allItems.filter { $0.hasUsedAI == true }.count
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

    private func requestAppReview() {
        if #available(iOS 18.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }
            ) as? UIWindowScene {
                AppStore.requestReview(in: scene)
                print("Requested app review using AppStore API")
            }
        } else {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }
            ) as? UIWindowScene {
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
                footer: Text(
                    "High detail image analysis uses 2048x2048 resolution and may take up to 4 times longer and use 4 times more credits than standard detail analysis (512x512 resolution)."
                )
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
    ]) var allLocations: [InventoryLocation]
    @Query(sort: \Home.purchaseDate) private var homes: [Home]

    private var activeHome: Home? {
        guard let activeIdString = settings.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    // Filter locations by active home
    private var locations: [InventoryLocation] {
        guard let activeHome = activeHome else {
            return allLocations
        }
        return allLocations.filter { $0.home?.id == activeHome.id }
    }

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
    @EnvironmentObject var settings: SettingsManager
    @Query(sort: [
        SortDescriptor(\InventoryLabel.name)
    ]) var allLabels: [InventoryLabel]
    @Query(sort: \Home.purchaseDate) private var homes: [Home]

    private var activeHome: Home? {
        guard let activeIdString = settings.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    // Labels are global (not filtered by home)
    private var labels: [InventoryLabel] {
        allLabels
    }

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
