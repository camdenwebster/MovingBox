import CloudKit
import Combine
import Network
import SwiftData
import SwiftUI

enum SyncStatus {
    case ready
    case syncing
    case offline
    case error(String)

    var displayText: String {
        switch self {
        case .ready:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .offline:
            return "Offline"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

@MainActor
class SyncStatusMonitor: ObservableObject {
    @Published var syncStatus: SyncStatus = .ready
    @Published var isSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: "iCloudSyncEnabled")
            if !isSyncEnabled {
                syncStatus = .offline
            }
        }
    }

    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    private var isNetworkAvailable = false

    init() {
        self.isSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        if UserDefaults.standard.object(forKey: "iCloudSyncEnabled") == nil {
            // Default to enabled for new installations
            self.isSyncEnabled = true
            UserDefaults.standard.set(true, forKey: "iCloudSyncEnabled")
        }

        setupNetworkMonitoring()
        setupCloudKitNotifications()
        updateSyncStatus()
    }

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                self.isNetworkAvailable = path.status == .satisfied
                self.updateSyncStatus()
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    private func setupCloudKitNotifications() {
        // Listen for CloudKit sync notifications
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleRemoteChange()
                }
            }
            .store(in: &cancellables)
    }

    private func handleRemoteChange() {
        if isSyncEnabled && isNetworkAvailable {
            syncStatus = .syncing
            // Simulate sync completion after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                if self.isSyncEnabled && self.isNetworkAvailable {
                    self.syncStatus = .ready
                    // Note: lastSyncDate is now updated by ModelContainerManager via CloudKit events
                }
            }
        }
    }

    private func updateSyncStatus() {
        if !isSyncEnabled {
            syncStatus = .ready  // Show ready when sync is disabled
        } else if !isNetworkAvailable {
            syncStatus = .offline
        } else {
            // Check if we're currently syncing
            syncStatus = .ready
        }
    }

    func refreshStatus() {
        updateSyncStatus()
    }

    func setSyncEnabled(_ enabled: Bool) {
        isSyncEnabled = enabled
    }

    deinit {
        networkMonitor.cancel()
    }
}

struct SyncDataSettingsView: View {
    @StateObject private var syncMonitor = SyncStatusMonitor()
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @State private var showRestartAlert = false
    @State private var initialSyncState: Bool?

    var body: some View {
        List {
            syncSettingsSection
            manageDataSection
        }
        .navigationTitle("Sync and Data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncMonitor.refreshStatus()
            // Capture initial state on first appear
            if initialSyncState == nil {
                initialSyncState = syncMonitor.isSyncEnabled
            }
        }
        .onChange(of: syncMonitor.isSyncEnabled) { _, newValue in
            // Show alert if sync setting changed from initial state
            if let initial = initialSyncState, initial != newValue {
                showRestartAlert = true
            }
        }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("Restart Now") {
                // Exit the app - user will need to reopen manually
                exit(0)
            }
            Button("Later", role: .cancel) {
                // User chose to restart later - do nothing
            }
        } message: {
            Text(
                "The app needs to restart for sync changes to take effect. Your data is safe and will be preserved."
            )
        }
    }

    private var syncSettingsSection: some View {
        Section {
            Toggle(isOn: $syncMonitor.isSyncEnabled) {
                Label {
                    Text("Enable Sync")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "icloud")

                }
            }

            HStack {
                Label {
                    Text("Sync Service")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "server.rack")

                }
                Spacer()
                Text("iCloud")
                    .foregroundColor(.secondary)
            }

            HStack {
                Label {
                    Text("Sync Status")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(
                        systemName: syncMonitor.syncStatus.isError
                            ? "exclamationmark.triangle" : "checkmark.circle"
                    )
                    .foregroundStyle(syncMonitor.syncStatus.isError ? .red : .green)
                }
                Spacer()
                HStack(spacing: 8) {
                    if case .syncing = syncMonitor.syncStatus {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(syncMonitor.syncStatus.displayText)
                        .foregroundColor(.secondary)
                }
            }

            if let lastSyncText = formattedLastSyncText(for: nil) {
                HStack {
                    Label {
                        Text("Last Sync")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "clock")

                    }
                    Spacer()
                    Text(lastSyncText)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Sync Settings")
            //                .font(.footnote)
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    "Your data is automatically synced across all your devices using iCloud when sync is enabled."
                )
                Text("Changes to sync settings require restarting the app to take effect.")
                    .foregroundColor(.secondary)
                if !syncMonitor.isSyncEnabled {
                    Text("Sync is currently disabled. Your data will only be available on this device.")
                        .foregroundColor(.orange)
                }
            }
            .font(.footnote)
        }
    }

    private var manageDataSection: some View {
        Group {
            Section("Manage Data") {

                NavigationLink(value: Router.Destination.importDataView) {
                    Label {
                        Text("Import Data")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "square.and.arrow.down")

                    }
                }
                .accessibilityIdentifier("importDataLink")

                NavigationLink(value: Router.Destination.exportDataView) {
                    Label {
                        Text("Export Data")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")

                    }
                }
                .accessibilityIdentifier("exportDataLink")
            }

            Section {
                NavigationLink(value: Router.Destination.deleteDataView) {
                    Label {
                        Text("Delete All Data")
                            .foregroundStyle(.red)
                    } icon: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func formattedLastSyncText(for date: Date?) -> String? {
        guard let date else { return nil }

        let now = Date()
        let elapsed = now.timeIntervalSince(date)
        let oneDay: TimeInterval = 24 * 60 * 60

        if elapsed >= 0, elapsed < oneDay {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: now)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        SyncDataSettingsView()
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    }
}
