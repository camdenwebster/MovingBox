//
//  SettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/4/24.
//

import Dependencies
import SQLiteData
import Sentry
import StoreKit
import SwiftUI
import SwiftUIBackports
import UserNotifications

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
    @State private var selectedSection: SettingsSection? = .categories  // Default selection
    @State private var showingPaywall = false
    @State private var showingICloudAlert = false
    @State private var analyzedItemsCount: Int = 0

    @FetchAll(SQLiteInventoryItem.all, animation: .default)
    private var allItems: [SQLiteInventoryItem]

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
                NavigationLink(value: Router.Destination.insurancePolicyListView) {
                    Label {
                        Text("Insurance Policies")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "shield")
                    }
                }
                .accessibilityIdentifier("settings-insurance-button")
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

                if revenueCatManager.isProSubscriptionActive {
                    NavigationLink(value: Router.Destination.familySharingSettingsView) {
                        Label {
                            Text("Family Sharing")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "person.2.fill")
                        }
                    }
                    .accessibilityIdentifier("familySharingLink")
                } else {
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack {
                            Label {
                                Text("Family Sharing")
                                    .foregroundStyle(.secondary)
                            } icon: {
                                Image(systemName: "person.2.fill")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Pro")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.yellow)
                                .clipShape(.rect(cornerRadius: 4))
                        }
                    }
                    .accessibilityIdentifier("familySharingProButton")
                }
            }

            Section("Notifications") {
                NavigationLink(value: "notifications") {
                    Label {
                        Text("Notifications")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "bell.badge")
                    }
                }
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
            case "notifications": NotificationSettingsView()
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
            case .insurancePolicyListView: InsurancePolicyListView()
            case .insurancePolicyDetailView(let policyID): InsurancePolicyDetailView(policyID: policyID)
            case .familySharingSettingsView: FamilySharingSettingsView()
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
        analyzedItemsCount = allItems.filter { $0.hasUsedAI }.count
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    var body: some View {
        Form {
            Section("Status") {
                HStack {
                    Label {
                        Text(statusTitle)
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                    }

                    Spacer()

                    Text(statusDetail)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Analysis Alerts") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Get notified when multi-item analysis finishes in the background.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Text("Example: “Item analysis ready — tap to review detected items.”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                switch authorizationStatus {
                case .notDetermined:
                    Button {
                        Task {
                            await requestPermissions()
                        }
                    } label: {
                        Label("Enable Notifications", systemImage: "bell.badge.fill")
                    }
                    .disabled(isRequesting)

                case .denied:
                    Button {
                        openSystemSettings()
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                    }

                case .authorized, .provisional, .ephemeral:
                    Button {
                        openSystemSettings()
                    } label: {
                        Label("Manage in Settings", systemImage: "gear")
                    }

                @unknown default:
                    EmptyView()
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await refreshStatus()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await refreshStatus()
                }
            }
        }
    }

    private var statusTitle: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Enabled"
        case .denied:
            return "Disabled"
        case .notDetermined:
            return "Not Enabled"
        @unknown default:
            return "Unknown"
        }
    }

    private var statusDetail: String {
        switch authorizationStatus {
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Temporary"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not requested"
        @unknown default:
            return "Unknown"
        }
    }

    private var statusIcon: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "bell.badge"
        @unknown default:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .secondary
        }
    }

    private func refreshStatus() async {
        let center = UNUserNotificationCenter.current()
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    private func requestPermissions() async {
        isRequesting = true
        defer { isRequesting = false }
        do {
            let center = UNUserNotificationCenter.current()
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
        } catch {
            await refreshStatus()
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct AISettingsView: View {
    @State private var isEditing = false
    @EnvironmentObject var settings: SettingsManager
    private let modelOptions: [(id: String, label: String)] = [
        ("google/gemini-3-flash-preview", "Gemini 3 Flash")
    ]
    @FocusState private var isApiKeyFieldFocused: Bool

    private var currentModelLabel: String {
        modelOptions.first(where: { $0.id == settings.aiModel })?.label ?? settings.aiModel
    }

    var body: some View {
        Form {
            Section(header: Text("Model Settings")) {
                if isEditing {
                    Picker("Model", selection: $settings.aiModel) {
                        ForEach(modelOptions, id: \.id) { option in
                            Text(option.label)
                                .tag(option.id)
                        }
                    }
                } else {
                    HStack {
                        Text("Model")
                        Spacer()
                        Text(currentModelLabel)
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

struct LabelSettingsView: View {
    @Dependency(\.defaultDatabase) var database
    @EnvironmentObject var router: Router

    @FetchAll(SQLiteInventoryLabel.order(by: \.name), animation: .default)
    private var allLabels: [SQLiteInventoryLabel]

    var body: some View {
        if allLabels.isEmpty {
            ContentUnavailableView(
                "No Labels",
                systemImage: "tag",
                description: Text("Add labels to categorize your items.")
            )
        } else {
            List {
                ForEach(allLabels) { label in
                    NavigationLink {
                        EditLabelView(labelID: label.id)
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
                        router.navigate(to: .editLabelView(labelID: nil, isEditing: true))
                    } label: {
                        Label("Add Label", systemImage: "plus")
                    }
                }
            }
        }
    }

    func deleteLabel(at offsets: IndexSet) {
        for index in offsets {
            let labelToDelete = allLabels[index]
            do {
                try database.write { db in
                    try SQLiteInventoryLabel.find(labelToDelete.id).delete().execute(db)
                }
                print("Deleting label: \(labelToDelete.name)")
                TelemetryManager.shared.trackLabelDeleted()
            } catch {
                print("Failed to delete label: \(error)")
            }
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    NavigationStack {
        SettingsView()
            .environmentObject(Router())
            .environmentObject(SettingsManager())
            .environmentObject(RevenueCatManager.shared)
    }
}
