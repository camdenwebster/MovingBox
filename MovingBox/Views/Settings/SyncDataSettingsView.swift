import SwiftUI
import SwiftData
import CloudKit
import Network
import Combine

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
    @Published var lastSyncDate: Date?
    
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
                    self.lastSyncDate = Date()
                }
            }
        }
    }
    
    private func updateSyncStatus() {
        if !isSyncEnabled {
            syncStatus = .ready // Show ready when sync is disabled
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
    
    var body: some View {
        List {
            syncSettingsSection
            manageDataSection
        }
        .navigationTitle("Sync and Data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncMonitor.refreshStatus()
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
                        .foregroundStyle(Color.customPrimary)
                }
            }
            
            HStack {
                Label {
                    Text("Sync Service")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "server.rack")
                        .foregroundStyle(Color.customPrimary)
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
                    Image(systemName: syncMonitor.syncStatus.isError ? "exclamationmark.triangle" : "checkmark.circle")
                        .foregroundStyle(syncMonitor.syncStatus.isError ? .red : Color.customPrimary)
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
            
            if let lastSync = syncMonitor.lastSyncDate {
                HStack {
                    Label {
                        Text("Last Sync")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundStyle(Color.customPrimary)
                    }
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Sync Settings")
//                .font(.footnote)
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your data is automatically synced across all your devices using iCloud when sync is enabled.")
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
                            .foregroundStyle(Color.customPrimary)
                    }
                }
                .accessibilityIdentifier("importDataLink")
                
                NavigationLink(value: Router.Destination.exportDataView) {
                    Label {
                        Text("Export Data")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.customPrimary)
                    }
                }
                .accessibilityIdentifier("exportDataLink")
            }
            
            Section {
                Button(role: .destructive) {
                    router.navigate(to: .deleteDataView)
                } label: {
                    Label {
                        Text("Delete All Data")
                    } icon: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SyncDataSettingsView()
            .environmentObject(Router())
    }
}
