//
//  SyncStatusIndicator.swift
//  MovingBox
//
//  Created by Camden Webster on 6/22/25.
//

import SwiftUI

struct SyncStatusIndicator: View {
    @StateObject private var syncManager = SyncManager.shared
    @EnvironmentObject private var settingsManager: SettingsManager
    
    let size: Size
    let showText: Bool
    
    enum Size {
        case small
        case medium
        case large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .footnote
            }
        }
    }
    
    init(size: Size = .medium, showText: Bool = false) {
        self.size = size
        self.showText = showText
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if showSyncIndicator {
                syncIcon
                    .font(.system(size: size.iconSize))
                    .foregroundColor(syncColor)
                
                if showText {
                    Text(syncText)
                        .font(size.fontSize)
                        .foregroundColor(syncColor)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: syncManager.syncStatus)
    }
    
    // MARK: - Computed Properties
    
    private var showSyncIndicator: Bool {
        // Show indicator when sync is enabled and configured
        return settingsManager.syncEnabled && syncManager.isConfigured
    }
    
    private var syncIcon: Image {
        switch syncManager.syncStatus {
        case .idle:
            return Image(systemName: syncServiceIcon)
        case .syncing:
            return Image(systemName: "arrow.clockwise")
        case .completed:
            return Image(systemName: "checkmark.circle.fill")
        case .failed:
            return Image(systemName: "exclamationmark.triangle.fill")
        }
    }
    
    private var syncServiceIcon: String {
        switch settingsManager.syncServiceType {
        case .icloud:
            return "icloud.fill"
        case .homebox:
            return "server.rack"
        }
    }
    
    private var syncColor: Color {
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
    
    private var syncText: String {
        switch syncManager.syncStatus {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing"
        case .completed:
            return "Synced"
        case .failed:
            return "Failed"
        }
    }
}

// MARK: - Convenience Modifiers

extension View {
    /// Add a sync status indicator to any view
    func syncStatusIndicator(size: SyncStatusIndicator.Size = .medium, showText: Bool = false) -> some View {
        HStack {
            self
            Spacer()
            SyncStatusIndicator(size: size, showText: showText)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Small indicator")
            Spacer()
            SyncStatusIndicator(size: .small)
        }
        
        HStack {
            Text("Medium with text")
            Spacer()
            SyncStatusIndicator(size: .medium, showText: true)
        }
        
        HStack {
            Text("Large with text")
            Spacer()
            SyncStatusIndicator(size: .large, showText: true)
        }
        
        Text("Using modifier")
            .syncStatusIndicator(showText: true)
    }
    .padding()
    .environmentObject(SettingsManager())
}