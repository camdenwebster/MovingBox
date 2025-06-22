//
//  SyncSettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 6/22/25.
//

import SwiftUI

struct SyncSettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @StateObject private var syncManager = SyncManager.shared
    @State private var showingHomeBoxConfig = false
    @State private var isPerformingSync = false
    @State private var showingSyncServiceConfirmation = false
    @State private var selectedServiceType: SyncServiceType = .icloud
    
    var body: some View {
        List {
            // Sync Service Selection
            Section("Sync Service") {
                Picker("Sync Service", selection: $selectedServiceType) {
                    ForEach(SyncServiceType.allCases, id: \.self) { serviceType in
                        Text(serviceType.displayName)
                            .tag(serviceType)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedServiceType) { _, newValue in
                    if newValue != settingsManager.syncServiceType {
                        showingSyncServiceConfirmation = true
                    }
                }
                
                Text("Choose how your data is synchronized across devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Current Service Status
            Section("Sync Status") {
                HStack {
                    Label {
                        Text("Current Service")
                            .foregroundColor(.primary)
                    } icon: {
                        Image(systemName: syncServiceIcon)
                            .foregroundColor(.customPrimary)
                    }
                    Spacer()
                    Text(settingsManager.syncServiceType.displayName)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label {
                        Text("Status")
                            .foregroundColor(.primary)
                    } icon: {
                        Image(systemName: syncStatusIcon)
                            .foregroundColor(syncStatusColor)
                    }
                    Spacer()
                    Text(syncStatusText)
                        .foregroundColor(.secondary)
                }
                
                if let lastSync = syncManager.lastSyncDate {
                    HStack {
                        Label {
                            Text("Last Sync")
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundColor(.customPrimary)
                        }
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
                
                if syncManager.pendingSyncCount > 0 {
                    HStack {
                        Label {
                            Text("Pending Changes")
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Text("\(syncManager.pendingSyncCount)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // HomeBox Configuration
            if settingsManager.syncServiceType == .homebox {
                Section("HomeBox Configuration") {
                    NavigationLink {
                        HomeBoxConfigView()
                    } label: {
                        Label {
                            Text("Server Configuration")
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "server.rack")
                                .foregroundColor(.customPrimary)
                        }
                    }
                    
                    if !settingsManager.homeBoxServerURL.isEmpty {
                        HStack {
                            Label {
                                Text("Server URL")
                                    .foregroundColor(.primary)
                            } icon: {
                                Image(systemName: "link")
                                    .foregroundColor(.customPrimary)
                            }
                            Spacer()
                            Text(settingsManager.homeBoxServerURL)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    
                    if !settingsManager.homeBoxUsername.isEmpty {
                        HStack {
                            Label {
                                Text("Username")
                                    .foregroundColor(.primary)
                            } icon: {
                                Image(systemName: "person")
                                    .foregroundColor(.customPrimary)
                            }
                            Spacer()
                            Text(settingsManager.homeBoxUsername)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // iCloud Information
            if settingsManager.syncServiceType == .icloud {
                Section("iCloud Sync") {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your data is automatically synchronized across all your devices using iCloud")
                                .foregroundColor(.primary)
                            Text("Make sure you're signed in to iCloud in Settings to enable sync")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "icloud")
                            .foregroundColor(.customPrimary)
                    }
                }
            }
            
            // Sync Actions
            Section("Actions") {
                Button {
                    performManualSync()
                } label: {
                    HStack {
                        Label {
                            Text("Sync Now")
                                .foregroundColor(isPerformingSync ? .secondary : .customPrimary)
                        } icon: {
                            if isPerformingSync {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.customPrimary)
                            }
                        }
                        
                        if case .syncing(let progress) = syncManager.syncStatus {
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(isPerformingSync || !syncManager.isConfigured)
                
                Toggle(isOn: $settingsManager.syncEnabled) {
                    Label {
                        Text("Enable Sync")
                            .foregroundColor(.primary)
                    } icon: {
                        Image(systemName: "gear")
                            .foregroundColor(.customPrimary)
                    }
                }
            }
        }
        .navigationTitle("Sync Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedServiceType = settingsManager.syncServiceType
        }
        .alert("Change Sync Service?", isPresented: $showingSyncServiceConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedServiceType = settingsManager.syncServiceType
            }
            Button("Change") {
                settingsManager.syncServiceType = selectedServiceType
            }
        } message: {
            Text("Switching sync services will require reconfiguring your sync settings. Your local data will remain safe.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var syncServiceIcon: String {
        switch settingsManager.syncServiceType {
        case .icloud:
            return "icloud"
        case .homebox:
            return "server.rack"
        }
    }
    
    private var syncStatusIcon: String {
        switch syncManager.syncStatus {
        case .idle:
            return "pause.circle"
        case .syncing:
            return "arrow.clockwise"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    private var syncStatusColor: Color {
        switch syncManager.syncStatus {
        case .idle:
            return .secondary
        case .syncing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var syncStatusText: String {
        switch syncManager.syncStatus {
        case .idle:
            return "Ready"
        case .syncing(let progress):
            return "Syncing (\(Int(progress * 100))%)"
        case .completed(let date):
            return "Last synced \(date.formatted(.relative(presentation: .named)))"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Actions
    
    private func performManualSync() {
        isPerformingSync = true
        
        Task {
            do {
                try await syncManager.performFullSync()
            } catch {
                print("⚠️ SyncSettingsView - Manual sync failed: \(error)")
            }
            
            await MainActor.run {
                isPerformingSync = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        SyncSettingsView()
            .environmentObject(SettingsManager())
    }
}