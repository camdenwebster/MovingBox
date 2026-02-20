//
//  FamilySharingSettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 2/4/26.
//

import Dependencies
import SQLiteData
import SwiftUI

struct FamilySharingSettingsView: View {
    @FetchAll(SQLiteHome.order(by: \.name), animation: .default)
    private var homes: [SQLiteHome]

    var body: some View {
        List {
            homesSection
            infoSection
        }
        .navigationTitle("Family Sharing")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var homesSection: some View {
        Section {
            if homes.isEmpty {
                Text("Create a home to start sharing.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(homes) { home in
                    NavigationLink {
                        HomeDetailSettingsView(homeID: home.id, presentedInSheet: false)
                    } label: {
                        HomeSharingSummaryRow(home: home)
                    }
                }
            }
        } header: {
            Text("Homes")
        } footer: {
            Text("Sharing is managed inside each home's settings.")
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        Section {
            InfoRow(
                icon: "house",
                title: "Per-Home Sharing",
                description: "Invite people to specific homes while keeping others private."
            )
            InfoRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Real-time Sync",
                description: "Changes sync automatically between all participants."
            )
            InfoRow(
                icon: "lock.shield",
                title: "Secure",
                description: "Data is encrypted and only shared with people you invite."
            )
        } header: {
            Text("About Family Sharing")
        }
    }
}

private struct HomeSharingSummaryRow: View {
    @Dependency(\.defaultDatabase) private var database

    let home: SQLiteHome

    @State private var isLoading = true
    @State private var isShared = false
    @State private var participantCount = 0

    private var homeDisplayName: String {
        if !home.name.isEmpty { return home.name }
        if !home.address1.isEmpty { return home.address1 }
        return "Unnamed Home"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(homeDisplayName)
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Image(systemName: isShared ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isShared ? .green : .secondary)

                if isLoading {
                    Text("Checking status...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isShared {
                    Text("Shared with \(participantCount) people")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not Shared")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: home.syncMetadataID) {
            await loadSharingStatus()
        }
    }

    private func loadSharingStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let metadata = try await database.read { db in
                do {
                    return try SyncMetadata.find(home.syncMetadataID).fetchOne(db)
                } catch {
                    if isMissingSyncMetadataTableError(error) {
                        return nil
                    }
                    throw error
                }
            }
            if let share = metadata?.share {
                isShared = true
                participantCount = share.participants.filter { $0.role != .owner }.count
            } else {
                isShared = false
                participantCount = 0
            }
        } catch {
            isShared = false
            participantCount = 0
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        FamilySharingSettingsView()
    }
}
